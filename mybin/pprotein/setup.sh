#!/bin/sh -eu
#
# setup.sh
#   ISUCON競技サーバでpprotein-agentを導入し、pproteinサーバから
#   pprof/slowlog/httplogを収集できる状態に整えます。
# 使い方:
#   ./setup.sh install    # ダウンロード・systemd登録・サービス起動
#   ./setup.sh uninstall  # サービス停止とクリーンアップ
# 環境変数:
#   PPROTEIN_VERSION           (既定: 1.2.4)
#   PPROTEIN_ARCH              (既定: linux_amd64)
#   INSTALL_DIR                (既定: /home/isucon)
#   SERVICE_USER               (既定: root)
#   SERVICE_NAME               (既定: pprotein-agent)
#   BIND_PORT                  (既定: 19000)
#   PPROTEIN_HTTPLOG           (既定: /var/log/nginx/access.log)
#   PPROTEIN_SLOWLOG           (既定: /var/log/mysql/mysql-slow.log)
#   PPROTEIN_GIT_REPOSITORY    (既定: このリポジトリのルート)
# 参考: https://zenn.dev/team_soda/articles/20231206000000

COMMAND=${1:-install}
PPROTEIN_VERSION=${PPROTEIN_VERSION:-1.2.4}
PPROTEIN_ARCH=${PPROTEIN_ARCH:-linux_amd64}
INSTALL_DIR=${INSTALL_DIR:-/home/isucon}
SERVICE_USER=${SERVICE_USER:-root}
SERVICE_NAME=${SERVICE_NAME:-pprotein-agent}
BIND_PORT=${BIND_PORT:-19000}
PPROTEIN_HTTPLOG=${PPROTEIN_HTTPLOG:-/var/log/nginx/access.log}
PPROTEIN_SLOWLOG=${PPROTEIN_SLOWLOG:-/var/log/mysql/mysql-slow.log}
REPO_ROOT=${PPROTEIN_GIT_REPOSITORY:-$(cd "$(dirname "$0")/../.." && pwd)}
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
DOWNLOAD_URL="https://github.com/kaz/pprotein/releases/download/v${PPROTEIN_VERSION}/pprotein_${PPROTEIN_VERSION}_${PPROTEIN_ARCH}.tar.gz"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] $1 が見つかりません" >&2
    exit 1
  fi
}

download_release() {
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir}"' EXIT
  archive="${tmpdir}/pprotein.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${DOWNLOAD_URL}" -o "${archive}"
  else
    need_cmd wget
    wget -q "${DOWNLOAD_URL}" -O "${archive}"
  fi
  tar -xzf "${archive}" -C "${tmpdir}"
  sudo install -m 0755 "${tmpdir}/pprotein-agent" "${INSTALL_DIR}/pprotein-agent"
  if [ -f "${tmpdir}/pprotein" ]; then
    sudo install -m 0755 "${tmpdir}/pprotein" "${INSTALL_DIR}/pprotein"
  fi
}

ensure_permissions() {
  if [ -f "${PPROTEIN_SLOWLOG}" ]; then
    sudo chmod +r "${PPROTEIN_SLOWLOG}"
    slowlog_dir=$(dirname "${PPROTEIN_SLOWLOG}")
    sudo chmod +rx "${slowlog_dir}"
  fi
  if [ -f "${PPROTEIN_HTTPLOG}" ]; then
    sudo chmod +r "${PPROTEIN_HTTPLOG}"
  fi
}

write_service() {
  sudo tee "${SERVICE_FILE}" >/dev/null <<EOF_SERVICE
[Unit]
Description=pprotein agent service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=PORT=${BIND_PORT}
Environment=PPROTEIN_HTTPLOG=${PPROTEIN_HTTPLOG}
Environment=PPROTEIN_SLOWLOG=${PPROTEIN_SLOWLOG}
Environment=PPROTEIN_GIT_REPOSITORY=${REPO_ROOT}
ExecStart=${INSTALL_DIR}/pprotein-agent
WorkingDirectory=${INSTALL_DIR}
Restart=always
RestartSec=2s
User=${SERVICE_USER}

[Install]
WantedBy=multi-user.target
EOF_SERVICE
}

start_service() {
  sudo systemctl daemon-reload
  sudo systemctl enable "${SERVICE_NAME}"
  sudo systemctl restart "${SERVICE_NAME}"
}

stop_service() {
  if systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
    sudo systemctl stop "${SERVICE_NAME}" || true
    sudo systemctl disable "${SERVICE_NAME}" || true
  fi
}

remove_files() {
  sudo rm -f "${SERVICE_FILE}"
  sudo systemctl daemon-reload
  sudo rm -f "${INSTALL_DIR}/pprotein-agent"
  sudo rm -f "${INSTALL_DIR}/pprotein"
}

case "${COMMAND}" in
  install)
    need_cmd tar
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
      echo "[ERROR] curl または wget を用意してください" >&2
      exit 1
    fi
    sudo mkdir -p "${INSTALL_DIR}"
    download_release
    ensure_permissions
    write_service
    start_service
    ;;
  uninstall)
    stop_service
    remove_files
    ;;
  *)
    echo "使い方: $0 {install|uninstall}" >&2
    exit 1
    ;;
 esac
