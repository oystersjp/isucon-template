#!/bin/sh -eu
#
# download.sh
#   サーバ上のミドルウェア設定を infra/ に取り込む
# 使い方:
#   ./mybin/infra/download.sh discover   # 棚卸しのみ（discover.sh と同じ）
#   ./mybin/infra/download.sh detected   # .discover-components に基づく取り込み
#   ./mybin/infra/download.sh systemd-all
#   ./mybin/infra/download.sh nginx|mysql|redis|memcached|php|sysctl|systemd|all

. "$(dirname "$0")/common.sh"

require_cmd rsync

HOST_DEFAULT="${ISUCON_HOST:-}"

download_nginx() {
  host=$(resolve_host NGINX_HOST "$HOST_DEFAULT")
  echo "[download] nginx from ${host}"
  rsync_from_remote /etc/nginx "${INFRA_DIR}/nginx" "$host"
}

download_mysql() {
  host=$(resolve_host MYSQL_HOST "$HOST_DEFAULT")
  echo "[download] mysql from ${host}"
  rsync_from_remote /etc/mysql "${INFRA_DIR}/mysql" "$host"
  if [ -f /etc/my.cnf ] || run_on_host "$host" "test -f /etc/my.cnf" 2>/dev/null; then
    mkdir -p "${INFRA_DIR}/mysql"
    if spec=$(host_spec "$host"); then
      rsync -az -e "$RSYNC_RSH" "${spec}:/etc/my.cnf" "${INFRA_DIR}/mysql/my.cnf" --rsync-path="sudo rsync" 2>/dev/null || true
    elif [ -f /etc/my.cnf ]; then
      sudo cp -p /etc/my.cnf "${INFRA_DIR}/mysql/my.cnf"
      sudo chown "$(id -un)":"$(id -gn)" "${INFRA_DIR}/mysql/my.cnf"
    fi
  fi

  limits_dir="${INFRA_DIR}/systemd/mysql.service.d"
  mkdir -p "$limits_dir"
  if spec=$(host_spec "$host"); then
    "$RSYNC_RSH" "$spec" "sudo test -f /etc/systemd/system/mysql.service.d/limits.conf" 2>/dev/null || return 0
    rsync -az -e "$RSYNC_RSH" \
      "${spec}:/etc/systemd/system/mysql.service.d/limits.conf" \
      "${limits_dir}/limits.conf" \
      --rsync-path="sudo rsync"
  elif [ -f /etc/systemd/system/mysql.service.d/limits.conf ]; then
    sudo cp -p /etc/systemd/system/mysql.service.d/limits.conf "${limits_dir}/limits.conf"
    sudo chown "$(id -un)":"$(id -gn)" "${limits_dir}/limits.conf"
  fi
}

download_redis() {
  host=$(resolve_host REDIS_HOST "$HOST_DEFAULT")
  echo "[download] redis from ${host}"
  if run_on_host "$host" "test -d /etc/redis" 2>/dev/null; then
    rsync_from_remote /etc/redis "${INFRA_DIR}/redis" "$host"
  fi
}

download_memcached() {
  host=$(resolve_host MEMCACHED_HOST "$HOST_DEFAULT")
  echo "[download] memcached from ${host}"
  mkdir -p "${INFRA_DIR}/memcached"
  if spec=$(host_spec "$host"); then
    "$RSYNC_RSH" "$spec" "sudo test -f /etc/memcached.conf" 2>/dev/null && \
      rsync -az -e "$RSYNC_RSH" "${spec}:/etc/memcached.conf" "${INFRA_DIR}/memcached/memcached.conf" --rsync-path="sudo rsync" || true
    run_on_host "$host" "test -d /etc/memcached.d" 2>/dev/null && \
      rsync_from_remote /etc/memcached.d "${INFRA_DIR}/memcached.d" "$host" || true
  else
    [ -f /etc/memcached.conf ] && sudo cp -p /etc/memcached.conf "${INFRA_DIR}/memcached/memcached.conf"
    [ -d /etc/memcached.d ] && rsync_from_remote /etc/memcached.d "${INFRA_DIR}/memcached.d" "$host"
  fi
}

download_php() {
  host=$(resolve_host PHP_HOST "$HOST_DEFAULT")
  echo "[download] php from ${host}"
  if run_on_host "$host" "test -d /etc/php" 2>/dev/null; then
    rsync_from_remote /etc/php "${INFRA_DIR}/php" "$host"
  fi
}

