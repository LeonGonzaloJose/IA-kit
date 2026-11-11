# __TITLE__

Go (backend) + Vue 3 (frontend) + Postgres, everything local in Docker.

```bash
cp .env.example .env
docker compose up -d            # infrastructure (see docker-compose.yml)
cd backend && make run          # API on http://localhost:__PORT__  — manual at /docs/
cd frontend && npm install && npm run dev
```

The API contract lives in `backend/api/openapi.yaml` (source of truth). The manual (Scalar) is served at `/docs/` only outside production.
Project definition and plan: `docs/PROJECT.md`, `docs/DECISIONS.md`, `docs/plans/`.
