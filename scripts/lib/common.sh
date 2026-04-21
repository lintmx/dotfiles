#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$ROOT_DIR/config"

ZSH_BLOCK_START="# >>> dotfiles 配置 >>>"
ZSH_BLOCK_END="# <<< dotfiles 配置 <<<"

OS_FAMILY=""

SUMMARY_INSTALLED=()
SUMMARY_SKIPPED=()
SUMMARY_FAILED=()

# 输出普通信息日志。
log() {
  printf '[INFO] %s\n' "$*"
}

# 输出告警日志到 stderr。
warn() {
  printf '[WARNING] %s\n' "$*" >&2
}

# 输出错误日志到 stderr。
fail() {
  printf '[ERROR] %s\n' "$*" >&2
}

# 向安装结果汇总中追加一条记录。
record_summary() {
  local bucket="$1"
  shift

  case "$bucket" in
    installed)
      SUMMARY_INSTALLED+=("$*")
      ;;
    skipped)
      SUMMARY_SKIPPED+=("$*")
      ;;
    failed)
      SUMMARY_FAILED+=("$*")
      ;;
  esac
}

# 在某个汇总分组非空时输出该分组。
print_summary_bucket() {
  local title="$1"
  shift
  local items=("$@")
  local item

  if [ "${#items[@]}" -eq 0 ]; then
    return
  fi

  printf '\n%s\n' "$title"
  for item in "${items[@]}"; do
    printf '  - %s\n' "$item"
  done
}

# 输出最终的安装/跳过/失败汇总。
print_summary() {
  print_summary_bucket "已执行" "${SUMMARY_INSTALLED[@]-}"
  print_summary_bucket "已跳过" "${SUMMARY_SKIPPED[@]-}"
  print_summary_bucket "失败项" "${SUMMARY_FAILED[@]-}"
}

# 读取 yes/no 输入，并支持默认值。
confirm() {
  local prompt="$1"
  local default="${2:-N}"
  local reply=""

  while true; do
    if [ "$default" = "Y" ]; then
      printf '%s [Y/n] ' "$prompt"
    else
      printf '%s [y/N] ' "$prompt"
    fi

    IFS= read -r reply
    if [ -z "$reply" ]; then
      reply="$default"
    fi

    case "$reply" in
      Y|y|yes|YES)
        return 0
        ;;
      N|n|no|NO)
        return 1
        ;;
    esac
  done
}

# 读取单字符选项，并返回归一化后的结果。
prompt_choice() {
  local prompt="$1"
  local default="$2"
  shift 2
  local options=("$@")
  local reply=""
  local option=""
  local normalized_default=""

  normalized_default="$(printf '%s' "$default" | tr '[:upper:]' '[:lower:]')"

  while true; do
    printf '%s ' "$prompt" >&2
    IFS= read -r reply
    if [ -z "$reply" ]; then
      reply="$normalized_default"
    fi

    reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
    for option in "${options[@]}"; do
      if [ "$reply" = "$option" ]; then
        printf '%s\n' "$reply"
        return 0
      fi
    done
  done
}

# 检测受支持的系统类型，供安装依赖时使用。
detect_os() {
  local kernel=""
  local id_like=""

  kernel="$(uname -s)"
  case "$kernel" in
    Darwin)
      OS_FAMILY="mac"
      return 0
      ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
          ubuntu|debian|arch)
            OS_FAMILY="$ID"
            return 0
            ;;
        esac

        id_like="${ID_LIKE:-}"
        case "$id_like" in
          *debian*)
            OS_FAMILY="debian"
            return 0
            ;;
          *arch*)
            OS_FAMILY="arch"
            return 0
            ;;
        esac
      fi
      ;;
  esac

  fail "不支持的系统平台：$kernel"
  return 1
}

# 解析路径对应的规范绝对路径。
canonical_path() {
  perl -MCwd=abs_path -e 'my $path = shift; my $real = abs_path($path); exit 1 unless defined $real; print $real;' "$1"
}

# 检查目标符号链接是否已指向期望的源文件。
is_managed_symlink() {
  local target="$1"
  local source="$2"
  local target_real=""
  local source_real=""

  [ -L "$target" ] || return 1

  target_real="$(canonical_path "$target" 2>/dev/null)" || return 1
  source_real="$(canonical_path "$source" 2>/dev/null)" || return 1
  [ "$target_real" = "$source_real" ]
}

