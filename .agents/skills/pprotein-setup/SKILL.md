---
name: pprotein-setup
description: >-
  Set up pprotein profiling for any ISUCON contest end-to-end: discover hosts
  and app layout, install pprotein-agent, enable DB slowlog, convert nginx/apache
  access logs to LTSV, wire app pprof and initialize collect webhook, open
  firewall/SG, register group/targets and alp matching_groups. Use when the user
  asks for pprotein setup, group/targets, httplog/config, alp config, or agent
  install on competition servers.
---

# pprotein Setup (any ISUCON)

## Purpose

任意の ISUCON 問題で、計測対象サーバと構築済み pprotein サーバをつなぎ Collect できる状態にする。

**最終アウトプット（必須）:**
1. `group/targets` JSON（対象ホストごと）
2. alp `httplog/config`（`matching_groups`）
3. Webhook URL: `http://<pprotein-host>:9000/api/group/collect`

pprotein 本体（UI / alp / slp）は構築済み前提。未構築ならこのスキルでは扱わない。

問題固有のパス・サービス名・言語は **推測せず、リポジトリとサーバを調べて決める**。

## Architecture (default)

| Role | Port | Process | Provides |
|------|------|---------|----------|
| agent | 19000 | `pprotein-agent` | httplog / slowlog |
| app pprof | 19001 | アプリプロセス内 debug handler | **アプリ**の pprof |
| UI | 9000 | pprotein | Collect / alp / slp |

- agent の pprof はアプリではない。アプリ CPU プロファイルが必要なら app 側でも公開する。
- 古い README の Echo `pkg/middleware` / POST webhook 例は現行では使わない。
- Collect webhook は **GET** `/api/group/collect`。

## Phase 0 — Discover (必須・最初に行う)

不明ならユーザーに確認。分かった値を以降で使う。

1. **対象ホスト**: SSH alias、Public IP（別 VPC なら必須）、Private IP
2. **pprotein**: SSH alias / base URL（例 `http://x.x.x.x:9000`）
3. **アプリ配置**: リポジトリ root、`webapp` 相当のパス、実装言語（Go / 他）
4. **Initialize エンドポイント**: パスとハンドラ関数名（`/initialize`, `/api/initialize` など）
5. **プロセス管理**: systemd unit 名、バイナリパス、環境変数ファイル（`env.sh` 等）
6. **ログパス**: nginx/apache access log、MySQL/MariaDB/PostgreSQL slow log
7. **補助スクリプト有無**: `mybin/pprotein/setup.sh`, `mybin/mysql/mysql_slow_query.sh` など（無ければ同等手順を手で行う）
8. **DB 種別**: MySQL 系 / Postgres 等（slowlog の有効化方法が変わる）

## Workflow

```
- [ ] 0. Discover（ホスト・言語・unit・ログ・Initialize）
- [ ] 1. agent install（全対象ホスト）
- [ ] 2. DB slowlog ON
- [ ] 3. アクセスログを LTSV 化 + reload
- [ ] 4. SG/firewall: pprotein → 19000/19001
- [ ] 5. アプリ: pprof(:19001) + Initialize webhook + env
- [ ] 6. ビルド / サービス再起動
- [ ] 7. group/targets 登録
- [ ] 8. alp matching_groups 登録（ルートから生成）
- [ ] 9. 疎通確認 → 最終成果物を提示
```

### 1) Agent

補助スクリプトがある場合:

```sh
cd <repo-root>   # 例: ~/webapp
sudo DEBIAN_FRONTEND=noninteractive ./mybin/pprotein/setup.sh install
```

無い場合は pprotein release の `pprotein-agent` を配置し、systemd で `:19000` 起動。環境変数:

- `PPROTEIN_HTTPLOG`（既定 `/var/log/nginx/access.log`）
- `PPROTEIN_SLOWLOG`（既定 `/var/log/mysql/mysql-slow.log` — 実パスに合わせる）
- `PPROTEIN_GIT_REPOSITORY`（リポジトリ root）

`mybin` が一部ホストに無いときは、あるホストから `rsync` するか、リポジトリを揃える。

### 2) DB slowlog

- **MySQL/MariaDB**: リポジトリの helper があればそれを使う。無ければ `slow_query_log=ON` と log file を設定して restart。
- **PostgreSQL** 等: 問題の標準手順に従う（`log_min_duration_statement` など）。agent の `PPROTEIN_SLOWLOG` を実ファイルに合わせる。

### 3) Access log → LTSV

リバースプロキシ（多くは nginx）の access log を alp 向け LTSV にする。フォーマットは [reference.md](reference.md)。`nginx -t` 後に reload。apache の場合も同等の LTSV に揃える。

### 4) Network

pprotein の IP から各競技サーバの **TCP 19000 / 19001** を許可（AWS SG / ufw / security group）。

### 5) App instrumentation

言語に応じて最小差分で入れる。詳細は [reference.md](reference.md)。

**Go（標準）:**
1. `go standalone.Integrate(":19001")` をアプリ起動と別に goroutine で
2. Initialize ハンドラ先頭で collect webhook（非同期 GET、失敗しても初期化は継続）
3. 環境変数 `PPROTEIN_WEBHOOK_URL`

**Go 以外:**
- アプリプロセスで pprof 相当を `:19001` に出せなければ、targets の `pprof` は agent `:19000` に落とす（アプリ CPU ではない旨を注記）
- Initialize 相当から webhook GET を非同期で叩く（言語の HTTP client で可）

既存の Initialize 付随処理（Slack 通知など）は消さず併存させる。

### 6) group/targets

ホスト Label は invent せず、discover した名前（`s1` / `isucon-1` 等）を使う。各ホスト 3 行（Duration 既定 10）:

| Type | URL |
|------|-----|
| pprof | `http://<reachable-ip>:19001/debug/pprof/profile`（app pprof 無しなら `:19000/...`） |
| httplog | `http://<reachable-ip>:19000/debug/log/httplog` |
| slowlog | `http://<reachable-ip>:19000/debug/log/slowlog` |

`<reachable-ip>` は pprotein から届くアドレス（別 VPC なら Public）。

### 7) alp matching_groups

**その問題のルート定義から生成する。** 固定の問題別リストをコピペしない。

手順:
1. ルータ / OpenAPI / フレームワークのルート一覧を収集
2. パスパラメータ（`:id`, `{id}`, `<id>` 等）を含むものだけ残す
3. 可変セグメントを `[^/]+` 等に置換した regex を `matching_groups` にする
4. クエリ文字列は通常マッチ対象外（uri の path 側）

生成ルール・例は [reference.md](reference.md)。

### 8) Verify

tail 系はブロックし得るので **`--max-time` 必須**:

```sh
curl -s -o /dev/null -w "%{http_code}\n" --connect-timeout 3 --max-time 3 \
  http://<ip>:19000/debug/pprof/
curl -s -o /dev/null -w "%{http_code}\n" --connect-timeout 3 --max-time 3 \
  http://<ip>:19001/debug/pprof/
```

pprotein ホストから全 target IP で 200 を確認。

## Agent Behavior

1. 問題固有の API パス・unit 名・ディレクトリをハードコードしない。必ず Discover。
2. 最終回答に **group/targets**・**matching_groups**・**Webhook URL**・使った前提（ホスト/IP）を含める。
3. Public IP をデフォルト（Private 到達確認時のみ Private）。
4. pprotein 本体の新規構築はしない。
5. 既存 Initialize 周辺を破壊しない。
6. 秘密情報をログや PR に出さない。

## References

- テンプレ・生成ルール: [reference.md](reference.md)
