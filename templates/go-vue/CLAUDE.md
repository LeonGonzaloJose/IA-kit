# __TITLE__

Go + Vue 3 + Postgres, all in Docker. Definition: `docs/PROJECT.md`; decisions: `docs/DECISIONS.md`; roadmap: `docs/plans/00-roadmap.md`.

## Commands
- Infra: `docker compose up -d` · API: `cd backend && make run` · Front: `cd frontend && npm run dev`
- Backend checks: `make test lint vuln sec` · Front checks: `npm run typecheck lint test`
- Migrations: goose (`make migrate-up|down`), queries: sqlc (`make gen`). No ORM.

## Rules
- `backend/api/openapi.yaml` is the source of truth; change it first, then regenerate server/client types.
- API manual = Scalar at `/docs/` (dev only). Do not add swaggo/Swagger UI.
- New migration for every schema change; never edit an applied migration.
- Secrets only in `.env` (git-ignored); keep `.env.example` current.
- Commit `frontend/package-lock.json`; CI and Docker install with `npm ci`, never `npm install`.
- Stack conventions: kit profiles `go.md` / `vue.md` / `postgres.md` (read once per session when relevant).