# 按需创建目标路径的父目录。
ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

# 在替换前删除文件、符号链接或目录目标。
replace_path() {
  local target="$1"

  if [ -d "$target" ] && [ ! -L "$target" ]; then
    rm -rf -- "$target"
  else
    rm -f -- "$target"
  fi
}

# 对非受管目标确认覆盖后，创建受管符号链接。
link_file() {
  local target="$1"
  local source="$2"
  local label="$3"

  ensure_parent_dir "$target"

  if is_managed_symlink "$target" "$source"; then
    log "$label 已由当前仓库接管，跳过"
    record_summary skipped "$label 已由当前仓库接管"
    return 0
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    if ! confirm "${label} 已存在于 ${target}，是否覆盖？" "N"; then
      record_summary skipped "${label} 保留现有目标"
      return 0
    fi
    replace_path "$target"
  fi

  ln -s "$source" "$target"
  record_summary installed "${label} 已链接到 ${source}"
  return 0
}

# 克隆依赖仓库，除非用户选择保留现有目录。
clone_or_skip() {
  local repo="$1"
  local destination="$2"
  local label="$3"

  if [ -d "$destination/.git" ]; then
    log "$label 已存在，跳过克隆"
    record_summary skipped "$label 已存在"
    return 0
  fi

  if [ -e "$destination" ]; then
    if ! confirm "${label} 已存在于 ${destination}，是否替换为重新克隆的版本？" "N"; then
      record_summary skipped "${label} 保留现有目录"
      return 0
    fi
    replace_path "$destination"
  fi

  if git clone "$repo" "$destination"; then
    record_summary installed "${label} 已从 ${repo} 克隆"
    return 0
  fi

  record_summary failed "${label} 克隆失败"
  return 1
}

# 生成插入到 ~/.zshrc 中的受管 zsh source 片段。
zsh_managed_block() {
  local source_file="$1"

  cat <<EOF
$ZSH_BLOCK_START
if [ -r "$source_file" ]; then
  source "$source_file"
fi
$ZSH_BLOCK_END
EOF
}

# 生成用于整体替换 ~/.zshrc 的最小内容。
zsh_minimal_entry() {
  local source_file="$1"

  cat <<EOF
# 由 dotfiles 安装脚本接管。
# 如有需要，可在下方继续追加当前机器的专属配置。
$(zsh_managed_block "$source_file")
EOF
}

# 检查 ~/.zshrc 是否仍指向仓库根目录中的旧入口文件。
is_legacy_repo_zshrc_link() {
  local zshrc="$1"
  local legacy_target="$ROOT_DIR/.zshrc"

  [ -L "$zshrc" ] || return 1
  [ -e "$legacy_target" ] || return 1
  is_managed_symlink "$zshrc" "$legacy_target"
}

# 将 ~/.zshrc 从旧的仓库内软链接迁移为真正的本地文件。
migrate_legacy_zshrc_link() {
  local zshrc="$1"
  local tmp_file=""

  is_legacy_repo_zshrc_link "$zshrc" || return 1

  tmp_file="$(mktemp)" || return 1
  cat "$zshrc" > "$tmp_file" || {
    rm -f "$tmp_file"
    return 1
  }

  rm -f "$zshrc" || {
    rm -f "$tmp_file"
    return 1
  }

  mv "$tmp_file" "$zshrc" || return 1
  record_summary installed "已将 ${zshrc} 从旧的仓库内软链接迁移为本地文件"
  return 0
}

# 从现有 ~/.zshrc 副本中移除受管片段。
strip_zsh_block() {
  local file="$1"
  local tmp_file="$2"

  awk -v start="$ZSH_BLOCK_START" -v end="$ZSH_BLOCK_END" '
    $0 == start { in_block = 1; next }
    $0 == end { in_block = 0; next }
    !in_block { print }
  ' "$file" > "$tmp_file"
}

