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

function docker() {
  _dotfiles_docker_wrapper docker "$@"
}

function docker-compose() {
  _dotfiles_docker_wrapper docker-compose "$@"
}

function _dotfiles_docker_platform() {
  emulate -L zsh
  local -a parts=("${(@s:/:)1}")
  if (( ${#parts} < 2 || ${#parts} > 3 )) || [[ -z "$parts[1]" || -z "$parts[2]" || "$1" == *,* ]]; then
    print -u2 -- "不支持的镜像平台：$1；请使用 os/arch[/variant]。"
    return 1
  fi
  case "$parts[2]" in
    x86_64|x86-64) parts[2]=amd64 ;;
    aarch64) parts[2]=arm64 ;;
    armhf|armv7l) parts[2]=arm; parts[3]=v7 ;;
    armel|armv6l) parts[2]=arm; parts[3]=v6 ;;
    i386|i686) parts[2]=386 ;;
  esac
  [[ "$parts[2]" == arm64 && "${parts[3]-}" == v8 ]] && parts=("$parts[1]" "$parts[2]")
  print -r -- "${(j:/:)parts}"
}

function _dotfiles_docker_auth() {
  emulate -L zsh
  unsetopt xtrace
  local registry="$1" config_file="$2" auth_file="$3"
  local config='{}' helper server="$registry" helper_result
  [[ -r "$config_file" ]] && config=$(command jq -ce 'select(type == "object")' "$config_file") || {
    if [[ -e "$config_file" ]]; then
      print -u2 -- "无法读取 Docker 登录配置：$config_file"
      return 1
    fi
  }
  [[ "$registry" == docker.io ]] && server='https://index.docker.io/v1/'
  helper=$(print -r -- "$config" | command jq -r --arg registry "$registry" --arg server "$server" \
    '.credHelpers[$registry] // .credHelpers[$server] // .credsStore // empty') || return
  if [[ -z "$helper" ]] && print -r -- "$config" | command jq -e \
    '((.auths // {}) | length) == 0 and ((.credHelpers // {}) | length) == 0 and (.credsStore // "") == ""' >/dev/null; then
    case "$(uname -s)" in
      Darwin) (( $+commands[docker-credential-osxkeychain] )) && helper=osxkeychain ;;
      Linux)
        if (( $+commands[docker-credential-pass] )); then
          helper=pass
        elif (( $+commands[docker-credential-secretservice] )); then
          helper=secretservice
        fi
        ;;
    esac
  fi
  if [[ -n "$helper" ]]; then
    if ! command -v "docker-credential-$helper" >/dev/null 2>&1; then
      print -u2 -- "缺少 Docker 登录配置指定的 docker-credential-$helper。"
      return 1
    fi
    helper_result="${auth_file}.helper"
    if print -r -- "$server" | command "docker-credential-$helper" get >"$helper_result" 2>"${helper_result}.err"; then
      command jq -ce --arg registry "$registry" '
        if (.Username | type) != "string" or (.Secret | type) != "string" then
          error("credential helper 返回的凭据格式无效")
        else
          {auths: {($registry): (if .Username == "<token>" then
            {identitytoken: .Secret}
          else {auth: ([.Username, .Secret] | join(":") | @base64)} end)}}
        end' "$helper_result" >"$auth_file" || return
    elif [[ "$(cat "$helper_result" "${helper_result}.err")" == *"credentials not found"* ]]; then
      print -r -- '{"auths":{}}' >"$auth_file"
    else
      print -u2 -- "无法通过 docker-credential-$helper 读取 $registry 的登录信息。"
      return 1
    fi
    command rm -f -- "$helper_result" "${helper_result}.err"
  else
    print -r -- "$config" | command jq --arg registry "$registry" --arg server "$server" '
      (.auths // {}) as $auths |
      ($auths[$server] // $auths[$registry] //
        ([$auths | to_entries[] | select((.key | sub("^https?://"; "") | split("/")[0] |
          if . == "index.docker.io" then "docker.io" else . end) == $registry) | .value][0]) // {}) as $auth |
      {auths: {($registry): $auth}}' >"$auth_file"
  fi
}

function _dotfiles_docker_wrapper() (
  emulate -L zsh
  unsetopt xtrace
  setopt pipefail
  local entry="$1"
  shift
  local proxy_name proxy_enabled=0
  for proxy_name in HTTP_PROXY HTTPS_PROXY http_proxy https_proxy; do
    if [[ "${parameters[$proxy_name]-}" == *export* && -n "${(P)proxy_name}" ]]; then
      proxy_enabled=1
      break
    fi
  done
  if (( ! proxy_enabled )); then
    command "$entry" "$@"
    return $?
  fi
  local -a original=("$@") docker_opts=() compose_opts=() targets=() compose_cmd=() config_opts=()
  local compose=0 pulling=0 quiet=0 include_deps=0 ignore_buildable=0 ignore_failures=0 dry_run=0
  local config_dir="${DOCKER_CONFIG:-$HOME/.docker}" requested_platform="${DOCKER_DEFAULT_PLATFORM-}" policy=''
  local option value
  [[ "$entry" == docker-compose ]] && compose=1
  while (( $# )); do
    option="$1"
    case "$option" in
      --help|-h) command "$entry" "${original[@]}"; return $? ;;
      --config|--context|-c|--host|-H|--log-level|-l|--tlscacert|--tlscert|--tlskey)
        (( $# >= 2 )) || { print -u2 -- "$option 缺少参数。"; return 2; }
        [[ "$option" == --config ]] && config_dir="$2"
        docker_opts+=("$1" "$2"); shift 2; continue ;;
      --config=*|--context=*|--host=*|--log-level=*|--tlscacert=*|--tlscert=*|--tlskey=*|-c?*|-H?*|-l?*)
        [[ "$option" == --config=* ]] && config_dir="${option#*=}"
        docker_opts+=("$1"); shift; continue ;;
      --debug|-D|--debug=*|--tls|--tls=*|--tlsverify|--tlsverify=*)
        docker_opts+=("$1"); shift; continue ;;
    esac
    if (( compose )); then
      case "$option" in
        -f|--file|-p|--project-name|--project-directory|--env-file|--profile|--ansi|--parallel|--progress)
          (( $# >= 2 )) || { print -u2 -- "$option 缺少参数。"; return 2; }
          [[ "$option" == --progress && "$2" == quiet ]] && quiet=1
          compose_opts+=("$1" "$2"); shift 2; continue ;;
        --file=*|--project-name=*|--project-directory=*|--env-file=*|--profile=*|--ansi=*|--parallel=*|--progress=*|-f?*|-p?*)
          [[ "$option" == --progress=quiet ]] && quiet=1
          compose_opts+=("$1"); shift; continue ;;
        --compatibility|--compatibility=*|--all-resources|--all-resources=*)
          compose_opts+=("$1"); shift; continue ;;
        --dry-run|--dry-run=true) dry_run=1; shift; continue ;;
        --dry-run=false) dry_run=0; shift; continue ;;
      esac
    fi
    if (( ! pulling )); then
      case "$option" in
        compose)
          if [[ "$entry" == docker ]] && (( ! compose )); then
            compose=1; shift; continue
          fi ;;
        pull) pulling=1; shift; continue ;;
      esac
      command "$entry" "${original[@]}"
      return $?
    fi
    case "$option" in
      --quiet|-q|--quiet=true) quiet=1 ;;
      --quiet=false) quiet=0 ;;
      --platform|--policy)
        (( $# >= 2 )) || { print -u2 -- "$option 缺少参数。"; return 2; }
        if [[ "$option" == --platform ]] && (( ! compose )); then
          requested_platform="$2"
        elif [[ "$option" == --policy ]] && (( compose )); then
          policy="$2"
        else
          print -u2 -- "此 pull 命令不支持 $option。"; return 2
        fi
        shift ;;
      --platform=*)
        (( ! compose )) || { print -u2 -- 'compose pull 不支持 --platform。'; return 2; }
        requested_platform="${option#*=}" ;;
      --policy=*)
        (( compose )) || { print -u2 -- 'docker pull 不支持 --policy。'; return 2; }
        policy="${option#*=}" ;;
      --include-deps|--include-deps=true|--ignore-buildable|--ignore-buildable=true|--ignore-pull-failures|--ignore-pull-failures=true|--include-deps=false|--ignore-buildable=false|--ignore-pull-failures=false)
        (( compose )) || { print -u2 -- "docker pull 不支持 $option。"; return 2; }
        value=1; [[ "$option" == *=false ]] && value=0
        case "${option%%=*}" in
          --include-deps) include_deps=$value ;;
          --ignore-buildable) ignore_buildable=$value ;;
          --ignore-pull-failures) ignore_failures=$value ;;
        esac ;;
      --disable-content-trust|--disable-content-trust=true)
        (( ! compose )) || { print -u2 -- "compose pull 不支持 $option。"; return 2; } ;;
      --) shift; targets+=("$@"); break ;;
      -*) print -u2 -- "Skopeo wrapper 不支持 pull 参数：$option；可用 command $entry 绕过。"; return 2 ;;
      *) targets+=("$1") ;;
    esac
    shift
  done
  if (( ! pulling )); then
    command "$entry" "${original[@]}"
    return $?
  fi
  if (( dry_run )) || [[ "${COMPOSE_DRY_RUN-}" == (1|true|TRUE) && "$compose" == 1 ]]; then
    print -u2 -- 'Skopeo wrapper 暂不支持 Compose dry-run；未执行拉取。'
    return 2
  fi
  if [[ "${DOCKER_CONTENT_TRUST-}" == (1|true|TRUE) ]]; then
    print -u2 -- 'Skopeo wrapper 不支持 Docker Content Trust；请使用 command docker。'
    return 2
  fi
  if [[ -n "$policy" && "$policy" != (always|missing) ]]; then
    print -u2 -- '--policy 只支持 always 或 missing。'; return 2
  fi
  if (( ! compose && ${#targets} != 1 )); then
    print -u2 -- '用法：docker pull [--platform os/arch[/variant]] [-q] IMAGE[:TAG]'
    return 2
  fi
  local dependency
  for dependency in docker jq skopeo; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      print -u2 -- "缺少 $dependency；请安装 Docker 及安装器中的 Docker 拉取（Skopeo）模块。"
      return 127
    fi
  done
  umask 077
  local work_dir
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-docker-pull.XXXXXX") || return
  trap 'command rm -rf -- "$work_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  if (( compose )); then
    if [[ "$entry" == docker ]]; then
      compose_cmd=(docker "${docker_opts[@]}" compose "${compose_opts[@]}")
    else
      compose_cmd=(docker-compose "${docker_opts[@]}" "${compose_opts[@]}")
    fi
    local config_help selected
    config_help=$(command "${compose_cmd[@]}" config --help) || return
    if [[ "$config_help" != *--format* ]]; then
      print -u2 -- '需要支持 config --format json 的 Compose v2 或更新版本；不支持旧版 Compose v1。'
      return 2
    fi
    config_opts=(config --format json)
    [[ "$config_help" == *--no-env-resolution* ]] && config_opts+=(--no-env-resolution)
    command "${compose_cmd[@]}" "${config_opts[@]}" -- "${targets[@]}" >"$work_dir/compose.json" || return
    selected=$(command jq -cn --args '$ARGS.positional' "${targets[@]}") || return
    command jq -c --argjson selected "$selected" --argjson deps "$include_deps" \
      --argjson ignore_buildable "$ignore_buildable" --arg policy "$policy" '
      .services | to_entries[] |
      select(($selected | length) == 0 or $deps == 1 or (.key as $key | $selected | index($key))) |
      .value | select(.image != null and .image != "") |
      select($ignore_buildable == 0 or .build == null) |
      {image, platform: (.platform // ""), policy: (if $policy != "" then $policy else .pull_policy // "always" end)} |
      select(.policy != "never" and .policy != "build")' "$work_dir/compose.json" >"$work_dir/jobs" || return
  else
    command jq -cn --arg image "$targets[1]" --arg platform "$requested_platform" \
      '{image: $image, platform: $platform, policy: "always"}' >"$work_dir/jobs" || return
  fi
  [[ -s "$work_dir/jobs" ]] || return 0
  if ! command jq -es 'all(.[]; (.image | contains("@") | not) and (.policy == "always" or .policy == "missing" or .policy == "if_not_present"))' "$work_dir/jobs" >/dev/null; then
    print -u2 -- 'Skopeo wrapper 暂不支持 digest 镜像引用或按时间刷新的 pull_policy；未执行拉取。'
    return 2
  fi
  local daemon_platform job image platform registry image_policy local_platform key result=0 rc
  local -a platform_parts skopeo_opts
  local -A attempted
  daemon_platform=$(command docker "${docker_opts[@]}" info --format '{{.OSType}}/{{.Architecture}}') || return
  daemon_platform=$(_dotfiles_docker_platform "$daemon_platform") || return
  while IFS= read -r job; do
    image=$(print -r -- "$job" | command jq -r .image) || return
    platform=$(print -r -- "$job" | command jq -r .platform) || return
    platform=$(_dotfiles_docker_platform "${platform:-${requested_platform:-$daemon_platform}}") || return
    image_policy=$(print -r -- "$job" | command jq -r .policy) || return
    if [[ "$image" != */* ]]; then
      image="docker.io/library/$image"
    elif [[ "${image%%/*}" != *[.:]* && "${image%%/*}" != localhost ]]; then
      image="docker.io/$image"
    fi
    [[ "$image" == index.docker.io/* ]] && image="docker.io/${image#*/}"
    [[ "${image##*/}" != *:* ]] && image="${image}:latest"
    key="$image|$platform"
    [[ -n "${attempted[$key]-}" ]] && continue
    if [[ "$image_policy" != always && "$image" != *:latest ]]; then
      local_platform=$(command docker "${docker_opts[@]}" image inspect --format '{{.Os}}/{{.Architecture}}/{{.Variant}}' "$image" 2>/dev/null) && {
        local_platform=$(_dotfiles_docker_platform "${local_platform%/}") || return
        [[ "$local_platform" == "$platform" || "$platform" == "${local_platform%/*}" ]] && continue
      }
    fi
    attempted[$key]=1
    registry="${image%%/*}"
    platform_parts=("${(@s:/:)platform}")
    skopeo_opts=(--tmpdir "$work_dir" --override-os "$platform_parts[1]" --override-arch "$platform_parts[2]" --override-variant "${platform_parts[3]-}" copy)
    (( quiet )) && skopeo_opts+=(--quiet)
    rc=0
    if _dotfiles_docker_auth "$registry" "$config_dir/config.json" "$work_dir/auth.json" &&
      command skopeo "${skopeo_opts[@]}" --src-authfile "$work_dir/auth.json" \
        "docker://$image" "docker-archive:$work_dir/image.tar:$image"; then
      if (( quiet )); then
        command docker "${docker_opts[@]}" load -i "$work_dir/image.tar" >/dev/null || rc=$?
      else
        command docker "${docker_opts[@]}" load -i "$work_dir/image.tar" || rc=$?
      fi
      if (( rc == 0 && quiet && ! compose )); then
        command docker "${docker_opts[@]}" image inspect --format '{{.Id}}' "$image" || rc=$?
      fi
    else
      rc=$?
    fi
    command rm -f -- "$work_dir/image.tar" "$work_dir/auth.json"
    if (( rc )); then
      print -u2 -- "镜像拉取或导入失败：$image ($platform)"
      result=$rc
      (( ignore_failures )) || return "$result"
    fi
  done <"$work_dir/jobs"
  (( ignore_failures )) && return 0
  return "$result"
)
