#!/bin/sh -eu
#
# discover.sh
#   稼働中のミドルウェアと設定パスを洗い出し、infra/INVENTORY.md に記録する
# 使い方:
#   ./mybin/infra/discover.sh
#   ISUCON_HOST=isucon-1 ./mybin/infra/discover.sh
# 出力:
#   infra/INVENTORY.md          人が読む一覧
#   infra/.discover-components  download detected 用（1行1コンポーネント）

. "$(dirname "$0")/common.sh"

HOST=$(resolve_host ISUCON_HOST "${ISUCON_HOST:-}")
INVENTORY="${INFRA_DIR}/INVENTORY.md"
MANIFEST="${INFRA_DIR}/.discover-components"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[WARN] $1 が見つかりません（一部の検出をスキップします）" >&2
    return 1
  fi
}

run_discover() {
  if spec=$(host_spec "$HOST"); then
    "$RSYNC_RSH" "$spec" 'sh -s' < "$(dirname "$0")/discover-remote.sh" > "${TMP}/raw.txt"
  else
    sh "$(dirname "$0")/discover-remote.sh" > "${TMP}/raw.txt"
  fi
}

mkdir -p "$INFRA_DIR"
run_discover

# discover-remote.sh の出力形式:
#   component<TAB>detail
#   listen<TAB>proto:port<TAB>process
#   config<TAB>path
#   service<TAB>unit_name

: > "${TMP}/components"
: > "${TMP}/listen"
: > "${TMP}/config"
: > "${TMP}/service"

while IFS= read -r line || [ -n "$line" ]; do
  kind=${line%%$'\t'*}
  rest=${line#*$'\t'}
  case "$kind" in
    component)
      printf '%s\n' "$rest" >> "${TMP}/components"
      ;;
    listen)
      printf '%s\n' "$rest" >> "${TMP}/listen"
      ;;
    config)
      printf '%s\n' "$rest" >> "${TMP}/config"
      ;;
    service)
      printf '%s\n' "$rest" >> "${TMP}/service"
      ;;
  esac
done < "${TMP}/raw.txt"

sort -u "${TMP}/components" > "$MANIFEST"

generated_at=$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')

{
  echo "# インフラ棚卸し (INVENTORY)"
  echo ""
  echo "- 生成日時: ${generated_at}"
  echo "- 対象ホスト: ${HOST}"
  echo ""
  echo "## 検出されたコンポーネント"
  echo ""
  if [ -s "$MANIFEST" ]; then
    while read -r c; do
      echo "- \`${c}\`"
    done < "$MANIFEST"
  else
    echo "_（コンポーネント未検出）_"
  fi
  echo ""
  echo "## リスニングポート"
  echo ""
  echo '```'
  if [ -s "${TMP}/listen" ]; then
    cat "${TMP}/listen"
  else
    echo "(なし)"
  fi
  echo '```'
  echo ""
  echo "## 設定ファイル・ディレクトリ"
  echo ""
  echo '```'
  if [ -s "${TMP}/config" ]; then
    cat "${TMP}/config"
  else
    echo "(なし)"
  fi
  echo '```'
  echo ""
  echo "## systemd ユニット（アプリ・ミドルウェア関連）"
  echo ""
  echo '```'
  if [ -s "${TMP}/service" ]; then
    cat "${TMP}/service"
  else
    echo "(なし)"
  fi
  echo '```'
  echo ""
  echo "## 次のステップ"
  echo ""
  echo '```sh'
  echo "# 検出結果に基づいて設定を取り込む"
  echo "make bootstrap-infra"
  echo ""
  echo "# または個別"
  echo "make download-detected"
  echo '```'
} > "$INVENTORY"

echo "Wrote ${INVENTORY}"
echo "Wrote ${MANIFEST}"
echo ""
echo "検出コンポーネント:"
cat "$MANIFEST" 2>/dev/null || true
