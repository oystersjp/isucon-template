#!/bin/sh -eu
#
# deploy.sh
#   infra/ のミドルウェア設定をサーバへ反映する

. "$(dirname "$0")/common.sh"

require_cmd rsync

HOST_DEFAULT="${ISUCON_HOST:-}"

deploy_nginx() {
  [ -d "${INFRA_DIR}/nginx" ] || return 0
  host=$(resolve_host NGINX_HOST "$HOST_DEFAULT")
  echo "[deploy] nginx to ${host}"
  rsync_to_remote "${INFRA_DIR}/nginx" /etc/nginx "$host"
  run_on_host "$host" "sudo nginx -t && sudo systemctl reload nginx"
}

deploy_mysql() {
  [ -d "${INFRA_DIR}/mysql" ] || return 0
  host=$(resolve_host MYSQL_HOST "$HOST_DEFAULT")
  echo "[deploy] mysql to ${host}"
  rsync_to_remote "${INFRA_DIR}/mysql" /etc/mysql "$host"
  if [ -f "${INFRA_DIR}/mysql/my.cnf" ]; then
    copy_file_to_remote "${INFRA_DIR}/mysql/my.cnf" /etc/my.cnf "$host"
  fi

  limits_file="${INFRA_DIR}/systemd/mysql.service.d/limits.conf"
  if [ -f "$limits_file" ]; then
    copy_file_to_remote "$limits_file" /etc/systemd/system/mysql.service.d/limits.conf "$host"
    run_on_host "$host" "sudo systemctl daemon-reload"
  fi

  run_on_host "$host" "sudo systemctl restart mysql 2>/dev/null || sudo systemctl restart mariadb 2>/dev/null || true"
}

deploy_redis() {
  [ -d "${INFRA_DIR}/redis" ] || return 0
  host=$(resolve_host REDIS_HOST "$HOST_DEFAULT")
  echo "[deploy] redis to ${host}"
  rsync_to_remote "${INFRA_DIR}/redis" /etc/redis "$host"
  run_on_host "$host" "sudo systemctl restart redis-server 2>/dev/null || sudo systemctl restart redis 2>/dev/null || true"
}

deploy_memcached() {
  host=$(resolve_host MEMCACHED_HOST "$HOST_DEFAULT")
  if [ -f "${INFRA_DIR}/memcached/memcached.conf" ]; then
    echo "[deploy] memcached.conf to ${host}"
    copy_file_to_remote "${INFRA_DIR}/memcached/memcached.conf" /etc/memcached.conf "$host"
  fi
  if [ -d "${INFRA_DIR}/memcached.d" ]; then
    rsync_to_remote "${INFRA_DIR}/memcached.d" /etc/memcached.d "$host"
  fi
  run_on_host "$host" "sudo systemctl restart memcached 2>/dev/null || true"
}

deploy_php() {
  [ -d "${INFRA_DIR}/php" ] || return 0
  host=$(resolve_host PHP_HOST "$HOST_DEFAULT")
  echo "[deploy] php to ${host}"
  rsync_to_remote "${INFRA_DIR}/php" /etc/php "$host"
  run_on_host "$host" "sudo systemctl restart php8.3-fpm 2>/dev/null || sudo systemctl restart php-fpm 2>/dev/null || true"
}

deploy_sysctl() {
  host=$(resolve_host SYSCTL_HOST "$HOST_DEFAULT")
  if [ -f "${INFRA_DIR}/etc/sysctl.conf" ]; then
    copy_file_to_remote "${INFRA_DIR}/etc/sysctl.conf" /etc/sysctl.conf "$host"
  fi
  if [ -d "${INFRA_DIR}/etc/sysctl.d" ]; then
    rsync_to_remote "${INFRA_DIR}/etc/sysctl.d" /etc/sysctl.d "$host"
  fi
  run_on_host "$host" "sudo sysctl -p 2>/dev/null || true"
}

deploy_systemd() {
  host=$(resolve_host WEBAPP_HOST "$HOST_DEFAULT")
  app_service=$(resolve_app_service)
  service_file="${app_service}.service"
  local_file="${INFRA_DIR}/systemd/system/${service_file}"

  if [ ! -f "$local_file" ]; then
    echo "[WARN] ${local_file} が無いため systemd deploy をスキップします" >&2
    return 0
  fi

  echo "[deploy] systemd ${service_file} to ${host}"
  copy_file_to_remote "$local_file" "/etc/systemd/system/${service_file}" "$host"
  run_on_host "$host" "sudo systemctl daemon-reload && sudo systemctl restart ${app_service}"
}

deploy_systemd_all() {
  host=$(resolve_host WEBAPP_HOST "$HOST_DEFAULT")
  dest_dir="${INFRA_DIR}/systemd/system"
  [ -d "$dest_dir" ] || return 0

  echo "[deploy] systemd units to ${host}"
  for local_file in "$dest_dir"/*.service; do
    [ -f "$local_file" ] || continue
    base=$(basename "$local_file")
    copy_file_to_remote "$local_file" "/etc/systemd/system/${base}" "$host"
  done
  run_on_host "$host" "sudo systemctl daemon-reload"
}

component_to_deploy() {
  comp="$1"
  case "$comp" in
    nginx) deploy_nginx ;;
    mysql | mariadb | bin:mysqld | bin:mariadbd) deploy_mysql ;;
    redis-server | redis | bin:redis-server) deploy_redis ;;
    memcached | bin:memcached) deploy_memcached ;;
    php*|bin:php-fpm) deploy_php ;;
    *) ;;
  esac
}

deploy_detected() {
  manifest="${INFRA_DIR}/.discover-components"
  if [ ! -f "$manifest" ]; then
    echo "[ERROR] ${manifest} がありません。先に make discover-infra を実行してください" >&2
    exit 1
  fi
  deploy_sysctl
  while read -r comp; do
    [ -n "$comp" ] || continue
    component_to_deploy "$comp"
  done < "$manifest"
  deploy_systemd_all
}

case "${1:-}" in
  detected)
    deploy_detected
    ;;
  nginx)
    deploy_nginx
    ;;
  mysql)
    deploy_mysql
    ;;
  redis)
    deploy_redis
    ;;
  memcached)
    deploy_memcached
    ;;
  php)
    deploy_php
    ;;
  sysctl)
    deploy_sysctl
    ;;
  systemd)
    deploy_systemd
    ;;
  systemd-all)
    deploy_systemd_all
    ;;
  all)
    deploy_sysctl
    deploy_nginx
    deploy_mysql
    deploy_redis
    deploy_memcached
    deploy_php
    deploy_systemd_all
    ;;
  *)
    echo "使い方: $0 {detected|nginx|mysql|redis|memcached|php|sysctl|systemd|systemd-all|all}" >&2
    exit 1
    ;;
esac
