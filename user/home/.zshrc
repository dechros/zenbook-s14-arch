if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

typeset -U path PATH
path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/.cargo/bin
  $HOME/.npm-global/bin
  $HOME/go/bin
  $HOME/.yarn/bin
  /usr/local/sbin
  /usr/local/bin
  /usr/bin
  /bin
  $path
)
export PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git)

source $ZSH/oh-my-zsh.sh

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH=~/.npm-global/bin:$PATH
