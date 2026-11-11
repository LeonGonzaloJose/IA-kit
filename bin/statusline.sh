#!/usr/bin/env bash
# Statusline del kit: claude-hud (modelo, proyecto, rama, contexto, uso)
# + línea extra: versión del kit y commits de diferencia contra main/master.
input="$(cat)"
kit="$(dirname "$(dirname "$(readlink -f "$0")")")"
ver="$(cat "$kit/VERSION" 2>/dev/null || echo '?')"
hud="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/claude-hud/dist/index.js"
[ -f "$hud" ] && printf '%s' "$input" | node "$hud"

line="kit v$ver"
cwd="$(printf '%s' "$input" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("workspace",{}).get("current_dir") or d.get("cwd",""))' 2>/dev/null)"
if [ -n "$cwd" ] && cd "$cwd" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  base=""
  for b in origin/main origin/master main master; do
    git rev-parse --verify -q "$b" >/dev/null && { base="$b"; break; }
  done
  cur="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -n "$base" ] && [ "$cur" != "${base#origin/}" ]; then
    read -r behind ahead < <(git rev-list --left-right --count "$base"...HEAD 2>/dev/null)
    line="$line │ vs $base: ↑${ahead:-0} ↓${behind:-0}"
  elif [ -n "$base" ]; then
    line="$line │ en ${base#origin/}"
  fi
fi
st="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/kit/state/doctor.json"
if [ -f "$st" ] && command -v jq >/dev/null 2>&1; then
  f=$(jq -r '.fail // 0' "$st" 2>/dev/null); w=$(jq -r '.warn // 0' "$st" 2>/dev/null)
  if [ "${f:-0}" -gt 0 ]; then d=$'\033[31m'"doctor ✗${f}"$'\033[0m\033[2m'
  elif [ "${w:-0}" -gt 0 ]; then d=$'\033[33m'"doctor ⚠${w}"$'\033[0m\033[2m'
  else d=$'\033[32m'"doctor ✓"$'\033[0m\033[2m'; fi
  line="$line │ $d"
fi
printf '\033[2m%s\033[0m\n' "$line"
