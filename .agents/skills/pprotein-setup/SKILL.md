---
name: pprotein-setup
description: >-
  Prepare pprotein profiling for any ISUCON contest: discover hosts and app
  layout, open a PR that adds app pprof (:19001) and Initialize collect webhook,
  and tell the user to run mybin/pprotein/pprotein-setup.sh
  (nginx/mysql/agent/targets/alp/verify). Do not invent long manual runbooks for
  host setup when the CLI covers it. AWS SG changes are always out of scope.
  Use when the user asks for pprotein setup, group/targets, httplog/config,
  alp config, or agent install.
---

# pprotein Setup (any ISUCON)

## Purpose

計測対象サーバと構築済み pprotein をつなぎ Collect できる状態にする。

**ホスト設定と API 登録は CLI。アプリ pprof / webhook はエージェントが PR を開く。**

最終回答では、ユーザーが埋める値を先に表で出す（空欄を残さない）:

| ユーザー作業 | 値 |
|--------------|-----|
| SG 19000/19001（pprotein→競技ホスト） | 手動。CLI / エージェントは触らない |
| `PPROTEIN_URL` | `http://…:9000` |
| `--host label=ip` | 到達可能な IP（既定 Public） |
| `alp --group` | パラメータ付きルートの regex（提案してよい） |
| pprof PR のマージとデプロイ | エージェントが PR を作ったあと |

`--app-pprof` は、pprof PR を入れたホストの label を渡す。

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

## Ownership

| 担当 | やること |
|------|----------|
| **CLI** (`pprotein-setup.sh`) | nginx LTSV、mysql slowlog、agent install、targets / alp POST、verify |
| **エージェント** | Discover、**アプリ pprof + Initialize webhook の PR 作成**、CLI 引数の具体値の提案 |
| **ユーザー** | SG 手動、SSH、CLI 実行、**pprof PR のマージ**、デプロイ・再起動 |

- アプリ差分は「下書きだけ渡して終わり」にしない。**ブランチを切って PR を開く**（タイトル・本文はリポジトリ慣例に従う。このリポジトリでは日本語）。
- **AWS SG / クラウド FW は依頼されても変更しない。**
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
3. アプリ言語・エントリポイント・Initialize パス
4. ログパス（既定と違うときだけ）
5. matching_groups 用のパラメータ付きルート

## Workflow

```
- [ ] 0. Discover
- [ ] 1. アプリ pprof (:19001) + Initialize webhook の PR を開く
- [ ] 2. ユーザーに CLI コマンドを渡す（nginx → mysql → agent → verify）
- [ ] 3. SG は注記のみ（人が許可）
- [ ] 4. targets / alp の CLI コマンドを渡す（具体 IP と regex）
```

### App instrumentation（エージェントが PR を開く）

Go: [reference.md](reference.md) の `standalone.Integrate(":19001")` と `notifyPproteinCollect()`。古い Echo middleware / POST webhook は使わない。

PR に含めるもの:

1. `go standalone.Integrate(":19001")`（起動と別 goroutine）
2. Initialize（または同等）先頭の非同期 GET webhook
3. `PPROTEIN_WEBHOOK_URL` を問題の env / systemd 流儀で設定する差分（値はプレースホルダ可。実 URL はユーザー表の `PPROTEIN_URL` から組み立て）
4. 依存追加（`github.com/kaz/pprotein`）

Go 以外で :19001 相当が出せないときだけ、targets の pprof を agent :19000 に落とし、PR では webhook のみ（またはスキップ理由を PR / 回答に書く）。

既存の Initialize 付随処理（Slack 通知など）は消さず併存させる。

### CLI 詳細

ヘッダと `./mybin/pprotein/pprotein-setup.sh help` を正とする。

- `nginx on|off` … LTSV
- `mysql on|off` … 管理ブロックで冪等
- `agent install` … 内部で `setup.sh install`（ログが無いと失敗する）
- `targets` / `alp` … `PPROTEIN_URL` 必須。`alp` は生 YAML POST
- `verify` … `:19000/debug/pprof/`（`/debug/log/*` は叩かない）

### matching_groups

ルート定義からパラメータ付きだけを regex にする。生成ルールは [reference.md](reference.md)。結果は `alp --group` または `--groups-file` に渡す。

## Agent Behavior

1. 問題固有パスをハードコードしない。Discover する。
2. アプリ計測は **PR を開いて URL を返す**。差分だけチャットに貼って終わらない。
3. 最終回答は **pprof PR URL**、**実行すべき `pprotein-setup.sh` コマンド列**、Webhook URL、前提 IP を含める。
4. Public IP 既定。
5. pprotein 本体は構築しない。
6. SG を変更しない。
7. サーバ上で git branch を変えない。

## References

- CLI: `mybin/pprotein/pprotein-setup.sh`
- テンプレ: [reference.md](reference.md)
