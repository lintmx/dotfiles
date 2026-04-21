# Zsh 配置文件

## oh-my-zsh 配置
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="ys"

plugins=(
  z
  copypath
  command-not-found
  docker-compose
  safe-paste
  git
  sudo
  man
  svn
  encode64
  extract
  systemd
  zsh-syntax-highlighting
  zsh-autosuggestions
)

ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$HOME/.oh-my-zsh-cache}"
mkdir -p "$ZSH_CACHE_DIR"

if [ -r "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

## 环境变量
export LANG="${LANG:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export EDITOR="${EDITOR:-vim}"

## 别名
alias svim='sudo -E vim'
alias la='ls -la'
alias s='screen -R work'
alias t='tmux new -As work'

# 增加额外的 sbin 目录到 PATH，以便在不使用 sudo 的情况下访问 Homebrew 和其他用户安装的工具。
for extra_sbin in /usr/local/sbin /opt/homebrew/sbin; do
  case ":$PATH:" in
    *":$extra_sbin:"*) ;;
    *) [ -d "$extra_sbin" ] && PATH="$extra_sbin:$PATH" ;;
  esac
done
export PATH

# 从 functions.zsh 加载自定义函数（如果存在）。
if [ -r "$_dotfiles_zsh_dir/functions.zsh" ]; then
  source "$_dotfiles_zsh_dir/functions.zsh"
fi
