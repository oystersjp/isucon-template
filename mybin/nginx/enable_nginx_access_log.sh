#!/bin/bash -eu

# Nginx設定ファイルパス（適宜変更してください）
NGINX_CONF="/etc/nginx/nginx.conf"

# access_logのコメントアウトを解除
sudo sed -i '/access_log off;/d' $NGINX_CONF
sudo sed -i '/# access_log \/var\/log\/nginx\/access.log with_time;/s/^# //' $NGINX_CONF

# Nginxの設定を再読み込み
sudo nginx -t && sudo systemctl reload nginx

