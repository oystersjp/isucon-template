#!/bin/sh
# discover-remote.sh
#   対象ホスト上で実行され、TAB 区切りで検出結果を stdout に出す
#   （discover.sh から pipe / ssh で呼ばれる）

emit() {
  printf '%s\t%s\n' "$1" "$2"
}

unit_active() {
  systemctl is-active --quiet "$1" 2>/dev/null
}

unit_exists() {
  systemctl list-unit-files "$1" 2>/dev/null | grep -q "^${1}"
}

# --- コンポーネント検出（プロセス / systemd）---

for unit in nginx mysql mariadb redis-server redis memcached php8.3-fpm php8.2-fpm php8.1-fpm php-fpm \
  postgresql envoy haproxy varnish; do
  if unit_active "$unit" || unit_active "${unit}.service" 2>/dev/null; then
    emit component "$unit"
  fi
done

# バイナリがあれば補足（systemd 名が違う大会向け）
for bin in nginx mysqld mariadbd redis-server memcached php-fpm postmaster envoy haproxy varnishd; do
  if command -v "$bin" >/dev/null 2>&1; then
    emit component "bin:${bin}"
  fi
done

# --- リスニングポート ---
if command -v ss >/dev/null 2>&1; then
  ss -lntp 2>/dev/null | awk 'NR>1 {print}' | while read -r _ _ local _ proc; do
    emit listen "${local}	${proc}"
  done
elif command -v netstat >/dev/null 2>&1; then
  netstat -lntp 2>/dev/null | awk 'NR>2 {print $1,$4,$7}' | while read -r proto local proc; do
    emit listen "${proto}:${local}	${proc}"
  done
fi

# --- 設定パス ---
if [ -d /etc/nginx ]; then
  emit config /etc/nginx
  if command -v nginx >/dev/null 2>&1; then
    nginx -V 2>&1 | head -n 5 | while read -r line; do
      emit config "nginx -V: ${line}"
    done
  fi
fi

if [ -d /etc/mysql ]; then
  emit config /etc/mysql
fi
if [ -f /etc/my.cnf ]; then
  emit config /etc/my.cnf
fi
if [ -d /etc/mysql/mysql.conf.d ]; then
  emit config /etc/mysql/mysql.conf.d
fi

if command -v mysqld >/dev/null 2>&1; then
  mysqld --verbose --help 2>/dev/null | grep -A1 'Default options' | while read -r line; do
    emit config "mysqld: ${line}"
  done || true
fi

if [ -d /etc/redis ]; then
  emit config /etc/redis
fi
if [ -f /etc/redis/redis.conf ]; then
  emit config /etc/redis/redis.conf
fi

if [ -f /etc/memcached.conf ]; then
  emit config /etc/memcached.conf
fi
if [ -d /etc/memcached.d ]; then
  emit config /etc/memcached.d
fi

if [ -d /etc/php ]; then
  find /etc/php -maxdepth 3 -type f -name '*.conf' 2>/dev/null | head -n 20 | while read -r f; do
    emit config "$f"
  done
fi

if [ -f /etc/sysctl.conf ]; then
  emit config /etc/sysctl.conf
fi
if [ -d /etc/sysctl.d ]; then
  emit config /etc/sysctl.d
fi

# --- systemd: /etc/systemd/system 配下のカスタムユニット ---
if [ -d /etc/systemd/system ]; then
  for f in /etc/systemd/system/*.service; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      dbus-* | getty@* | serial-getty@* | systemd-* | cloud-* | snap-*)
        continue
        ;;
    esac
    emit service "$base"
  done
fi

# Makefile の APP_NAME が不明なとき用: isucon っぽい名前
for f in /etc/systemd/system/*isucon*.service /etc/systemd/system/*-go.service; do
  [ -f "$f" ] || continue
  emit service "$(basename "$f")"
done
