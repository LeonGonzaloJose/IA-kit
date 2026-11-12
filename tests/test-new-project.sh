#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/bin/new-project.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
exp() { local name="$1" code="$2"; shift 2; "$GEN" "$@" >/dev/null 2>&1; [ $? -eq "$code" ] && ok "$name" || bad "$name (want exit $code)"; }

exp "no args"               2
exp "bad name"              2 Bad_Name
exp "bad port"              2 app --port 99999
exp "unknown service"       2 app --services mysql
exp "nothing to generate"   2 app --no-front --no-back
exp "dry-run writes nothing" 0 app --dir "$TMP/dry" --dry-run
[ ! -e "$TMP/dry" ] && ok "dry-run created no files" || bad "dry-run created files"

"$GEN" demo --dir "$TMP/demo" --module example.com/demo --services postgres,redis,elasticsearch,floci --no-vendor --title "Demo" >/dev/null 2>&1
[ $? -eq 0 ] && ok "generate full project" || bad "generate full project"
[ -f "$TMP/demo/backend/cmd/api/main.go" ] && [ -f "$TMP/demo/frontend/package.json" ] && [ -f "$TMP/demo/backend/internal/docs/docs.go" ] && [ -d "$TMP/demo/docs/tasks" ] && grep -q 'docs/tasks' "$TMP/demo/CLAUDE.md" && ok "expected files exist" || bad "expected files"
! grep -rqE '__(MODULE|NAME|TITLE|PORT)__' "$TMP/demo" && ok "no placeholders left" || bad "placeholders left"
grep -q 'module example.com/demo' "$TMP/demo/backend/go.mod" && ok "module substituted" || bad "module"
grep -qE 'elasticsearch|redis|postgres|floci' "$TMP/demo/docker-compose.yml" && ok "compose has services" || bad "compose services"
if command -v docker >/dev/null; then docker compose -f "$TMP/demo/docker-compose.yml" config -q 2>/dev/null && ok "compose is valid" || bad "compose invalid"; fi
if command -v go >/dev/null; then (cd "$TMP/demo/backend" && go vet ./... >/dev/null 2>&1) && ok "backend passes go vet" || bad "go vet"; fi
[ -f "$TMP/demo/backend/harness.mk" ] && [ -x "$TMP/demo/backend/scripts/test-integration.sh" ] && [ -f "$TMP/demo/backend/internal/testutil/db.go" ] && [ -f "$TMP/demo/docs/HARNESS.md" ] && ok "harness installed with postgres" || bad "harness files"
grep -q 'jackc/pgx/v5' "$TMP/demo/backend/go.mod" && grep -q '^include harness.mk' "$TMP/demo/backend/Makefile" && grep -q 'scripts/verify.sh' "$TMP/demo/CLAUDE.md" && [ -x "$TMP/demo/scripts/verify.sh" ] && grep -q '^verify-full:' "$TMP/demo/Makefile" && ok "harness wired (go.mod, Makefiles, CLAUDE.md, verify.sh)" || bad "harness wiring"
bash -n "$TMP/demo/backend/scripts/test-integration.sh" && ok "integration script parses" || bad "integration script syntax"
[ -f "$TMP/demo/backend/cmd/api/contract_test.go" ] && ok "contract test generated" || bad "contract test missing"
no_integration() { # no_integration <dir>: nothing of the Postgres harness may be left behind
  [ -f "$1/backend/Makefile" ] && [ -f "$1/CLAUDE.md" ] && [ -f "$1/backend/go.mod" ] && [ ! -e "$1/backend/harness.mk" ] && [ ! -e "$1/backend/scripts" ] && [ ! -e "$1/backend/internal/testutil" ] &&
    ! grep -q 'harness.mk' "$1/backend/Makefile" && ! grep -q 'pgx' "$1/backend/go.mod"; }
no_harness() { no_integration "$1" && [ ! -e "$1/scripts" ] && [ ! -e "$1/docs/HARNESS.md" ] && [ ! -e "$1/Makefile" ] && ! grep -q 'verify' "$1/CLAUDE.md"; }
out=$("$GEN" nh --dir "$TMP/nh" --no-vendor --no-harness 2>/dev/null)
no_harness "$TMP/nh" && [ -f "$TMP/nh/backend/cmd/api/contract_test.go" ] && [ "$(jq -r .harness <<<"$out")" = skipped ] && ok "--no-harness skips the harness" || bad "--no-harness"
out=$("$GEN" nopg --dir "$TMP/nopg" --no-vendor --services redis 2>/dev/null)
no_integration "$TMP/nopg" && [ -x "$TMP/nopg/scripts/verify.sh" ] && [ "$(jq -r .harness <<<"$out")" = verify-only ] && ok "no postgres: verify only, no integration harness" || bad "harness without postgres"
out=$("$GEN" yes --dir "$TMP/yes" --no-vendor 2>/dev/null); [ "$(jq -r .harness <<<"$out")" = installed ] && ok "summary reports the harness" || bad "summary harness field"
if command -v go >/dev/null; then
  (cd "$TMP/demo/backend" && go test ./cmd/... -count=1 >/dev/null 2>&1) && ok "generated contract test passes" || bad "generated contract test"
  # a GET in the contract with no route must fail even though it declares 404
  printf '  /ghost:\n    get:\n      responses:\n        "404":\n          description: nope\n' >> "$TMP/yes/backend/api/openapi.yaml"
  tail -n 1 "$TMP/yes/backend/api/openapi.yaml" | grep -q 'description: nope' || bad "could not append /ghost to the contract"
  (cd "$TMP/yes/backend" && go test ./cmd/... -count=1 2>&1 | grep -q 'GET /ghost is in the contract but not registered') && ok "unimplemented route is not a false green" || bad "unimplemented route went undetected"
fi
if [ "${KIT_TEST_DOCKER:-0}" = 1 ]; then
  # own compose project: `down -v` must never reach another project's volumes
  export COMPOSE_PROJECT_NAME="kit-test-$$"
  # --no-vendor leaves a placeholder that the docs test rightly rejects; stand in for the real bundle
  printf '// test stand-in for the Scalar bundle%*s\n' 1200 '' > "$TMP/demo/backend/internal/docs/scalar.standalone.js"
  # no npm install here: without the front, verify-full covers Go + integration only
  rm -rf "$TMP/demo/frontend"
  trap '(cd "$TMP/demo" 2>/dev/null && docker compose down -v >/dev/null 2>&1); rm -rf "$TMP"' EXIT
  trap 'exit 143' INT TERM HUP
  if (cd "$TMP/demo" && docker compose up -d postgres >"$TMP/docker.log" 2>&1 && make verify-full >>"$TMP/docker.log" 2>&1) && grep -q '^== integration' "$TMP/docker.log"; then ok "make verify-full passes with integration (docker)"
  else bad "make verify-full (docker)"; tail -n 15 "$TMP/docker.log"; fi
  left=$(cd "$TMP/demo" && docker compose exec -T postgres psql -qAt -U app -d postgres -c "SELECT count(*) FROM pg_database WHERE datname LIKE 'app\_test\_%'" 2>/dev/null)
  [ "$left" = 0 ] && ok "no throwaway database left behind" || bad "throwaway databases left: ${left:-could not query postgres}"
fi
exp "refuses non-empty dir" 3 demo --dir "$TMP/demo" --no-vendor
"$GEN" onlyback --dir "$TMP/ob" --no-front --no-vendor >/dev/null 2>&1; [ ! -d "$TMP/ob/frontend" ] && [ -d "$TMP/ob/backend" ] && ok "--no-front" || bad "--no-front"
exit $fail
