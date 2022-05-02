# ZSH Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="ys"

plugins=(
  git
  sudo
  man
  svn
  encode64
  extract
  systemd
#  zsh_reload
  zsh-syntax-highlighting
)

ZSH_CACHE_DIR=$HOME/.oh-my-zsh-cache
if [[ ! -d $ZSH_CACHE_DIR ]]; then
  mkdir $ZSH_CACHE_DIR
fi

source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export EDITOR='vim'
export PATH="/usr/local/sbin:$PATH"

source $HOME/.zsh_machine

# Aliases
alias svim='sudo -E vim'
alias la='ls -la'
alias nohis="unset HISTFILE"
alias s='screen -R work'
alias t='tmux new -As work'
alias filechown='find . -exec sh -c "if [[ -d "{}" ]]; then chmod 755 "{}"; else chmod 644 "{}"; fi " \;'

# Function
function proxy() {
  export http_proxy="http://127.0.0.1:7890"
  export https_proxy="http://127.0.0.1:7890"
}

function noproxy() {
  export http_proxy=""
  export https_proxy=""
}

