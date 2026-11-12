#!/usr/bin/env bash
# post-edit hook: blocks on real lint or format failures only, never on a clean run.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
hook() { jq -nc --arg f "$1" '{tool_input:{file_path:$f}}' | bash "$ROOT/bin/post-edit.sh" 2>"$TMP/err"; }
expect() { # expect <name> <exit code> <file>
  hook "$3"; local rc=$?
  [ "$rc" -eq "$2" ] && ok "$1" || { bad "$1 (exit $rc, want $2)"; head -n 3 "$TMP/err"; }
}

expect "missing file is ignored" 0 "$TMP/nope.go"
echo "plain" > "$TMP/notes.txt"; expect "other file types are ignored" 0 "$TMP/notes.txt"
if ! command -v go >/dev/null || ! command -v golangci-lint >/dev/null; then echo "SKIP go or golangci-lint not found: Go cases not run"; exit $fail; fi

mkdir -p "$TMP/mod" "$TMP/nomod" "$TMP/tpl"
printf 'module example.com/pe\n\ngo 1.24\n' > "$TMP/mod/go.mod"
printf 'package main\n\nfunc main() {}\n' > "$TMP/mod/main.go"
expect "clean Go file in a module does not block" 0 "$TMP/mod/main.go"
[ ! -s "$TMP/err" ] && ok "clean run is silent" || bad "clean run printed: $(head -n 1 "$TMP/err")"
printf 'package main\n\nfunc main() {\n\tx := 1\n\tx = 2\n\t_ = x\n}\n' > "$TMP/mod/main.go"
expect "a lint issue blocks" 2 "$TMP/mod/main.go"
grep -q ineffassign "$TMP/err" && ok "the issue is reported" || bad "issue not reported"
printf 'package main\n\nfunc main( {\n' > "$TMP/mod/main.go"
expect "Go that does not parse blocks" 2 "$TMP/mod/main.go"
printf 'package main\n\nfunc main() {}\n' > "$TMP/nomod/main.go"
expect "Go file outside a module does not block" 0 "$TMP/nomod/main.go"
printf 'module __MODULE__\n\ngo 1.24\n' > "$TMP/tpl/go.mod"; printf 'package main\n\nfunc main() {}\n' > "$TMP/tpl/main.go"
expect "kit template with a placeholder module does not block" 0 "$TMP/tpl/main.go"
if command -v gofumpt >/dev/null; then
  printf 'package main\n\nfunc main() {\n\n}\n' > "$TMP/nomod/main.go"; hook "$TMP/nomod/main.go"
  [ "$(grep -c '^$' "$TMP/nomod/main.go")" -eq 1 ] && ok "gofumpt formats the file" || bad "file not formatted"
fi
exit $fail
