#!/usr/bin/env bash
# PreCompact: stores a names-only state snapshot in Engram right before compaction, without depending on Claude.
# Needs the host `engram` CLI; silently does nothing otherwise. Never stores file contents.
set -u
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
command -v engram >/dev/null 2>&1 || exit 0
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9_-')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger // .matcher // "unknown"' 2>/dev/null)
[ -n "$CWD" ] && [ -d "$CWD" ] || CWD="$PWD"
BRANCH=$(git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null || echo "-")
TOP=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")
LAST=$(git -C "$CWD" log -1 --format='%h %s' 2>/dev/null || echo "-")
CHANGED=$(git -C "$CWD" status --short 2>/dev/null | head -20)
CONTENT=$(printf '**What**: automatic snapshot before %s compaction at %s\n**Where**: %s (branch %s)\n**Learned**: last commit: %s\nChanged files (names only):\n%s\n(Written by the kit precompact hook. Resume with mem_context.)' \
  "$TRIGGER" "$(date '+%Y-%m-%d %H:%M')" "$TOP" "$BRANCH" "$LAST" "${CHANGED:-(clean)}")
PROJECT="${ENGRAM_PROJECT:-$(basename "$TOP")}"
timeout 4 engram save "Auto snapshot before compaction ($BRANCH)" "$CONTENT" --type note --project "$PROJECT" --topic "auto-snapshot/${SID:-unknown}" >/dev/null 2>&1
exit 0
