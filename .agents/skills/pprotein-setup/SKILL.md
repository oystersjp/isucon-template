---
name: pprotein-setup
description: >-
  Prepare pprotein profiling for any ISUCON contest: discover hosts and app
  layout from the repo, draft app pprof/webhook patches, generate group/targets
  and alp matching_groups, and hand the user a copy-paste server runbook.
  Server SSH and AWS SG changes are out of scope unless the user explicitly
  asks. Use when the user asks for pprotein setup, group/targets, httplog/config,
  alp config, or agent install instructions.
---

# pprotein Setup (any ISUCON)

## Purpose

任意の ISUCON 問題で、計測対象サーバと構築済み pprotein サーバをつなぎ Collect できる状態にする。

**最終アウトプット（必須）:**
1. `group/targets` JSON（対象ホストごと）
2. alp `httplog/config`（`matching_groups`）
3. Webhook URL: `http://<pprotein-host>:9000/api/group/collect`
4. **サーバー手動ランブック**（agent / slowlog / LTSV / 再起動のコピペ手順）

pprotein 本体（UI / alp / slp）は構築済み前提。未構築ならこのスキルでは扱わない。

問題固有のパス・サービス名・言語は **推測せず、リポジトリを調べて決める**。サーバ上の事実が必要ならユーザーに確認する（Discover で SSH しない）。

## Ownership (誰が何をするか)

| 担当 | やること |
|------|----------|
| **エージェント** | リポジトリ調査、アプリ差分の下書き、targets / matching_groups 生成、手動ランブック作成 |
| **ユーザー（手動）** | 競技サーバへの SSH、agent 導入、slowlog / nginx、デプロイ・再起動、ネットワーク許可 |

- サーバー操作は **ユーザー手動が既定**。エージェントは手順とコマンドを渡す。
- SSH 実行は、ユーザーが明示したときだけ。
- **AWS SG / クラウド FW のルール追加・変更はしない**（依頼されてもやらない）。必要なポートはランブックに書くだけ。
- サーバ上で **git branch を勝手に変えない**（`checkout` / `switch` / ブランチを変える `pull` 禁止）。現在のブランチのまま作業する。ブランチ変更が必要ならユーザーに依頼する。

## Architecture (default)

| Role | Port | Process | Provides |
|------|------|---------|----------|
| agent | 19000 | `pprotein-agent` | httplog / slowlog |
| app pprof | 19001 | アプリプロセス内 debug handler | **アプリ**の pprof |
| UI | 9000 | pprotein | Collect / alp / slp |

- agent の pprof はアプリではない。アプリ CPU プロファイルが必要なら app 側でも公開する。
- 古い README の Echo `pkg/middleware` / POST webhook 例は現行では使わない。
- Collect webhook は **GET** `/api/group/collect`。

## Phase 0 — Discover（リポジトリ中心）

不明ならユーザーに確認。分かった値を以降で使う。**この段階では SSH しない。**

1. **対象ホスト**: SSH alias、Public IP（別 VPC なら必須）、Private IP（ユーザーから）
2. **pprotein**: base URL（例 `http://x.x.x.x:9000`）
3. **アプリ配置**: リポジトリ root、`webapp` 相当のパス、実装言語（Go / 他）
4. **Initialize エンドポイント**: パスとハンドラ関数名（`/initialize`, `/api/initialize` など）
5. **プロセス管理**: systemd unit 名、バイナリパス、環境変数ファイル（`env.sh` 等）
6. **ログパス**: nginx/apache access log、MySQL/MariaDB/PostgreSQL slow log（コード・docs・既存 mybin から推定し、不明なら確認）
7. **補助スクリプト有無**: `mybin/pprotein/setup.sh`, `mybin/mysql/mysql_slow_query.sh` など
8. **DB 種別**: MySQL 系 / Postgres 等

## Workflow

```
- [ ] 0. Discover（リポジトリ + ユーザー確認。SSH しない）
- [ ] 1. アプリ差分下書き: pprof(:19001) + Initialize webhook + env
- [ ] 2. group/targets 生成
- [ ] 3. alp matching_groups 生成（ルートから）
- [ ] 4. 手動ランブック作成（agent / slowlog / LTSV / 再起動 / 疎通 curl）
- [ ] 5. ネットワーク前提を注記のみ（SG は触らない）
- [ ] 6. 最終成果物を提示 → ユーザーがサーバ作業
```

ユーザーが「サーバでやって」と明示した場合のみ、ランブックの該当ステップを SSH で実行してよい。その場合も **branch 変更禁止・SG 変更禁止** は維持する。

### 1) App instrumentation（エージェントが差分を用意）

