#!/usr/bin/env bash
# Project harness installer: new and existing projects, idempotency, and never overwriting a file it does not manage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INST="$ROOT/bin/harness-install.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
tree_sum() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum); }
field() { jq -r "$1" <<<"$out"; }
has_note() { field '.notes[]' | grep -q -- "$1"; }
go_repo() { # go_repo <dir>: a minimal module with one passing test
  mkdir -p "$1"; printf 'module example.com/repo\n\ngo 1.22\n' > "$1/go.mod"
  printf 'package main\n\nfunc add(a, b int) int { return a + b }\n\nfunc main() { _ = add(1, 2) }\n' > "$1/main.go"
  printf 'package main\n\nimport "testing"\n\nfunc TestAdd(t *testing.T) {\n\tif add(1, 2) != 3 {\n\t\tt.Fatal("add")\n\t}\n}\n' > "$1/main_test.go"
}
command -v go >/dev/null || echo "SKIP go not found: Go verify cases not run"
command -v npm >/dev/null || echo "SKIP npm not found: front verify cases not run"

"$INST" >/dev/null 2>&1; [ $? -eq 2 ] && ok "no args is a usage error" || bad "no args"
mkdir "$TMP/empty"; "$INST" "$TMP/empty" >/dev/null 2>&1; [ $? -eq 2 ] && [ -z "$(ls -A "$TMP/empty")" ] && ok "refuses a directory with nothing to verify" || bad "empty directory"

# (b) existing Go repo: module at the root, no Makefile, no CLAUDE.md, Postgres under another service name, path with spaces
G="$TMP/go repo"; go_repo "$G"; mkdir -p "$G/db/migrations"
printf 'services:\n  db:\n    image: postgres:17\n' > "$G/docker-compose.yaml"
before="$(tree_sum "$G")"
out="$("$INST" "$G" --dry-run 2>/dev/null)"; dry_notes="$(field '.notes|sort|join("|")')"; dry_installed="$(field '.installed|sort|join(" ")')"
[ "$(tree_sum "$G")" = "$before" ] && [ "$(field .dry_run)" = true ] && ok "dry-run writes nothing" || bad "dry-run wrote files"
out="$("$INST" "$G" 2>/dev/null)"
want="Makefile docs/HARNESS.md harness.mk internal/testutil/db.go internal/testutil/db_integration_test.go internal/testutil/fixtures/00_example.sql scripts/test-integration.sh scripts/verify.sh"
[ "$(field '.installed|sort|join(" ")')" = "$want" ] && [ "$dry_installed" = "$want" ] && [ "$(field '.notes|sort|join("|")')" = "$dry_notes" ] && ok "dry-run announces exactly what the real run does (files and notes)" || bad "dry-run differs from the real run: $out / $dry_notes"
[ "$(field .go_dir)" = . ] && [ "$(field .postgres)" = true ] && [ -x "$G/scripts/verify.sh" ] && [ -x "$G/scripts/test-integration.sh" ] && ok "existing Go repo: verify + integration harness at the module root" || bad "existing Go repo install: $out"
grep -q '^require github.com/jackc/pgx/v5 ' "$G/go.mod" && has_note HARNESS_PG_SERVICE && has_note 'no CLAUDE.md' && has_note 'go mod tidy' && ! has_note 'no Makefile' && ok "pgx required; notes name the service, go mod tidy and the missing CLAUDE.md" || bad "go.mod or notes: $out"
make -C "$G" -n verify-full test-integration >/dev/null 2>&1 && ok "root Makefile exposes verify-full and test-integration" || bad "root Makefile targets"
after="$(tree_sum "$G")"; out="$("$INST" "$G" 2>/dev/null)"
[ "$(tree_sum "$G")" = "$after" ] && [ "$(field '(.installed+.updated+.kept)|length')" = 0 ] && ok "second run changes nothing" || bad "not idempotent: $out"
if command -v go >/dev/null; then
  log="$(cd "$G" && bash scripts/verify.sh 2>&1)" && grep -q '^verify: PASS' <<<"$log" && grep -q '^== go test' <<<"$log" && ok "verify passes on the existing Go repo" || { bad "verify on the existing Go repo"; tail -n 15 <<<"$log"; }
  sed -i 's/!= 3/!= 4/' "$G/main_test.go"
  log="$(cd "$G" && bash scripts/verify.sh 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && grep -q '^failed: go test' <<<"$log" && grep -q '^verify: FAIL' <<<"$log" && ok "a failing test makes verify fail" || bad "failing test went undetected (rc=$rc)"
  sed -i 's/!= 4/!= 3/' "$G/main_test.go"
  mkdir -p "$G/node_modules/dep"; printf 'package dep\n\n// Badly is formatted badly on purpose.\nfunc   Badly( ) {}\n' > "$G/node_modules/dep/ugly.go"
  (cd "$G" && bash scripts/verify.sh 2>&1) | grep -q '^verify: PASS' && ok "unformatted Go under node_modules is ignored" || bad "gofmt checked node_modules"
  printf 'package main\n\nfunc   badly( ) {}\n' > "$G/ugly.go"
  (cd "$G" && bash scripts/verify.sh 2>&1) | grep -q '^failed: go fmt' && ok "unformatted Go makes verify fail" || bad "gofmt check"
  printf 'package main\n\nfunc broken( {\n' > "$G/ugly.go"
  (cd "$G" && bash scripts/verify.sh 2>&1) | grep -q '^failed: go fmt' && ok "Go that gofmt cannot parse makes verify fail" || bad "gofmt error went undetected"
  rm "$G/ugly.go" "$G/main_test.go"
  log="$(cd "$G" && bash scripts/verify.sh 2>&1)"; [ $? -ne 0 ] && grep -q '^verify: FAIL (no test ran' <<<"$log" && ok "a run where no test ran is not a PASS" || bad "PASS with nothing tested"
  printf 'package main\n\nimport (\n\t"testing"\n\t"time"\n)\n\nfunc TestSlow(t *testing.T) { time.Sleep(time.Minute) }\n' > "$G/main_test.go"
  log="$(cd "$G" && VERIFY_TIMEOUT=5 bash scripts/verify.sh 2>&1)"; [ $? -ne 0 ] && grep -q 'timed out after 5s' <<<"$log" && ok "a hung step times out and fails" || bad "no timeout"
  rm "$G/main_test.go"
