---
name: isucon-make-tests
description: Create Go characterization tests for ISUCON apps to detect regressions before benchmarks. Use for refactoring safety, API compatibility, golden files, DB fixtures, and HTTP behavior tests.
---

# ISUCON Go Characterization Tests

## 目的

アプリケーションの現在の振る舞いを保持するテストを作成する。

目的は理想仕様を定義することではない。ユーザーが別の仕様を明示しない限り、現在の実装の挙動が正（source of truth）である。

## スコープ

router または handler 経由で、公開 HTTP API の挙動をテストする。

推奨:
- Go `testing`
- `net/http/httptest`
- table-driven tests
- DB fixtures
- golden files
- リクエスト、login、DB reset、JSON 比較用の helper 関数

避けること:
- private または internal 関数を直接テストすること
- SQL 構造、cache 実装、private helper、package 内部の詳細にテストを結合すること
- 現在の実装から推論できない expected value を推測すること

## ワークフロー

1. routes、handlers、middleware、DB schema、fixtures、既存テストを調査する。
2. 公開 API を一覧化する。
3. 回帰検知の価値が高い箇所を特定する:
   - login/session
   - authorization
   - create/update/delete の side effect
   - list/detail エンドポイント
   - ranking/aggregation
   - sorting と pagination
   - error response
   - 境界値
4. コード編集前にテストケースを提案する。
5. テスト helper を実装する:
   - `resetDB(t)`
   - `newTestHandler(t)`
   - `doJSON(t, handler, method, path, body, cookies...)`
   - `loginAs(t, handler, user)`
   - `assertJSONGolden(t, path, got)`
   - `normalizeJSON(t, raw)`
6. `testdata/fixtures` 配下に fixture を追加または更新する。
7. `testdata/golden` 配下に golden file を追加する。
8. `go test ./...` を実行する。
9. テストまたは testability の問題のみ修正する。必要かつ明示的に正当化されない限り、本番コードはリファクタリングしない。

## Golden File 方針

レスポンスが大きい、またはフィールド数が多い場合は golden file を使う。

比較前に不安定な値を正規化する:
- timestamp
- 本質でない場合の auto-increment ID
- session ID
- random token
- 生成された UUID
- リクエスト固有の値

expected value を安全に推論できない場合は、推測で作らない。現在の実装から golden file を取得する方式を優先する。

## 出力フォーマット

変更前に、次を出力する:

1. 発見した API
2. 提案するテストケース
3. 編集するファイル
4. 追加する fixture / golden file
5. 実行するコマンド

ユーザーが進めるよう指示したら実装する。
