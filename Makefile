APPNAME := isuhoge-go.service
APP_NAME := isuhoge-go

# infra: ミドルウェア設定の Git 管理
SSH_USER ?= isucon
ISUCON_HOST ?=
NGINX_HOST ?=
MYSQL_HOST ?=
WEBAPP_HOST ?=

.PHONY: *
gogo: stop-services build logs/clear start-services

stop-services:
	sudo systemctl stop nginx
	sudo systemctl stop $(APPNAME)
	sudo systemctl stop mysql
	# ssh isucon-s2 "sudo systemctl stop mysql"

build:
	__FIXME__
	# cd go && make
	# cd go && go build -o isuhoge

logs: limit=10000
logs: opts=
logs:
	journalctl -ex --since "$(shell systemctl status isuride-go.service | grep "Active:" | awk '{print $$6, $$7}')" -n $(limit) -q $(opts)

logs/error:
	$(MAKE) logs opts='--grep "(error|panic|- 500)" --no-pager'

logs/clear:
	sudo journalctl --rotate && sudo journalctl --vacuum-size=1K
	sudo truncate --size 0 /var/log/nginx/access.log
	sudo truncate --size 0 /var/log/nginx/error.log
	sudo truncate --size 0 /var/log/mysql/mysql-slow.log && sudo chmod 666 /var/log/mysql/mysql-slow.log
	sudo truncate --size 0 /var/log/mysql/error.log
	# ssh isucon-s2 "sudo truncate --size 0 /var/log/mysql/mysql-slow.log && chmod 666 /var/log/mysql/mysql-slow.log"
	# ssh isucon-s2 "sudo truncate --size 0 /var/log/mysql/error.log"

start-services:
	sudo systemctl daemon-reload
	# ssh isucon-s2 "sudo systemctl start mysql"
	sudo systemctl start mysql
	sudo systemctl start $(APPNAME)
	sudo systemctl start nginx

# --- infra: ミドルウェア設定ファイルの download / deploy ---

# 大会開始直後: 何が動いているか不明なときはここから
discover-infra:
	./mybin/infra/discover.sh

bootstrap-infra: discover-infra download-detected
	@echo "bootstrap 完了。infra/INVENTORY.md を確認して git add / commit してください"

download-detected:
	./mybin/infra/download.sh detected

deploy-detected:
	./mybin/infra/deploy.sh detected

download-nginx:
	./mybin/infra/download.sh nginx

download-mysql:
	./mybin/infra/download.sh mysql

download-systemd:
	./mybin/infra/download.sh systemd

download-infra: download-detected

download-infra-known: download-nginx download-mysql download-systemd

deploy-nginx:
	./mybin/infra/deploy.sh nginx

deploy-mysql:
	./mybin/infra/deploy.sh mysql

deploy-systemd:
	./mybin/infra/deploy.sh systemd

deploy-infra: deploy-detected

deploy-infra-known: deploy-nginx deploy-mysql deploy-systemd

