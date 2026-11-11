# Go profile (read once per session when working on backend/)

- Layout: `cmd/<app>/main.go` wires only; `internal/<domain>` holds logic; `api/` is the OpenAPI contract + generated types; `db/` migrations and sqlc queries. No `utils`/`common` packages.
- Errors: wrap with `fmt.Errorf("doing x: %w", err)`; compare with `errors.Is/As`; never swallow (`_ =`) without a comment saying why. Return errors; panic only at startup.
- Context: first parameter `ctx context.Context` on anything doing I/O; propagate it; set timeouts on every outbound call and on `http.Server`.
- Logging: `log/slog` JSON, structured fields, no secrets/PII, no `fmt.Println`.
- Interfaces: define them where they are consumed, keep them small; accept interfaces, return structs.
- HTTP: Go 1.22+ `ServeMux` patterns (`GET /items/{id}`); handlers decode → call service → encode; map domain errors to status codes in one place; the OpenAPI file is the source of truth (oapi-codegen).
- Concurrency: every goroutine has an owner and a way to stop; `errgroup` for fan-out; run tests with `-race`.
- Tests: table-driven, `t.Parallel()` when safe, `httptest` for handlers, real Postgres from compose for store tests (no mocking the database), `testdata/` for fixtures.
- Tooling gate before commit: `gofumpt`, `golangci-lint run`, `go vet`, `go test -race ./...`; `govulncheck` and `gosec` before publishing.
- Dependencies: standard library first; every new module needs the developer's approval (guard hook asks).
