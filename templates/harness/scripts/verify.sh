#!/usr/bin/env bash
# kit-harness: managed file (the kit's harness-install.sh updates it; local edits are overwritten)
# Project verification entry point. Its output is the evidence that a task is done.
#   verify.sh         fast checks, no Docker: Go fmt/vet/lint/test, front typecheck/lint/test
#   verify.sh --full  adds the Postgres integration harness
#   VERIFY_TIMEOUT    seconds allowed per step (default 900)
# A step that cannot run is reported as SKIPPED, never silently dropped; a run where no test ran is a FAIL.
set -uo pipefail
cd "$(dirname "$0")/.."

full=0
case "${1:-}" in "") ;; --full) full=1 ;; *) echo "usage: verify.sh [--full]" >&2; exit 2 ;; esac
limit="${VERIFY_TIMEOUT:-900}"

passed=(); failed=(); skipped=(); tests_ran=0
step() { # step <name> <command...>
  local name="$1"; shift
  echo "== $name"
  if "$@"; then passed+=("$name"); else failed+=("$name"); fi
}
skip() { echo "== $1: SKIPPED ($2)"; skipped+=("$1 ($2)"); }
have() { command -v "$1" >/dev/null; }
run_in() { # run_in <dir> <command...>: no stdin and a time limit, so a watcher or a prompt cannot hang an unattended run
  local dir="$1" rc; shift
  if have timeout; then timeout "$limit" bash -c 'cd "$1" && shift && exec "$@"' _ "$dir" "$@" </dev/null
  else (cd "$dir" && exec "$@") </dev/null; fi
  rc=$?
  [ "$rc" -ne 124 ] || echo "timed out after ${limit}s (VERIFY_TIMEOUT)"
  return "$rc"
}
gofmt_clean() {
  local out
  out="$(run_in "$go_dir" gofmt -l . 2>&1)" || { echo "$out"; return 1; }
  # dependencies are not ours to format
  out="$(grep -Ev '(^|/)(node_modules|vendor)/' <<<"$out")"
  [ -z "$out" ] || { echo "not gofmt-ed:"; echo "$out"; return 1; }
}
# go list honours build tags: integration-only test files do not count as tests of the fast run
has_go_tests() { [ -n "$(run_in "$go_dir" go list -f '{{if or .TestGoFiles .XTestGoFiles}}x{{end}}' ./... 2>/dev/null)" ]; }
npm_script() { node -e 'process.exit((require(process.argv[1]).scripts || {})[process.argv[2]] ? 0 : 1)' "$PWD/$front_dir/package.json" "$1"; }

go_dir=""; front_dir=""
if [ -f backend/go.mod ]; then go_dir=backend; elif [ -f go.mod ]; then go_dir=.; fi
# same rule as the installer: a root package.json is the front only when it depends on vue
if [ -f frontend/package.json ]; then front_dir=frontend; elif [ -f package.json ] && grep -q '"vue"' package.json; then front_dir=.; fi

if [ -n "$go_dir" ]; then
  if ! have go || ! have gofmt; then echo "== go: go or gofmt not found"; failed+=("go tools")
  else
    step "go fmt" gofmt_clean
    step "go vet" run_in "$go_dir" go vet ./...
    if have golangci-lint; then step "go lint" run_in "$go_dir" golangci-lint run ./...; else skip "go lint" "golangci-lint not installed"; fi
    if has_go_tests; then step "go test" run_in "$go_dir" go test ./... -count=1; tests_ran=1; else skip "go test" "no test files"; fi
    if [ "$full" -eq 1 ]; then
      if [ -f "$go_dir/scripts/test-integration.sh" ]; then step "integration" run_in . bash "$go_dir/scripts/test-integration.sh"; tests_ran=1
      else skip "integration" "no $go_dir/scripts/test-integration.sh"; fi
    fi
  fi
elif [ "$full" -eq 1 ]; then skip "integration" "no Go module"; fi

if [ -n "$front_dir" ]; then
  if ! have node || ! have npm; then echo "== front: node or npm not found"; failed+=("front tools")
  elif ! node -e 'require(process.argv[1])' "$PWD/$front_dir/package.json" 2>/dev/null; then echo "== front: $front_dir/package.json is not valid JSON"; failed+=("front package.json")
  elif [ ! -d "$front_dir/node_modules" ]; then echo "== front: node_modules missing (run npm ci in $front_dir)"; failed+=("front install")
  else
    for script in typecheck lint test; do
      # CI=true: test runners such as vitest run once instead of watching
      if npm_script "$script"; then
        step "front $script" run_in "$front_dir" env CI=true npm run -s "$script"
        [ "$script" != test ] || tests_ran=1
      else skip "front $script" "no npm script"; fi
    done
  fi
fi

echo
if [ -z "$go_dir$front_dir" ]; then echo "verify: FAIL (no go.mod or Vue package.json found)"; exit 1; fi
[ "${#skipped[@]}" -eq 0 ] || printf 'skipped: %s\n' "${skipped[@]}"
[ "${#failed[@]}" -eq 0 ] || printf 'failed: %s\n' "${failed[@]}"
counts="${#passed[@]} passed, ${#failed[@]} failed, ${#skipped[@]} skipped"
if [ "${#failed[@]}" -gt 0 ]; then echo "verify: FAIL ($counts)"; exit 1; fi
# green lint over untested code is not evidence
if [ "$tests_ran" -eq 0 ]; then echo "verify: FAIL (no test ran: $counts)"; exit 1; fi
echo "verify: PASS ($counts)"
