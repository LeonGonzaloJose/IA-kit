#!/usr/bin/env bash
set -u
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/guard.sh"
fail=0
run() { local name="$1" want="$2" json="$3" out
  out=$(printf '%s' "$json" | bash "$HOOK")
  if [ "$want" = ask ] && [[ "$out" == *'"permissionDecision":"ask"'* ]]; then echo "ok   $name"
  elif [ "$want" = allow ] && [ -z "$out" ]; then echo "ok   $name"
  else echo "FAIL $name: want $want got '$out'"; fail=1; fi; }
b() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')"; }
e() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s","new_string":%s,"content":%s}}' "$1" "$2" "$(jq -Rn --arg c "$3" '$c')" "$(jq -Rn --arg c "$3" '$c')"; }
run "go get"                   ask   "$(b 'go get github.com/x/y@v1.2.0')"
run "go mod edit require"      ask   "$(b 'go mod edit -require=github.com/x/y@v1.0.0')"
run "go test"                  allow "$(b 'go test ./...')"
run "go mod tidy"              allow "$(b 'go mod tidy')"
run "npm install pkg"          ask   "$(b 'npm install axios')"
run "npm i (no pkg)"           allow "$(b 'npm install')"
run "pnpm add"                 ask   "$(b 'pnpm add vue-router')"
run "goose up"                 ask   "$(b 'goose -dir db/migrations postgres \"$DSN\" up')"
run "goose create"             allow "$(b 'goose -dir db/migrations create add_users sql')"
run "migrate down"             ask   "$(b 'migrate -path db/migrations -database x down 1')"
run "compose down -v"          ask   "$(b 'docker compose down -v')"
run "compose down"             allow "$(b 'docker compose down')"
run "rtk wrapped go get"       ask   "$(b 'rtk go get example.com/m')"
run "/usr/bin/go get"          ask   "$(b '/usr/bin/go get example.com/m')"
run "go install @latest"       ask   "$(b 'go install github.com/x/tool@latest')"
run "go install local"         allow "$(b 'go install ./cmd/api')"
run "make migrate-up"          ask   "$(b 'make migrate-up')"
run "make migrate-down DSN"    ask   "$(b 'make migrate-down DSN=postgres://x')"
run "make test"                allow "$(b 'make test lint')"
run "docker-compose down -v"   ask   "$(b 'docker-compose down -v')"
run "docker-compose down"      allow "$(b 'docker-compose down')"
run "docker volume prune"      ask   "$(b 'docker volume prune -f')"
run "docker system prune -vol" ask   "$(b 'docker system prune --volumes')"
run "docker system prune"      allow "$(b 'docker system prune')"
run "edit CI workflow"         ask   "$(e Edit .github/workflows/ci.yml 'x')"
run "edit go.mod require"      ask   "$(e Edit backend/go.mod $'require github.com/x/y v1.0.0')"
run "edit go.mod module only"  allow "$(e Edit backend/go.mod 'module example.com/app')"
run "edit package.json dep"    ask   "$(e Edit frontend/package.json '"axios": "^1.7.0"')"
run "edit package.json script" allow "$(e Edit frontend/package.json '"dev": "vite"')"
run "edit existing migration"  ask   "$(e Edit backend/db/migrations/00001_init.sql 'ALTER')"
run "write NEW migration"      allow "$(e Write backend/db/migrations/00002_users.sql 'CREATE TABLE')"
run "edit go source"           allow "$(e Edit backend/internal/x.go 'func a(){}')"
run "garbage fails open"       allow 'not json'
exit $fail
