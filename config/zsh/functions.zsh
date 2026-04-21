# 统一修正当前目录下文件和目录的权限。
filechown() {
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
proxy() {
  local url="http://127.0.0.1:7890"
  export http_proxy="$url" https_proxy="$url" all_proxy="$url" HTTP_PROXY="$url" HTTPS_PROXY="$url" ALL_PROXY="$url"
}

# 清理当前 shell 会话中的代理环境变量。
unproxy() {
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
}

# 关闭当前会话的历史记录持久化。
nohis() {
  unset HISTFILE
}