fi
(cd "$G" && bash scripts/verify.sh --nope >/dev/null 2>&1); [ $? -eq 2 ] && ok "verify rejects unknown options" || bad "verify usage"

# files the project owns are kept; managed files are updated
echo "# mine" > "$G/scripts/verify.sh"; echo "-- mine" > "$G/internal/testutil/fixtures/00_example.sql"; echo "# stale copy, kit-harness: managed file" > "$G/harness.mk"
printf '# My notes\n\n\n\nThe kit marks its files with "kit-harness: managed file".\n' > "$G/docs/HARNESS.md"; echo "extra:" >> "$G/Makefile"
out="$("$INST" "$G" 2>/dev/null)"
[ "$(cat "$G/scripts/verify.sh")" = "# mine" ] && field '.kept[]' | grep -qx 'scripts/verify.sh' && ok "a file without the marker is never overwritten" || bad "unmanaged file overwritten: $out"
grep -q '^# My notes' "$G/docs/HARNESS.md" && field '.kept[]' | grep -qx 'docs/HARNESS.md' && ok "a project file that only mentions the marker is kept" || bad "file quoting the marker overwritten: $out"
[ "$(cat "$G/internal/testutil/fixtures/00_example.sql")" = "-- mine" ] && grep -q '^extra:' "$G/Makefile" && ok "the example fixture and the root Makefile belong to the project after the first install" || bad "once file overwritten"
cmp -s "$G/harness.mk" "$ROOT/templates/harness/backend/harness.mk" && field '.updated[]' | grep -qx 'harness.mk' && ok "a managed file is updated" || bad "managed file not updated: $out"

# symlinks are never followed out of the project
S="$TMP/sym"; go_repo "$S"; mkdir "$TMP/outside"; echo "# kit-harness: managed file" > "$TMP/outside/victim.sh"; cp "$TMP/outside/victim.sh" "$TMP/victim.orig"
mkdir "$S/scripts"; ln -s "$TMP/outside/victim.sh" "$S/scripts/verify.sh"; ln -s "$TMP/outside" "$S/docs"
out="$("$INST" "$S" 2>/dev/null)"
cmp -s "$TMP/outside/victim.sh" "$TMP/victim.orig" && [ ! -e "$TMP/outside/HARNESS.md" ] && has_note 'symlink' && ok "symlinked targets are not written through" || bad "wrote through a symlink: $out"

# Postgres detection: commented images and look-alike images do not count
for case in '    # image: postgres:17' '    image: prometheuscommunity/postgres-exporter:v0.15.0' '    image: postgrest/postgrest'; do
  P="$TMP/pg-$RANDOM"; go_repo "$P"; mkdir -p "$P/db/migrations"; printf 'services:\n  postgres:\n%s\n' "$case" > "$P/docker-compose.yml"
  out="$("$INST" "$P" --dry-run 2>/dev/null)"; [ "$(field .postgres)" = false ] && ok "not Postgres:$case" || bad "false Postgres detection:$case"
done
P="$TMP/pg-reg"; go_repo "$P"; mkdir -p "$P/db/migrations"; printf 'services:\n    postgres:\n        image: "docker.io/library/postgres:17"\n' > "$P/compose.yml"
out="$("$INST" "$P" --dry-run 2>/dev/null)"; [ "$(field .postgres)" = true ] && ! has_note HARNESS_PG_SERVICE && ok "registry-prefixed image and 4-space indentation are detected" || bad "postgres detection: $out"

