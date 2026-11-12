# Integration harness

`make test-integration` (from `backend/`, with `docker compose up -d` and `goose` installed) runs
`scripts/test-integration.sh`: it creates a throwaway database `app_test_<epoch>_<pid>`, applies
`db/migrations` with goose, runs `go test -tags=integration ./...` and drops the database on exit
(also on Ctrl-C; leftovers older than an hour are swept on the next run).

- Tests carry `//go:build integration`; `make test` stays fast and needs no Docker.
- `testutil.NewPool(t)` reads `DATABASE_URL_TEST` and refuses any database not named `*_test_<n>_<n>` or not on localhost.
- Fixtures: `backend/internal/testutil/fixtures/*.sql`, loaded with `testutil.Load(t, pool, "name")`; keep them idempotent.
- Different port or credentials: `HARNESS_PG_URL=postgres://user:pass@localhost:5433 make test-integration` (and `HARNESS_COMPOSE` for another compose file).
- The first run creates `go.sum` with `go mod tidy`; commit it. `-race` is used only when CGO is enabled.
- API contract: `backend/cmd/api/contract_test.go` (runs in `make test`, no Docker). Every GET in `api/openapi.yaml` must be a registered route, and GETs without path parameters must answer with a declared status. The parser accepts block-style YAML with 2-space indentation only and fails loudly otherwise.
- Out of scope here: browser e2e, AWS (floci) and CI.