download_sysctl() {
  host=$(resolve_host SYSCTL_HOST "$HOST_DEFAULT")
  echo "[download] sysctl from ${host}"
  mkdir -p "${INFRA_DIR}/etc"
  if spec=$(host_spec "$host"); then
    "$RSYNC_RSH" "$spec" "sudo test -f /etc/sysctl.conf" 2>/dev/null && \
      rsync -az -e "$RSYNC_RSH" "${spec}:/etc/sysctl.conf" "${INFRA_DIR}/etc/sysctl.conf" --rsync-path="sudo rsync" || true
    run_on_host "$host" "test -d /etc/sysctl.d" 2>/dev/null && \
      rsync_from_remote /etc/sysctl.d "${INFRA_DIR}/etc/sysctl.d" "$host" || true
  else
    [ -f /etc/sysctl.conf ] && sudo cp -p /etc/sysctl.conf "${INFRA_DIR}/etc/sysctl.conf"
    [ -d /etc/sysctl.d ] && rsync_from_remote /etc/sysctl.d "${INFRA_DIR}/etc/sysctl.d" "$host"
  fi
}

download_systemd() {
  host=$(resolve_host WEBAPP_HOST "$HOST_DEFAULT")
  app_service=$(resolve_app_service)
  service_file="${app_service}.service"
  dest_dir="${INFRA_DIR}/systemd/system"
  mkdir -p "$dest_dir"

  echo "[download] systemd ${service_file} from ${host}"
  if spec=$(host_spec "$host"); then
    "$RSYNC_RSH" "$spec" "sudo test -f /etc/systemd/system/${service_file}" 2>/dev/null || {
      echo "[WARN] /etc/systemd/system/${service_file} が見つかりません" >&2
      return 0
    }
    rsync -az -e "$RSYNC_RSH" \
      "${spec}:/etc/systemd/system/${service_file}" \
      "${dest_dir}/${service_file}" \
      --rsync-path="sudo rsync"
  elif [ -f "/etc/systemd/system/${service_file}" ]; then
    sudo cp -p "/etc/systemd/system/${service_file}" "${dest_dir}/${service_file}"
    sudo chown "$(id -un)":"$(id -gn)" "${dest_dir}/${service_file}"
  else
    echo "[WARN] /etc/systemd/system/${service_file} が見つかりません" >&2
  fi
}

download_systemd_all() {
  host=$(resolve_host WEBAPP_HOST "$HOST_DEFAULT")
  dest_dir="${INFRA_DIR}/systemd/system"
  mkdir -p "$dest_dir"
  echo "[download] systemd units (custom) from ${host}"

  if spec=$(host_spec "$host"); then
    units=$("$RSYNC_RSH" "$spec" "sudo ls /etc/systemd/system/*.service 2>/dev/null" || true)
  else
    units=$(ls /etc/systemd/system/*.service 2>/dev/null || true)
  fi

  for path in $units; do
    base=$(basename "$path")
    case "$base" in
      dbus-* | getty@* | serial-getty@* | systemd-* | cloud-* | snap-*)
        continue
        ;;
    esac
    if spec=$(host_spec "$host"); then
      rsync -az -e "$RSYNC_RSH" \
        "${spec}:/etc/systemd/system/${base}" \
        "${dest_dir}/${base}" \
        --rsync-path="sudo rsync" 2>/dev/null || true
    elif [ -f "/etc/systemd/system/${base}" ]; then
      sudo cp -p "/etc/systemd/system/${base}" "${dest_dir}/${base}"
      sudo chown "$(id -un)":"$(id -gn)" "${dest_dir}/${base}" 2>/dev/null || true
    fi
  done
}

component_to_download() {
  comp="$1"
  case "$comp" in
    nginx) download_nginx ;;
    mysql | mariadb | bin:mysqld | bin:mariadbd) download_mysql ;;
    redis-server | redis | bin:redis-server) download_redis ;;
    memcached | bin:memcached) download_memcached ;;
    php*|bin:php-fpm) download_php ;;
    *)
      echo "[skip] 未対応コンポーネント: ${comp}" >&2
      ;;
  esac
}

download_detected() {
  manifest="${INFRA_DIR}/.discover-components"
  if [ ! -f "$manifest" ]; then
    echo "[ERROR] ${manifest} がありません。先に make discover-infra を実行してください" >&2
    exit 1
  fi
  echo "[download] detected components"
  download_sysctl
  while read -r comp; do
    [ -n "$comp" ] || continue
    component_to_download "$comp"
  done < "$manifest"
  download_systemd_all
}

case "${1:-}" in
  discover)
    exec "$(dirname "$0")/discover.sh"
    ;;
  detected)
    download_detected
    ;;
  nginx)
    download_nginx
    ;;
  mysql)
    download_mysql
    ;;
  redis)
    download_redis
    ;;
  memcached)
    download_memcached
    ;;
  php)
    download_php
    ;;
  sysctl)
    download_sysctl
    ;;
  systemd)
    download_systemd
    ;;
  systemd-all)
    download_systemd_all
    ;;
  all)
    download_sysctl
    download_nginx
    download_mysql
    download_redis
    download_memcached
    download_php
    download_systemd_all
    ;;
  *)
    echo "使い方: $0 {discover|detected|nginx|mysql|redis|memcached|php|sysctl|systemd|systemd-all|all}" >&2
    exit 1
    ;;
esac
