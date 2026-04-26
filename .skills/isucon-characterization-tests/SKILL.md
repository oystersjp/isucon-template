---
name: isucon-characterization-tests
description: Create Go characterization tests for ISUCON apps to detect regressions before benchmarks. Use for refactoring safety, API compatibility, golden files, DB fixtures, and HTTP behavior tests.
---

# ISUCON Go Characterization Tests

## Goal

Create tests that preserve the current observable behavior of the application before refactoring.

The purpose is not to define an ideal specification. The current implementation behavior is the source of truth unless the user explicitly provides a different specification.

## Scope

Test public HTTP API behavior through the router or handler.

Prefer:
- Go `testing`
- `net/http/httptest`
- table-driven tests
- DB fixtures
- golden files
- helper functions for requests, login, DB reset, and JSON comparison

Avoid:
- Testing private or internal functions directly
- Coupling tests to SQL structure, cache implementation, private helpers, or package-internal details
- Guessing expected values that cannot be inferred from the current implementation

## Workflow

1. Inspect routes, handlers, middleware, DB schema, fixtures, and existing tests.
2. List public APIs.
3. Identify high-value regression targets:
   - login/session
   - authorization
   - create/update/delete side effects
   - list/detail endpoints
   - ranking/aggregation
   - sorting and pagination
   - error responses
   - boundary values
4. Propose test cases before editing code.
5. Implement test helpers:
   - `resetDB(t)`
   - `newTestHandler(t)`
   - `doJSON(t, handler, method, path, body, cookies...)`
   - `loginAs(t, handler, user)`
   - `assertJSONGolden(t, path, got)`
   - `normalizeJSON(t, raw)`
6. Add or update fixtures under `testdata/fixtures`.
7. Add golden files under `testdata/golden`.
8. Run `go test ./...`.
9. Fix only test or testability issues. Do not refactor production code unless needed and explicitly justified.

## Golden File Policy

Use golden files when the response is large or has many fields.

Normalize unstable values before comparing:
- timestamps
- auto-increment IDs when not essential
- session IDs
- random tokens
- generated UUIDs
- request-specific values

If an expected value cannot be safely inferred, do not invent it. Prefer golden-file capture from the current implementation.

## Output Format

Before making changes, output:

1. APIs discovered
2. proposed test cases
3. files to edit
4. fixtures/golden files to add
5. commands to run

Then implement when the user asks to proceed.
