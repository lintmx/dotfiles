# 统一修正当前目录下文件和目录的权限。
function filechown() {
  find . -exec sh -c '
    for path do
      if [ -d "$path" ]; then
        chmod 755 "$path"
      else
        chmod 644 "$path"
      fi
    done
  ' sh {} +
}

# 为当前 shell 会话启用本地 HTTP(S) 代理。
function proxy() {
  local url="http://127.0.0.1:7890"
  export http_proxy="$url" https_proxy="$url" all_proxy="$url" HTTP_PROXY="$url" HTTPS_PROXY="$url" ALL_PROXY="$url"
}

# 清理当前 shell 会话中的代理环境变量。
function unproxy() {
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
}

# 关闭当前会话的历史记录持久化。
function nohis() {
  unset HISTFILE
}

# 临时使用 php 版本
function phpuse() {
  if [ -z "$1" ]; then
    echo "Usage: phpuse 8.2"
    return 1
  fi

  local version="$1"
  local formula="php@$version"

  if [ "$version" = "8.5" ] || [ "$version" = "latest" ]; then
    formula="php"
  fi

  if ! brew --prefix "$formula" >/dev/null 2>&1; then
    if brew --prefix "shivammathur/php/php@$version" >/dev/null 2>&1; then
      formula="shivammathur/php/php@$version"
    else
      echo "PHP $version is not installed."
      echo "Try:"
      echo "  brew install php@$version"
      echo "  or"
      echo "  brew install shivammathur/php/php@$version"
      return 1
    fi
  fi

  export PATH="$(brew --prefix "$formula")/bin:$(brew --prefix "$formula")/sbin:$PATH"

  hash -r
  php -v
  which php
}