# 创建、更新、追加或整体替换受管的 ~/.zshrc 入口。
ensure_zsh_entry() {
  local zshrc="$1"
  local source_file="$2"
  local block=""
  local minimal_entry=""
  local tmp_file=""
  local choice=""

  block="$(zsh_managed_block "$source_file")"
  minimal_entry="$(zsh_minimal_entry "$source_file")"

  if is_legacy_repo_zshrc_link "$zshrc"; then
    migrate_legacy_zshrc_link "$zshrc" || return 1
  fi

  if [ ! -e "$zshrc" ]; then
    ensure_parent_dir "$zshrc"
    printf '%s\n' "$minimal_entry" > "$zshrc"
    record_summary installed "已在 ${zshrc} 创建 zsh 入口"
    return 0
  fi

  if grep -Fq "$ZSH_BLOCK_START" "$zshrc"; then
    if grep -Fq "source \"$source_file\"" "$zshrc"; then
      log "zsh 受管片段已是最新状态，跳过"
      record_summary skipped "zsh 受管片段已是最新状态"
      return 0
    fi

    choice="$(
      prompt_choice \
        "${zshrc} 中的 zsh 受管片段当前指向其他位置。请选择：[r] 替换为最小配置 / [a] 追加更新后的片段 / [s] 跳过（默认：a）：" \
        "a" \
        "r" "a" "s"
    )"

    case "$choice" in
      r)
        printf '%s\n' "$minimal_entry" > "$zshrc"
        record_summary installed "已将 ${zshrc} 替换为最小 zsh 配置"
        ;;
      a)
        tmp_file="$(mktemp)"
        strip_zsh_block "$zshrc" "$tmp_file"
        mv "$tmp_file" "$zshrc"
        printf '\n%s\n' "$block" >> "$zshrc"
        record_summary installed "已更新 ${zshrc} 中的 zsh 受管片段"
        ;;
      s)
        record_summary skipped "保留现有 zsh 受管片段不变"
        ;;
    esac
    return 0
  fi

  choice="$(
    prompt_choice \
      "${zshrc} 已存在。请选择：[r] 替换为最小配置 / [a] 追加共享 source 片段 / [s] 跳过（默认：a）：" \
      "a" \
      "r" "a" "s"
  )"

  case "$choice" in
    r)
      printf '%s\n' "$minimal_entry" > "$zshrc"
      record_summary installed "已将 ${zshrc} 替换为最小 zsh 配置"
      ;;
    a)
      printf '\n%s\n' "$block" >> "$zshrc"
      record_summary installed "已向 ${zshrc} 追加 zsh 受管片段"
      ;;
    s)
      record_summary skipped "未接入 zsh 共享配置"
      ;;
  esac
}

# 在用户主目录中创建本机专属的 git 配置模板。
ensure_git_local_config() {
  local target="$1"
  local label="$2"

  if [ -e "$target" ]; then
    record_summary skipped "${label} 已存在"
    return 0
  fi

  if ! confirm "是否在 ${target} 创建 ${label}？" "Y"; then
    record_summary skipped "${label} 未创建"
    return 0
  fi

  cat > "$target" <<'EOF'
# 本地机器的 Git 配置覆盖项，供 ~/.gitconfig 引用。
EOF
  record_summary installed "已在 ${target} 创建 ${label}"
}

# 确保目录存在，并设置为期望权限。
ensure_dir_with_mode() {
  local target="$1"
  local mode="$2"

  mkdir -p "$target"
  chmod "$mode" "$target"
}

# 在用户主目录中创建本机专属的 SSH 配置模板。
ensure_ssh_local_config() {
  local target="$1"
  local label="$2"

  if [ -e "$target" ]; then
    chmod 600 "$target" 2>/dev/null || true
    record_summary skipped "${label} 已存在"
    return 0
  fi

  if ! confirm "是否在 ${target} 创建 ${label}？" "Y"; then
    record_summary skipped "${label} 未创建"
    return 0
  fi

  ensure_parent_dir "$target"
  cat > "$target" <<'EOF'
# 本地机器专属的 SSH 配置补充项。
#
# 适合放在这里的内容：
# - 本机 agent / IdentityAgent
# - 本机额外 Include
# - 仅当前机器使用的临时 Host
# - 当前机器自行维护的分组说明
#
# 示例：
# Include ~/.orbstack/ssh/config
#
# Host *
#   IdentityAgent ~/.1password/agent.sock
#
# Host demo
#   HostName 192.0.2.10
#   User lintmx
EOF
  chmod 600 "$target"
  record_summary installed "已在 ${target} 创建 ${label}"
}
