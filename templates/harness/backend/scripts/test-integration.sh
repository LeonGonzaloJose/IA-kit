#!/usr/bin/env bash
# Integration harness: one throwaway Postgres database per run, migrated with goose, dropped on exit.
# Needs the compose stack up (`docker compose up -d`) and goose on PATH.
#   HARNESS_COMPOSE  compose file (default ../docker-compose.yml)
#   HARNESS_PG_URL   server URL as seen from the host, without database (default postgres://app:app@localhost:5432).
#                    Development credentials only.
set -euo pipefail
cd "$(dirname "$0")/.."

COMPOSE="${HARNESS_COMPOSE:-../docker-compose.yml}"
PG_URL="${HARNESS_PG_URL:-postgres://app:app@localhost:5432}"
PG_USER="$(printf '%s' "$PG_URL" | sed -E 's#^[a-z]+://([^:@/]+).*#\1#')"
DB="app_test_$(date +%s)_$$"
STALE_SECONDS=3600

die() { echo "test-integration: $1" >&2; exit 1; }
psql_admin() { timeout 20 docker compose -f "$COMPOSE" exec -T postgres psql -v ON_ERROR_STOP=1 -qAt -U "$PG_USER" -d postgres "$@"; }

for tool in docker go timeout; do command -v "$tool" >/dev/null || die "$tool not found"; done
command -v goose >/dev/null || die "goose not found (go install github.com/pressly/goose/v3/cmd/goose@latest)"
[[ "$PG_USER" =~ ^[A-Za-z0-9_.-]+$ ]] || die "HARNESS_PG_URL must look like postgres://user:pass@host:port"
[ -f "$COMPOSE" ] || die "compose file not found: $COMPOSE"
docker info >/dev/null 2>&1 || die "docker is not running"
[ -s go.sum ] || go mod tidy || die "go mod tidy failed (the first run needs network access)"

# -h 127.0.0.1: the image's init phase listens on the socket only, so a socket check can pass too early
ready=0
for _ in $(seq 1 30); do
  if timeout 5 docker compose -f "$COMPOSE" exec -T postgres pg_isready -q -h 127.0.0.1 -U "$PG_USER" 2>/dev/null; then ready=1; break; fi
  sleep 1
done
[ "$ready" -eq 1 ] || die "postgres is not ready (docker compose up -d?)"

# Sweep databases left behind by a killed run: only old ones with no open session, so a live run is never touched.
idle_test_dbs="SELECT d.datname FROM pg_database d WHERE d.datname ~ '^app_test_[0-9]+_[0-9]+\$'
  AND NOT EXISTS (SELECT 1 FROM pg_stat_activity a WHERE a.datname = d.datname)"
if leftovers="$(psql_admin -c "$idle_test_dbs")"; then
  now="$(date +%s)"
  for old in $leftovers; do
    started="${old#app_test_}"; started="${started%%_*}"
    if [ $((now - 10#$started)) -gt "$STALE_SECONDS" ]; then
      psql_admin -c "DROP DATABASE IF EXISTS \"$old\"" >/dev/null || echo "test-integration: could not drop stale $old" >&2
    fi
  done
else
  echo "test-integration: stale database sweep skipped" >&2
fi

# Long steps run in the background so a signal interrupts `wait` at once instead of after the child ends.
child=""
run() { "$@" & child=$!; wait "$child"; }
cleanup() { psql_admin -c "DROP DATABASE IF EXISTS \"$DB\" WITH (FORCE)" >/dev/null || echo "test-integration: could not drop $DB" >&2; }
on_signal() { [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true; exit "$1"; }
trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM HUP
psql_admin -c "CREATE DATABASE \"$DB\""

DSN="$PG_URL/$DB?sslmode=disable"
# DSN through the environment: argv is visible to every user in `ps`
GOOSE_DRIVER=postgres GOOSE_DBSTRING="$DSN" run goose -dir db/migrations up ||
  die "migrations failed, or ${PG_URL##*@} is not the compose Postgres (another server on that port?)"

race=""
if [ "$(go env CGO_ENABLED)" = 1 ]; then race="-race"; fi
DATABASE_URL_TEST="$DSN" run go test -tags=integration $race -count=1 ./...
