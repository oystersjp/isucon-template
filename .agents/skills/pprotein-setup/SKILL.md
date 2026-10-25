---
name: pprotein-setup
description: >-
  Prepare pprotein profiling for any ISUCON contest: discover hosts and app
  layout, draft app pprof/webhook patches if needed, and tell the user to run
  mybin/pprotein/pprotein-setup.sh (nginx/mysql/agent/targets/alp/verify).
  Do not invent long manual runbooks for host setup when the CLI covers it.
  AWS SG changes are always out of scope. Use when the user asks for pprotein
  setup, group/targets, httplog/config, alp config, or agent install.
---

# pprotein Setup (any ISUCON)

## Purpose

計測対象サーバと構築済み pprotein をつなぎ Collect できる状態にする。

**ホスト設定と API 登録はコマンドで行う。** AI がコピペランブックを長々と書かない。

```sh
# 各競技ホスト上
sudo ./mybin/pprotein/pprotein-setup.sh nginx on
sudo ./mybin/pprotein/pprotein-setup.sh mysql on
sudo ./mybin/pprotein/pprotein-setup.sh agent install
./mybin/pprotein/pprotein-setup.sh verify

# pprotein API に届くマシンから
export PPROTEIN_URL=http://<pprotein-host>:9000
./mybin/pprotein/pprotein-setup.sh targets --host s1=<ip> --host s2=<ip> --app-pprof s1
./mybin/pprotein/pprotein-setup.sh alp --group '^/api/items/[^/]+$'
```

**エージェントがやること:** Discover、アプリ差分の下書き（pprof / webhook）、上記コマンドに埋める IP・label・matching_groups の提案。
**ユーザーがやること:** SSH でコマンド実行、**AWS SG で 19000/19001 を手動許可**、デプロイ・再起動。

## Ownership

| 担当 | やること |
|------|----------|
| **CLI** (`pprotein-setup.sh`) | nginx LTSV、mysql slowlog、agent install、targets / alp POST、verify |
| **エージェント** | リポジトリ調査、アプリ差分下書き、CLI 引数の具体値の提案 |
| **ユーザー** | SSH、CLI 実行、SG 手動、ブランチ判断、デプロイ |

- **AWS SG / クラウド FW は依頼されても変更しない。** 未達なら「19000/19001 を許可してください」と伝えるだけ。
- サーバ上で **git checkout / switch しない。**
- SSH はユーザー明示時のみ。既定はコマンドを渡す。

## Architecture

| Role | Port | Process |
|------|------|---------|
| agent | 19000 | `pprotein-agent` |
| app pprof | 19001 | アプリ内 `standalone.Integrate` |
| UI | 9000 | pprotein Collect / alp / slp |

Collect webhook は **GET** `/api/group/collect`（`PPROTEIN_WEBHOOK_URL`）。

## Phase 0 — Discover

不明なら確認。SSH しない。

1. ホスト label / Public IP（targets 用）
2. `PPROTEIN_URL`
3. アプリ言語・Initialize パス
4. ログパス（既定と違うときだけ）
5. matching_groups 用のパラメータ付きルート

## Workflow

```
- [ ] 0. Discover
- [ ] 1. 必要ならアプリ差分（pprof :19001 + Initialize webhook）
- [ ] 2. ユーザーに CLI コマンドを渡す（nginx → mysql → agent → verify）
- [ ] 3. SG は注記のみ（人が許可）
- [ ] 4. targets / alp の CLI コマンドを渡す（具体 IP と regex）
```

### App instrumentation（エージェントが差分を用意）

Go: [reference.md](reference.md) の `standalone.Integrate(":19001")` と `notifyPproteinCollect()`。古い Echo middleware / POST webhook は使わない。

### CLI 詳細

ヘッダと `./mybin/pprotein/pprotein-setup.sh help` を正とする。

- `nginx on|off` … LTSV（`with_time` スクリプトは使わない）
- `mysql on|off` … 管理ブロックで冪等。旧 `mysql_slow_query.sh init` の二重追記を避ける
- `agent install` … 内部で `setup.sh install`（ログが無いと失敗する）
- `targets` / `alp` … `PPROTEIN_URL` 必須。python3 で JSON
- `verify` … `:19000/debug/pprof/` を `--max-time 3` 相当で確認（`/debug/log/*` は叩かない）

### matching_groups

ルート定義からパラメータ付きだけを regex にする。生成ルールは [reference.md](reference.md)。結果は `alp --group` または `--groups-file` に渡す。

## Agent Behavior

1. 問題固有パスをハードコードしない。Discover する。
2. 最終回答は **実行すべき `pprotein-setup.sh` コマンド列**、Webhook URL、前提 IP を含める。長文ランブックで CLI を再発明しない。
3. Public IP 既定。
4. pprotein 本体は構築しない。
5. SG を変更しない。
6. git branch を変えない。

## References

- CLI: `mybin/pprotein/pprotein-setup.sh`
- テンプレ: [reference.md](reference.md)
