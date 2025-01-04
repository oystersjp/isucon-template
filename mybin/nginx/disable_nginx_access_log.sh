#!/bin/bash -eu

# Nginx設定ファイルパス（適宜変更してください）
NGINX_CONF="/etc/nginx/nginx.conf"

# access_log を無効化（OFFに設定）
sudo sed -i 's#^[[:space:]]*access_log[[:space:]].*#access_log off;#' "$NGINX_CONF"

# Nginxの設定を再読み込み
sudo nginx -t && sudo systemctl reload nginx
