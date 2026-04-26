---
name: bench-slack-notify-init
description: Add Slack notifications in Go Initialize functions using Incoming Webhook. Sends an immediate notification when benchmark access is detected and a delayed follow-up after N seconds (default 60) to signal benchmark completion timing. Use when users ask for benchmark start/end alerts, access-triggered notifications, or N-seconds-later Slack notifications.
---

# Bench Slack Notify Init

## Purpose

`Initialize` 関数に Slack 通知を追加し、次を実現する。

- アクセス検知直後の通知（ベンチマーカ来訪）
- アクセスから N 秒後の通知（ベンチ終了目安）

既定の遅延は 60 秒。環境変数で上書き可能にする。

## Quick Start

1. `Initialize` の先頭で通知トリガーを実行する。
2. `notifySlack()` と `notifySlackAfter()` を実装する。
3. `BENCH_END_NOTIFY_AFTER_SEC` で遅延秒数 N を制御する（未設定時 60）。
4. Slack Incoming Webhook URL は `SLACK_WEBHOOK_URL` から取得する。

## Implementation Steps (Go)

### 1) 必要な環境変数

- `SLACK_WEBHOOK_URL` (必須)
- `BENCH_END_NOTIFY_AFTER_SEC` (任意, 既定: `60`)
- `HOSTNAME` (任意, 通知文面に含める)

### 2) Initialize で通知を呼ぶ

`Initialize` 内で以下を呼ぶ:

- 即時通知: `go notifySlack("bench access detected ...")`
- 遅延通知: `go notifySlackAfter(delaySec, "bench likely finished ...")`

通知の失敗で `Initialize` を落とさない。失敗はログ出力に留める。

### 3) 遅延秒数 N の解決

`BENCH_END_NOTIFY_AFTER_SEC` を `strconv.Atoi` で読み取り:

- 未設定/不正値/0以下なら `60`
- それ以外は指定値を使用

### 4) 非同期送信

`Initialize` のレスポンス遅延を避けるため、通知送信は goroutine で行う。

### 5) メッセージ構成

最低限以下を含める:

- 種別: `BENCH_START` / `BENCH_END_HINT`
- 時刻: `time.Now().Format(time.RFC3339)`
- ホスト: `HOSTNAME`（取得できれば）
- 遅延秒数（後段通知）

## References

- 関数リファレンス: [reference.md](reference.md)
- `Initialize` では `notifyBenchStartAndEndHint()` を呼ぶだけにする。

## Validation Checklist

- [ ] `/initialize` へアクセスした直後に `BENCH_START` 通知が来る
- [ ] N 秒後に `BENCH_END_HINT` 通知が来る
- [ ] `BENCH_END_NOTIFY_AFTER_SEC=10` で 10 秒後に来る
- [ ] `SLACK_WEBHOOK_URL` 未設定でもアプリが落ちない
- [ ] 通知失敗時にログへ理由が出る

## Agent Behavior

このスキルを使うとき、エージェントは次を守る:

1. 既存の `Initialize` 実装を壊さず最小差分で追加する。
2. 同期的な待機 (`time.Sleep`) をリクエスト本体で行わない。
3. デフォルト値 60 秒を保持し、N 秒に一般化する。
4. 通知送信失敗を致命エラーにしない。
