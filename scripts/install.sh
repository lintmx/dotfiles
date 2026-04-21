#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# 为当前系统安装基础依赖包。
install_base() {
  case "$OS_FAMILY" in
    ubuntu|debian)
      sudo apt update && sudo apt install -y zsh vim curl git tmux xclip
      ;;
    arch)
      sudo pacman -Syy --needed zsh vim curl git tmux xclip
      ;;
    mac)
      if ! command -v brew >/dev/null 2>&1; then
        fail "在 macOS 上安装基础模块需要先安装 Homebrew。"
        return 1
      fi
      brew install zsh vim curl git tmux reattach-to-user-namespace
      ;;
  esac
}

# 安装 zsh 相关依赖，并接入受管的 ~/.zshrc 入口。
install_zsh() {
  local shared_file="$CONFIG_DIR/zsh/.zshrc"

  clone_or_skip "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh" "oh-my-zsh" || return 1
  clone_or_skip "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting" || return 1
  clone_or_skip "https://github.com/zsh-users/zsh-autosuggestions.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "zsh-autosuggestions" || return 1
  ensure_zsh_entry "$HOME/.zshrc" "$shared_file" || return 1
}

install_vim_plug() {
  local autoload_dir="$HOME/.vim/autoload"
  local plug_vim="$autoload_dir/plug.vim"

  mkdir -p "$autoload_dir"

  if [ -f "$plug_vim" ]; then
    record_summary skipped "vim-plug 已存在"
    return 0
  fi

  if curl -fLo "$plug_vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
    record_summary installed "已安装 vim-plug"
    return 0
  fi

  record_summary failed "vim-plug 安装失败"
  return 1
}

install_vim_plugins() {
  if ! command -v vim >/dev/null 2>&1; then
    warn "系统中未找到 vim，跳过插件安装。"
    record_summary skipped "Vim 插件安装已跳过，因为系统中没有 vim"
    return 0
  fi

  if vim +PlugInstall +qall; then
    record_summary installed "已安装 Vim 插件"
    return 0
  fi

  record_summary failed "Vim 插件安装失败"
  return 1
}

# 链接共享的 vim 配置，并初始化 vim-plug 与插件。
install_vim() {
  link_file "$HOME/.vimrc" "$CONFIG_DIR/vim/.vimrc" "Vim 配置" || return 1

  if ! is_managed_symlink "$HOME/.vimrc" "$CONFIG_DIR/vim/.vimrc"; then
    warn "当前 Vim 配置不由本仓库管理，跳过 vim-plug 初始化和插件安装。"
    record_summary skipped "Vim 插件安装已跳过，因为 Vim 配置未由仓库接管"
    return 0
  fi

  install_vim_plug || return 1
  install_vim_plugins || return 1
}

# 链接共享的 git 配置，并按需创建本机本地配置。
install_git_module() {
  link_file "$HOME/.gitconfig" "$CONFIG_DIR/git/.gitconfig" "Git 配置" || return 1
  ensure_git_local_config "$HOME/.gitconfig.local" "Git 本地配置" || return 1
}

# 链接共享的 SSH 主配置，并为本机预留 conf.d 与 local 配置入口。
install_ssh_module() {
  ensure_dir_with_mode "$HOME/.ssh" 700 || return 1
  ensure_dir_with_mode "$HOME/.ssh/conf.d" 700 || return 1
  ensure_dir_with_mode "$HOME/.config/tssh" 700 || return 1

  link_file "$HOME/.ssh/config" "$CONFIG_DIR/ssh/config" "SSH 主配置" || return 1
  ensure_ssh_local_config "$HOME/.ssh/config.local" "SSH 本地配置" || return 1
  link_file "$HOME/.config/tssh/tssh.conf" "$CONFIG_DIR/tssh/tssh.conf" "tssh 配置" || return 1
}

# 安装 oh-my-tmux，并链接受管的 tmux 配置文件。
install_tmux() {
  clone_or_skip "https://github.com/gpakosz/.tmux.git" "$HOME/.oh-my-tmux" "oh-my-tmux" || return 1
  link_file "$HOME/.tmux.conf" "$HOME/.oh-my-tmux/.tmux.conf" "tmux 主配置" || return 1
  link_file "$HOME/.tmux.conf.local" "$CONFIG_DIR/tmux/.tmux.conf.local" "tmux 本地配置" || return 1
}

# 询问是否安装某个模块，并在失败时记录结果。
run_module() {
  local label="$1"
  shift

  if ! confirm "是否安装 $label 模块？" "Y"; then
    record_summary skipped "用户跳过了 $label 模块"
    return 0
  fi

  if "$@"; then
    log "$label 模块执行完成"
    return 0
  fi

  fail "$label 模块执行失败"
  record_summary failed "$label 模块执行失败"
  return 1
}

run_all_modules() {
  local module label handler
  local -a modules=(
    "基础环境:install_base"
    "zsh:install_zsh"
    "vim:install_vim"
    "git:install_git_module"
    "ssh:install_ssh_module"
    "tmux:install_tmux"
  )

  for module in "${modules[@]}"; do
    label="${module%%:*}"
    handler="${module#*:}"

    if ! run_module "$label" "$handler"; then
      print_summary
      return 1
    fi
  done
}

# 识别平台、执行所选模块，并输出汇总结果。
main() {
  log "仓库根目录：$ROOT_DIR"
  detect_os || exit 1
  log "检测到的平台：$OS_FAMILY"

  run_all_modules || exit 1
  print_summary
}

main "$@"
