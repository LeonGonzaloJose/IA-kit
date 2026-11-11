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
[ -f "$TMP/demo/backend/cmd/api/main.go" ] && [ -f "$TMP/demo/frontend/package.json" ] && [ -f "$TMP/demo/backend/internal/docs/docs.go" ] && ok "expected files exist" || bad "expected files"
! grep -rqE '__(MODULE|NAME|TITLE|PORT)__' "$TMP/demo" && ok "no placeholders left" || bad "placeholders left"
grep -q 'module example.com/demo' "$TMP/demo/backend/go.mod" && ok "module substituted" || bad "module"
grep -qE 'elasticsearch|redis|postgres|floci' "$TMP/demo/docker-compose.yml" && ok "compose has services" || bad "compose services"
if command -v docker >/dev/null; then docker compose -f "$TMP/demo/docker-compose.yml" config -q 2>/dev/null && ok "compose is valid" || bad "compose invalid"; fi
if command -v go >/dev/null; then (cd "$TMP/demo/backend" && go vet ./... >/dev/null 2>&1) && ok "backend passes go vet" || bad "go vet"; fi
exp "refuses non-empty dir" 3 demo --dir "$TMP/demo" --no-vendor
"$GEN" onlyback --dir "$TMP/ob" --no-front --no-vendor >/dev/null 2>&1; [ ! -d "$TMP/ob/frontend" ] && [ -d "$TMP/ob/backend" ] && ok "--no-front" || bad "--no-front"
exit $fail
