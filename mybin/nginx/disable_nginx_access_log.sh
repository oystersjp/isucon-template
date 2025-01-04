#!/bin/bash -eu

# Nginx設定ファイルパス（適宜変更してください）
NGINX_CONF="/etc/nginx/nginx.conf"

# access_logをコメントアウト
sudo sed -i '/^access_log \/var\/log\/nginx\/access.log with_time;/s/^/# /' $NGINX_CONF
sudo sed -i "/http {/a\    access_log off;" $NGINX_CONF
# Nginxの設定を再読み込み
sudo nginx -t && sudo systemctl reload nginx
