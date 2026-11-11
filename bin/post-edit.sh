#!/usr/bin/env bash
# PostToolUse (Edit|Write): formatea y lintea el archivo editado. Silencioso si todo está bien.
f="$(python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
[ -f "$f" ] || exit 0
dir="$(dirname "$f")"; out=""
case "$f" in
  *.go)
    command -v gofumpt >/dev/null && gofumpt -w "$f"
    command -v golangci-lint >/dev/null && out="$(cd "$dir" && golangci-lint run --fast-only ./... 2>&1 | head -15)" ;;
  *.vue|*.ts|*.js)
    root="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)"
    [ -x "$root/node_modules/.bin/eslint" ] && out="$(cd "$root" && node_modules/.bin/eslint --fix "$f" 2>&1 | head -15)" ;;
esac
[ -n "$out" ] && { echo "$out" >&2; exit 2; }
exit 0
