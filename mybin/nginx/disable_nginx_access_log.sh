#!/bin/bash

# Nginx設定ファイルパス（適宜変更してください）
NGINX_CONF="/etc/nginx/nginx.conf"

# バックアップを作成
cp $NGINX_CONF ${NGINX_CONF}.bak

# log_formatとaccess_logをコメントアウト
sed -i '/log_format with_time/s/^/# /' $NGINX_CONF
sed -i '/access_log \/var\/log\/nginx\/access.log with_time;/s/^/# /' $NGINX_CONF

# Nginxの設定を再読み込み
nginx -t && systemctl reload nginx

echo "アクセスログを無効化しました。（コメントアウトしました）"

