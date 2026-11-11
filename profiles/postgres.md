# Postgres profile (read once per session when touching db/)

- Migrations: goose, one file per change in `db/migrations/NNNNN_name.sql`, always with `-- +goose Down`. NEVER edit an applied migration: add a new one. Destructive DDL (drop/rename column or table) needs the developer's approval and a plan for existing data.
- Queries: sqlc in `db/queries/*.sql`; named, parameterized, no string concatenation, no ORM. Regenerate with `make gen`; never hand-edit generated code.
- Schema: `bigint generated always as identity` or `uuid` keys; `timestamptz` (never `timestamp`); `NOT NULL` by default; explicit foreign keys with `ON DELETE` behavior; index every foreign key and every filtered/sorted column you query on; constraints (`CHECK`, `UNIQUE`) over app-only validation.
- Money/precision: `numeric`, never float.
- Performance: `EXPLAIN (ANALYZE, BUFFERS)` on any new query over a growing table; paginate with keyset when possible; avoid N+1.
- Access: the app connects with a least-privilege role, not the superuser; credentials only via env.
- Transactions: keep them short; pass `ctx`; retry only on serialization/deadlock errors.
- Local: Postgres from `docker compose`; data lives in a named volume; `docker compose down -v` deletes it (guard hook asks).
