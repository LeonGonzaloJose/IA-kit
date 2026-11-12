#!/usr/bin/env bash
# PostToolUse (Edit|Write): formats and lints the edited file. Silent when everything is fine.
# Blocks (exit 2) on the tool's exit status, never on its output: golangci-lint prints "0 issues." on success.
f="$(python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
[ -f "$f" ] || exit 0
dir="$(dirname "$f")"; out=""; rc=0
case "$f" in
  *.go)
    if command -v gofumpt >/dev/null; then out="$(gofumpt -w "$f" 2>&1)"; rc=$?; fi
    # outside a module (GOMOD empty or /dev/null) the linter cannot typecheck: nothing to report
    gomod="$(cd "$dir" && go env GOMOD 2>/dev/null)"
    if [ "$rc" -eq 0 ] && command -v golangci-lint >/dev/null && [ -n "$gomod" ] && [ "$gomod" != /dev/null ]; then
      out="$(cd "$dir" && golangci-lint run --fast-only ./... 2>&1)"; rc=$?
    fi ;;
  *.vue|*.ts|*.js)
    root="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)"
    if [ -x "$root/node_modules/.bin/eslint" ]; then out="$(cd "$root" && node_modules/.bin/eslint --fix "$f" 2>&1)"; rc=$?; fi ;;
esac
[ "$rc" -eq 0 ] && exit 0
echo "$out" | head -15 >&2
exit 2
