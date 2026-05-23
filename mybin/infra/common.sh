#!/bin/sh -eu
#
# common.sh
#   infra 配下の設定ファイルをサーバと同期する共通処理

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
INFRA_DIR="${REPO_ROOT}/infra"

SSH_USER="${SSH_USER:-isucon}"
RSYNC_RSH="${RSYNC_RSH:-ssh}"

is_local_host() {
  case "$1" in
    "" | local | localhost | 127.0.0.1)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

host_spec() {
  host="$1"
  if is_local_host "$host"; then
    return 1
  fi
  printf '%s@%s' "$SSH_USER" "$host"
}

rsync_from_remote() {
  remote_path="$1"
  local_path="$2"
  host="$3"

  mkdir -p "$local_path"
  if spec=$(host_spec "$host"); then
    rsync -az -e "$RSYNC_RSH" "${spec}:${remote_path}/" "${local_path}/" --rsync-path="sudo rsync"
  else
    sudo rsync -a "${remote_path}/" "${local_path}/"
  fi
  sudo chown -R "$(id -un)":"$(id -gn)" "$local_path" 2>/dev/null || true
}

rsync_to_remote() {
  local_path="$1"
  remote_path="$2"
  host="$3"

  if [ ! -d "$local_path" ] && [ ! -f "$local_path" ]; then
    echo "[ERROR] ローカルに存在しません: ${local_path}" >&2
    exit 1
  fi

  if spec=$(host_spec "$host"); then
    rsync -az -e "$RSYNC_RSH" "${local_path}/" "${spec}:${remote_path}/" --rsync-path="sudo rsync"
  else
    sudo rsync -a "${local_path}/" "${remote_path}/"
  fi
}

copy_file_to_remote() {
  local_file="$1"
  remote_file="$2"
  host="$3"

  if [ ! -f "$local_file" ]; then
    echo "[ERROR] ローカルに存在しません: ${local_file}" >&2
    exit 1
  fi

  remote_dir=$(dirname "$remote_file")
  if spec=$(host_spec "$host"); then
    "$RSYNC_RSH" "$spec" "sudo mkdir -p ${remote_dir}"
    rsync -az -e "$RSYNC_RSH" "$local_file" "${spec}:${remote_file}" --rsync-path="sudo rsync"
  else
    sudo mkdir -p "$remote_dir"
    sudo cp -p "$local_file" "$remote_file"
  fi
}

run_on_host() {
  host="$1"
  shift
  if spec=$(host_spec "$host"); then
    "$RSYNC_RSH" "$spec" "$@"
  else
    sh -c "$*"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] $1 が見つかりません" >&2
    exit 1
  fi
}

resolve_host() {
  component="$1"
  default_host="${2:-}"

  eval "configured=\${${component}_HOST:-}"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return
  fi
  if [ -n "$default_host" ]; then
    printf '%s' "$default_host"
    return
  fi
  printf '%s' "local"
}

resolve_app_service() {
  if [ -n "${APP_NAME:-}" ]; then
    printf '%s' "$APP_NAME"
    return
  fi
  if [ -n "${APPNAME:-}" ]; then
    printf '%s' "${APPNAME%.service}"
    return
  fi
  echo "[ERROR] APP_NAME または APPNAME を指定してください" >&2
  exit 1
}
