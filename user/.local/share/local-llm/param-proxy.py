#!/usr/bin/env python3
"""Reverse proxy in front of ollama, presenting an OpenAI-compatible
/v1/chat/completions interface while actually talking to ollama's native
/api/chat endpoint underneath.

Why not just forward to ollama's own /v1/chat/completions? Because that
endpoint only honors genuine standard OpenAI sampling fields (temperature,
top_p, top_k, max_tokens). Anything else - min_p, repeat_penalty,
repeat_last_n, presence_penalty, frequency_penalty - is silently dropped
even when present in the request body; ollama falls back to whatever was
baked into the model at its last `ollama create`. That defeats the whole
point of this proxy for models whose hardening relies on those fields.

ollama's native /api/chat, by contrast, takes a nested "options" object and
genuinely applies every field in it per-request, no rebuild required. So
this proxy translates: it accepts OpenAI-shaped requests from opencode/VS
Code, rewrites them into a native /api/chat call (sampling params moved
into "options"), forwards to ollama, and translates the native response
(both streaming NDJSON and non-streaming) back into OpenAI chat.completion
shape so the clients never notice the difference.

Both the per-model parameters and the system prompt are read fresh from
disk on every request (no caching) - the .modelfile per model and one
shared SYSTEM_PROMPT.txt are the single source of truth. Editing either
file takes effect on the next request, for every client that goes through
this proxy (opencode and VS Code both point here instead of at ollama
directly).
"""
import pathlib
import json
import re
import time
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

OLLAMA_CHAT_URL = "http://127.0.0.1:11434/api/chat"
LISTEN_PORT = 11435
SYSTEM_PROMPT_PATH = str(pathlib.Path(__file__).with_name("SYSTEM_PROMPT.txt"))
SYSPROMPT_DIR = str(pathlib.Path(__file__).parent)

# Which .modelfile holds each model's PARAMETER block. This is the single
# source of truth for sampling params - edit the .modelfile, not this dict.
MODEL_FILES = {
    "huihui_ai/Qwen3.6-abliterated:35b-a3b": "qwen36-35b-a3b.modelfile",
}

# Modelfile PARAMETER names forwarded into ollama's native "options" object.
# All of these are genuinely applied per-request via /api/chat (unlike the
# /v1 shim, which only honors temperature/top_p/top_k/max_tokens).
FORWARD_PARAMS = {
    "temperature", "top_p", "top_k", "min_p", "typical_p",
    "presence_penalty", "frequency_penalty", "repeat_penalty", "repeat_last_n",
    "num_predict", "num_ctx", "num_batch", "num_gpu",
}


def _coerce(value):
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def load_params(model):
    filename = MODEL_FILES.get(model)
    if not filename:
        return {}
    params = {}
    try:
        with open(f"{SYSPROMPT_DIR}/{filename}") as f:
            for line in f:
                m = re.match(r"\s*PARAMETER\s+(\S+)\s+(\S+)", line)
                if m and m.group(1) in FORWARD_PARAMS:
                    params[m.group(1)] = _coerce(m.group(2))
    except OSError:
        pass
    return params


def openai_request_to_native(data):
    """Rewrite an OpenAI-shaped chat.completions body into ollama's native
    /api/chat body: sampling fields move into a nested "options" object,
    everything else (model/messages/tools/stream) passes through as-is."""
    model = data.get("model")
    options = {}
    modelfile_params = load_params(model)
    for k, v in modelfile_params.items():
        options[k] = v
    # Explicit OpenAI-style fields the client sent override the modelfile -
    # except num_predict/max_tokens: opencode/VS Code send their own client
    # config's output-token ceiling (e.g. maxOutputTokens: 8192) as
    # max_tokens on every request, which would silently overwrite a
    # deliberately-tuned num_predict safety cap from the modelfile. The
    # modelfile is the single source of truth for that field when it sets one.
    if "temperature" in data:
        options["temperature"] = data.pop("temperature")
    if "top_p" in data:
        options["top_p"] = data.pop("top_p")
    if "max_tokens" in data:
        client_max_tokens = data.pop("max_tokens")
        if "num_predict" not in modelfile_params:
            options["num_predict"] = client_max_tokens

    messages = data.get("messages")
    if isinstance(messages, list):
        for m in messages:
            if not isinstance(m, dict):
                continue
            for tc in (m.get("tool_calls") or []):
                fn = tc.get("function") if isinstance(tc, dict) else None
                if not isinstance(fn, dict):
                    continue
                args = fn.get("arguments")
                if isinstance(args, str):
                    try:
                        fn["arguments"] = json.loads(args) if args else {}
                    except json.JSONDecodeError:
                        fn["arguments"] = {}
    if isinstance(messages, list) and not any(
        m.get("role") == "system" for m in messages if isinstance(m, dict)
    ):
        try:
            with open(SYSTEM_PROMPT_PATH) as f:
                sys_text = f.read()
            messages.insert(0, {"role": "system", "content": sys_text})
        except OSError:
            pass

    native = {
        "model": model,
        "messages": messages,
        "stream": data.get("stream", False),
    }
    if data.get("tools"):
        native["tools"] = data["tools"]
    if options:
        native["options"] = options
    return native


