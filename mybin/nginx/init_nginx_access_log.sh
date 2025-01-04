#!/bin/bash

# Nginx設定ファイルパス（適宜変更してください）
NGINX_CONF="/etc/nginx/nginx.conf"

# バックアップを作成
if [ ! -f ${NGINX_CONF}.bak ]; then
    cp $NGINX_CONF ${NGINX_CONF}.bak
    echo "設定ファイルのバックアップを作成しました: ${NGINX_CONF}.bak"
else
    echo "バックアップはすでに存在します: ${NGINX_CONF}.bak"
fi

# log_formatとaccess_logの初期設定
LOG_FORMAT="# log_format with_time '\$remote_addr - \$remote_user [\$time_local] '\
#                     '\"\$request\" \$status \$body_bytes_sent '\
#                     '\"\$http_referer\" \"\$http_user_agent\" \$request_time';"
ACCESS_LOG="# access_log /var/log/nginx/access.log with_time;"
ACCESS_LOG_OFF="# access_log off;"

# httpブロック内に設定を追加
if grep -q "log_format with_time" $NGINX_CONF; then
    echo "log_format設定はすでに存在します。"
else
    sed -i "/http {/a\    $LOG_FORMAT" $NGINX_CONF
    echo "log_format設定を追加しました。"
fi

if grep -q "access_log /var/log/nginx/access.log with_time;" $NGINX_CONF; then
    echo "access_log設定はすでに存在します。"
else
    sed -i "/http {/a\    $ACCESS_LOG" $NGINX_CONF
    echo "access_log設定を追加しました。"
fi

if grep -q "access_log off;" $NGINX_CONF; then
    echo "access_log off; 設定はすでに存在します。"
else
    sed -i "/http {/a\    $ACCESS_LOG_OFF" $NGINX_CONF
    echo "access_log off; 設定を追加しました。"
fi

# Nginxの設定を再読み込み
nginx -t && systemctl reload nginx

echo "初期設定を完了しました。（デフォルトではアクセスログは無効化されています）"

