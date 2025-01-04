#!/bin/bash -eu

# Nginx設定ファイルパス（適宜変更してください）
NGINX_CONF="/etc/nginx/nginx.conf"

# access_log を有効化
sed -i 's#^[[:space:]]*access_log[[:space:]].*#access_log /var/log/nginx/access.log with_time;#' "$NGINX_CONF"

# Nginxの設定を再読み込み
sudo nginx -t && sudo systemctl reload nginx