def native_message_to_openai_tool_calls(msg):
    calls = msg.get("tool_calls")
    if not calls:
        return None
    out = []
    for i, c in enumerate(calls):
        fn = c.get("function", {})
        args = fn.get("arguments", {})
        if not isinstance(args, str):
            args = json.dumps(args)
        out.append({
            "id": f"call_{uuid.uuid4().hex[:24]}",
            "index": i,
            "type": "function",
            "function": {"name": fn.get("name", ""), "arguments": args},
        })
    return out


def native_chunk_to_openai_chunk(obj, resp_id, model, created):
    msg = obj.get("message", {}) or {}
    delta = {}
    if msg.get("content"):
        delta["content"] = msg["content"]
    tool_calls = native_message_to_openai_tool_calls(msg)
    if tool_calls:
        delta["tool_calls"] = tool_calls
    if not delta and not obj.get("done"):
        delta = {"content": ""}
    finish_reason = None
    if obj.get("done"):
        finish_reason = "tool_calls" if tool_calls else "stop"
    return {
        "id": resp_id,
        "object": "chat.completion.chunk",
        "created": created,
        "model": model,
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}],
    }


def native_response_to_openai(obj, resp_id, model, created):
    msg = obj.get("message", {}) or {}
    tool_calls = native_message_to_openai_tool_calls(msg)
    message = {"role": "assistant", "content": msg.get("content", "") or ""}
    finish_reason = "stop"
    if tool_calls:
        message["tool_calls"] = tool_calls
        finish_reason = "tool_calls"
    return {
        "id": resp_id,
        "object": "chat.completion",
        "created": created,
        "model": model,
        "choices": [{"index": 0, "message": message, "finish_reason": finish_reason}],
        "usage": {
            "prompt_tokens": obj.get("prompt_eval_count", 0),
            "completion_tokens": obj.get("eval_count", 0),
            "total_tokens": obj.get("prompt_eval_count", 0) + obj.get("eval_count", 0),
        },
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def do_GET(self):
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else b""

        if not self.path.rstrip("/").endswith("/v1/chat/completions"):
            self.send_response(404)
            self.end_headers()
            return

        try:
            data = json.loads(body)
        except (json.JSONDecodeError, TypeError):
            self.send_response(400)
            self.end_headers()
            return

        model = data.get("model")
        client_wants_stream = bool(data.get("stream", False))
        native = openai_request_to_native(data)
        # Always stream from ollama, regardless of what the client asked for
        # (see below for why). resp_id/created are computed up front since
        # headers now go out before we've even contacted ollama.
        native["stream"] = True
        resp_id = f"chatcmpl-{uuid.uuid4().hex[:24]}"
        created = int(time.time())

        # Send OUR response headers to the client right now, before opening
        # any connection to ollama. A client's header-timeout (opencode's
        # ai-sdk gives up after 300s) times the gap between request sent and
        # response headers received - and ollama itself does not flush its
        # own headers until it's ready to write the first byte, which for a
        # large prompt can mean minutes of prompt-eval before ANY bytes
        # arrive. Waiting on ollama's urlopen() before replying (the previous
        # approach) inherited that delay. Replying immediately decouples
        # client-side header timing from upstream conditions entirely - the
        # body can then take as long as it needs.
        if client_wants_stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()

        req = urllib.request.Request(
            OLLAMA_CHAT_URL,
            data=json.dumps(native).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=1200) as resp:
                if client_wants_stream:
                    for line in resp:
                        line = line.strip()
                        if not line:
                            continue
                        obj = json.loads(line)
                        chunk = native_chunk_to_openai_chunk(obj, resp_id, model, created)
                        self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
                    self.wfile.write(b"data: [DONE]\n\n")
                else:
                    final_obj = {}
                    content_parts = []
                    for line in resp:
                        line = line.strip()
                        if not line:
                            continue
                        obj = json.loads(line)
                        msg = obj.get("message", {}) or {}
                        if msg.get("content"):
                            content_parts.append(msg["content"])
                        if obj.get("done"):
                            final_obj = obj
                            if not final_obj.get("message"):
                                final_obj["message"] = {}
                            final_obj["message"]["content"] = "".join(content_parts)
                            if msg.get("tool_calls"):
                                final_obj["message"]["tool_calls"] = msg["tool_calls"]
                    out = native_response_to_openai(final_obj, resp_id, model, created)
                    self.wfile.write(json.dumps(out).encode())
        except urllib.error.HTTPError as e:
            # Client already got a 200 and headers - report the failure in
            # the body since we can no longer change the status line.
            body = e.read()
            if client_wants_stream:
                self.wfile.write(f"data: {json.dumps({'error': body.decode(errors='replace')})}\n\n".encode())
                self.wfile.write(b"data: [DONE]\n\n")
            else:
                self.wfile.write(json.dumps({"error": body.decode(errors="replace")}).encode())
        except Exception as e:
            if client_wants_stream:
                self.wfile.write(f"data: {json.dumps({'error': str(e)})}\n\n".encode())
                self.wfile.write(b"data: [DONE]\n\n")
            else:
                self.wfile.write(json.dumps({"error": str(e)}).encode())


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", LISTEN_PORT), Handler)
    server.serve_forever()