言語に応じて最小差分。詳細は [reference.md](reference.md)。

**Go（標準）:**
1. `go standalone.Integrate(":19001")` をアプリ起動と別に goroutine で
2. Initialize ハンドラ先頭で collect webhook（非同期 GET、失敗しても初期化は継続）
3. 環境変数 `PPROTEIN_WEBHOOK_URL`

**Go 以外:**
- アプリプロセスで pprof 相当を `:19001` に出せなければ、targets の `pprof` は agent `:19000` に落とす（アプリ CPU ではない旨を注記）
- Initialize 相当から webhook GET を非同期で叩く

既存の Initialize 付随処理（Slack 通知など）は消さず併存させる。

デプロイ・ビルド・サービス再起動はランブックに書き、ユーザーが実行する。

### 2) Manual runbook（ユーザー向け）

ホストごとにコピペ可能なコマンド列を出す。含めるもの:

1. **agent install** — helper があれば `sudo DEBIAN_FRONTEND=noninteractive ./mybin/pprotein/setup.sh install`。無ければ [reference.md](reference.md) の手動導入。env: `PPROTEIN_HTTPLOG` / `PPROTEIN_SLOWLOG` / `PPROTEIN_GIT_REPOSITORY`
2. **DB slowlog ON** — MySQL helper または同等設定
3. **アクセスログ LTSV** + `nginx -t` + reload（フォーマットは reference）
4. **アプリ反映** — 現在ブランチのまま pull/build/restart（branch 切替コマンドは書かない。切替が必要なら「現ブランチを確認してから…」とユーザー判断に委ねる）
5. **疎通** — 下記 Verify の curl（`--max-time` 必須）

ランブック冒頭に固定注記:

```
- git checkout / switch しない（現在のブランチのまま）
- AWS SG は変更しない（19000/19001 が未許可なら人が別途対応）
```

### 3) Network（注記のみ）

pprotein → 各競技サーバの **TCP 19000 / 19001** が届く必要がある。

- エージェントは SG / ufw / クラウド FW を **追加・変更しない**
- 未達なら「19000/19001 を pprotein から許可してください」と伝えるだけ

### 4) group/targets

ホスト Label は invent せず、discover した名前（`s1` / `isucon-1` 等）を使う。各ホスト 3 行（Duration 既定 10）:

| Type | URL |
|------|-----|
| pprof | `http://<reachable-ip>:19001/debug/pprof/profile`（app pprof 無しなら `:19000/...`） |
| httplog | `http://<reachable-ip>:19000/debug/log/httplog` |
| slowlog | `http://<reachable-ip>:19000/debug/log/slowlog` |

`<reachable-ip>` は pprotein から届くアドレス（別 VPC なら Public）。

登録は pprotein UI または API。ローカルから API を叩けるならエージェントが登録してよい。サーバ SSH は不要なら使わない。

### 5) alp matching_groups

**その問題のルート定義から生成する。** 固定の問題別リストをコピペしない。

1. ルータ / OpenAPI / フレームワークのルート一覧を収集
2. パスパラメータ（`:id`, `{id}`, `<id>` 等）を含むものだけ残す
3. 可変セグメントを `[^/]+` 等に置換した regex を `matching_groups` にする
4. クエリ文字列は通常マッチ対象外

生成ルール・例は [reference.md](reference.md)。

### 6) Verify（ランブックに含める）

tail 系はブロックし得るので **`--max-time` 必須**:

```sh
curl -s -o /dev/null -w "%{http_code}\n" --connect-timeout 3 --max-time 3 \
  http://<ip>:19000/debug/pprof/
curl -s -o /dev/null -w "%{http_code}\n" --connect-timeout 3 --max-time 3 \
  http://<ip>:19001/debug/pprof/
```

pprotein ホストから全 target IP で 200 を確認（ユーザーが実行）。

## Agent Behavior

1. 問題固有の API パス・unit 名・ディレクトリをハードコードしない。必ず Discover。
2. 最終回答に **group/targets**・**matching_groups**・**Webhook URL**・**手動ランブック**・使った前提（ホスト/IP）を含める。
3. Public IP をデフォルト（Private 到達確認時のみ Private）。
4. pprotein 本体の新規構築はしない。
5. 既存 Initialize 周辺を破壊しない。
6. 秘密情報をログや PR に出さない。
7. **SG / クラウド FW を変更しない。** 必要ポートは文章で伝えるだけ。
8. **サーバ SSH はユーザー明示時のみ。** 既定はランブック渡し。
9. **サーバ上で git branch を変えない。** 変更が必要ならユーザーに依頼する。

## References

- テンプレ・生成ルール: [reference.md](reference.md)