# existing root Makefile without a verify target: kept, with a note; a root tooling package.json is not a front
K="$TMP/mk"; go_repo "$K"; printf 'build:\n\tgo build ./...\n' > "$K/Makefile"; echo "# Project" > "$K/CLAUDE.md"; echo '{"devDependencies":{"husky":"9"}}' > "$K/package.json"; printf 'go 1.22\nuse .\n' > "$K/go.work"
out="$("$INST" "$K" 2>/dev/null)"
grep -q '^build:' "$K/Makefile" && ! grep -q verify "$K/Makefile" && has_note "root Makefile is the project's own" && [ "$(field .postgres)" = false ] && [ ! -e "$K/scripts/test-integration.sh" ] && ok "own Makefile kept with a note; no Postgres, no integration harness" || bad "own Makefile: $out"
[ "$(field .front_dir)" = "" ] && has_note 'does not depend on vue' && has_note 'go.work' && ok "tooling package.json is not a front; go.work is reported" || bad "front or go.work detection: $out"
[ "$(grep -c 'scripts/verify.sh' "$K/CLAUDE.md")" = 1 ] && "$INST" "$K" >/dev/null 2>&1 && [ "$(grep -c 'scripts/verify.sh' "$K/CLAUDE.md")" = 1 ] && ok "CLAUDE.md gets the verification line once" || bad "CLAUDE.md line"
if command -v go >/dev/null; then (cd "$K" && bash scripts/verify.sh 2>&1) | grep -q '^verify: PASS' && ok "verify ignores the tooling package.json" || bad "tooling package.json broke verify"; fi

# (c) front-only repo
F="$TMP/front"; mkdir "$F"; printf '{"name":"front","dependencies":{"vue":"3"},"scripts":{"test":"node -e \\"process.exit(Number(process.env.FAIL||0))\\""}}\n' > "$F/package.json"
out="$("$INST" "$F" 2>/dev/null)"
[ "$(field .front_dir)" = . ] && [ "$(field .go_dir)" = "" ] && [ -x "$F/scripts/verify.sh" ] && [ ! -e "$F/harness.mk" ] && ok "front-only repo: verify only" || bad "front-only install: $out"
if command -v npm >/dev/null; then
  log="$(cd "$F" && bash scripts/verify.sh 2>&1)"; [ $? -ne 0 ] && grep -q 'node_modules missing' <<<"$log" && ok "front without node_modules fails, it is not skipped" || bad "missing node_modules went undetected"
  mkdir "$F/node_modules"
  log="$(cd "$F" && bash scripts/verify.sh 2>&1)" && grep -q '^verify: PASS (1 passed, 0 failed, 2 skipped)' <<<"$log" && grep -q 'skipped: front lint' <<<"$log" && ok "verify passes on the front-only repo and lists skipped steps" || { bad "verify on the front-only repo"; tail -n 8 <<<"$log"; }
  (cd "$F" && FAIL=1 bash scripts/verify.sh >/dev/null 2>&1); [ $? -ne 0 ] && ok "a failing npm test makes verify fail" || bad "failing npm test went undetected"
  mkdir "$TMP/nonode"; for tool in bash dirname grep timeout env; do ln -s "$(command -v "$tool")" "$TMP/nonode/$tool"; done
  log="$(cd "$F" && PATH="$TMP/nonode" bash scripts/verify.sh 2>&1)"; [ $? -ne 0 ] && grep -q '^failed: front tools' <<<"$log" && ok "missing node is a failure, not a skip" || bad "missing node went undetected: $(tail -n 2 <<<"$log")"
  echo '{"dependencies":{"vue":"3"}}' > "$F/package.json"
  log="$(cd "$F" && bash scripts/verify.sh 2>&1)"; [ $? -ne 0 ] && grep -q 'no test ran' <<<"$log" && ok "a front with no scripts is not a PASS" || bad "PASS with no npm scripts"
  echo '{"dependencies":{"vue":' > "$F/package.json"
  (cd "$F" && bash scripts/verify.sh 2>&1) | grep -q '^failed: front package.json' && ok "invalid package.json is a failure" || bad "invalid package.json went undetected"
fi

# (a) project generated by the kit
if command -v go >/dev/null; then
  "$ROOT/bin/new-project.sh" gen --dir "$TMP/gen" --no-front --no-vendor >/dev/null 2>&1 || bad "generate project"
  # --no-vendor leaves a placeholder that the docs test rightly rejects; stand in for the real bundle
  printf '// test stand-in for the Scalar bundle%*s\n' 1200 '' > "$TMP/gen/backend/internal/docs/scalar.standalone.js"
  log="$(cd "$TMP/gen" && make verify 2>&1)" && grep -q '^verify: PASS' <<<"$log" && ok "make verify passes on a generated project" || { bad "make verify on a generated project"; tail -n 20 <<<"$log"; }
  if command -v golangci-lint >/dev/null; then grep -q '^== go lint$' <<<"$log" && ok "generated project passes its own lint" || bad "lint did not run"; else echo "SKIP golangci-lint not found: template lint not checked"; fi
  out="$("$INST" "$TMP/gen" 2>/dev/null)"; [ "$(field '(.installed+.updated+.kept)|length')" = 0 ] && ok "re-running on a generated project changes nothing" || bad "generated project not idempotent: $out"
fi
exit $fail
