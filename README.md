# isucon-template

## 初期セットアップ

競技開始後、`/home/isucon` 直下にこのリポジトリを clone し、以下のスクリプトを実行します。

```bash
cd /home/isucon
git clone <this-repo> isucon-template
bash isucon-template/mybin/setup.sh
```

スクリプトは対話式で以下を順に処理します。

1. **バックアップ** — `webapp` → `webapp_bk` にコピー
2. **言語ディレクトリ選定** — `go` / `perl` / `ruby` / `python` / `node` / `rust` 等を自動検出し、使用言語を番号で選択。残りは削除確認
3. **その他ファイル整理** — 残りのディレクトリ・ファイルを1件ずつ `[k]eep / [d]elete / [i]gnore` で選択
4. **Makefile 設定** — `APPNAME`（systemd サービス名）とビルドコマンドを入力
5. **ファイル移動** — `webapp` の中身をリポジトリ直下に移動
6. **`.gitignore` 更新** — Step 3 で `[i]` を選んだ項目を追記
7. **Makefile 書き換え** — 入力した `APPNAME` とビルドコマンドを反映
8. **ディレクトリリネーム** — リポジトリを `webapp` にリネーム（元の構造に一致させる）

完了後は `/home/isucon/webapp` がリポジトリになります。

## /etc 設定の git 管理 (etc-sync)

複数台の `/etc` 配下の主要設定を `infra/<host>/etc/...` に収集し、このリポジトリで差分管理します。対象サーバと収集パスは `conf.yaml` に書きます。

```yaml
hosts:
  s1: isucon-s1
  s2: isucon-s2

includes:
  - /etc/sysctl.conf
  - /etc/sysctl.d
  - /etc/security/limits.conf
  - /etc/hosts

excludes:
  - "*.bak"
  - "*.sock"

host_includes:
  s1:
    - /etc/nginx/nginx.conf
    - /etc/mysql/mysql.conf.d/mysqld.cnf
  s2:
    - /etc/systemd/system
    - /etc/nginx/sites-enabled

host_excludes:
  s1:
    - "*.tmp"
```

- `hosts` のキーがリポジトリ内の保存先 `infra/<host>/etc/...` になります。
- `hosts` の値は `ssh` コマンドで接続できるエイリアス、または `user@host` です。
- `make etc-sync/*` は本番サーバーのどれか1台で実行する想定です。実行元サーバーから、自分自身を含む `hosts` の全接続先へ `ssh` できるようにしてください。
- `includes` にはファイルとディレクトリのどちらも指定できます。例: `/etc/nginx/nginx.conf`、`/etc/mysql/mysql.conf.d/mysqld.cnf`、`/etc/systemd/system`。
- `host_includes` / `host_excludes` は指定したホストにだけ追加適用されます。サーバごとに nginx だけ、mysql だけ、systemd だけ、のように管理対象を分けられます。
- `deploy` も対象ホストの `includes` + `host_includes` に含まれるファイル/ディレクトリだけを反映します。
- `conf.yaml` は shell で読むための限定形式です。YAML の入れ子、アンカー、複雑なクォートは扱いません。

よく使う操作:

```
make etc-sync/pull          # 全ホストから infra/<host>/etc/... へ収集
make etc-sync/diff          # 収集前の差分を dry-run で確認
make etc-sync/deploy        # リポジトリから /etc への反映差分を dry-run で確認
make etc-sync/deploy/apply  # 実際に /etc へ反映
```

特定ホストだけ操作する場合:

```
./mybin/etc-sync/etc-sync.sh pull s1
./mybin/etc-sync/etc-sync.sh deploy s1
./mybin/etc-sync/etc-sync.sh deploy --apply s1
```

`deploy` は事故防止のため既定で dry-run です。実反映には `--apply` を明示してください。`rsync` は remote 側で `sudo rsync` を使い、`--no-owner --no-group` を付けてローカルの所有者・グループ情報を `/etc` へ誤反映しないようにしています。

## pprotein セットアップ

pprotein サーバ（UI :9000）は構築済み前提です。競技ホストの準備と targets / alp 登録は **`mybin/pprotein/pprotein-setup.sh`** で行います。AWS SG の 19000/19001 許可は人が手動で行います（スクリプトは触りません）。

### 競技ホスト上

```sh
cd /path/to/isucon-template
sudo ./mybin/pprotein/pprotein-setup.sh nginx on    # LTSV access_log
sudo ./mybin/pprotein/pprotein-setup.sh mysql on    # slow_query_log
sudo ./mybin/pprotein/pprotein-setup.sh agent install
./mybin/pprotein/pprotein-setup.sh verify
```

- `agent install` は内部で `setup.sh install` を呼びます（graphviz / agent / systemd / ACL）。
- ログパスが違うときは `PPROTEIN_HTTPLOG` / `PPROTEIN_SLOWLOG` を合わせて指定します。
- 最終ベンチ前にログを止める例: `sudo ./mybin/pprotein/pprotein-setup.sh nginx off`

### pprotein API（手元や到達できるマシン）

```sh
export PPROTEIN_URL=http://<pprotein-host>:9000
./mybin/pprotein/pprotein-setup.sh targets --host s1=<ip> --host s2=<ip> --app-pprof s1
./mybin/pprotein/pprotein-setup.sh alp --group '^/api/items/[^/]+$'
```

Webhook（Initialize から GET）: `http://<pprotein-host>:9000/api/group/collect`

### アプリ側（Go）

`github.com/kaz/pprotein/integration/standalone` で `:19001` を出し、Initialize 先頭から上記 webhook を非同期 GET します。詳細は `.agents/skills/pprotein-setup/reference.md`。古い Echo middleware / POST `:19000/webhook` 例は使いません。

### pprotein サーバ上の alp / slp

未導入なら pprotein ホストで alp / slp を入れる（バージョンは適宜読み替え）:

```sh
ALP_VERSION=1.0.21 ALP_ARCH=linux_amd64
curl -fsSL "https://github.com/tkuchiki/alp/releases/download/v${ALP_VERSION}/alp_${ALP_VERSION}_${ALP_ARCH}.tar.gz" -o /tmp/alp.tar.gz
tar -xzf /tmp/alp.tar.gz -C /tmp && sudo install -m 0755 /tmp/alp /usr/local/bin/alp
```

targets と httplog/config は UI でも登録できますが、通常は上記 `pprotein-setup.sh targets` / `alp` を使います。
