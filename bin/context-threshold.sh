#!/usr/bin/env bash
# UserPromptSubmit: asks Claude to persist state to Engram BEFORE auto-compact. Each band fires once per session.
#   save  (80% of the compact threshold, default 200k tokens): write mem_session_summary + mem_save now
#   warn  (KIT_CTX_COMPACT_TOKENS, default 250000 = autoCompactWindow): close the phase; compaction is imminent
set -u
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
WINDOW=$(printf '%s' "$INPUT" | jq -r '.context_window.context_window_size // empty' 2>/dev/null)
[ -n "$WINDOW" ] && [ "$WINDOW" != "null" ] || WINDOW=1000000
WARN_TOKENS=${KIT_CTX_COMPACT_TOKENS:-250000}
[ "$WARN_TOKENS" -gt $(( WINDOW * 9 / 10 )) ] && WARN_TOKENS=$(( WINDOW * 9 / 10 ))
SAVE_TOKENS=${KIT_CTX_SAVE_TOKENS:-$(( WARN_TOKENS * 8 / 10 ))}

TOKENS=$(printf '%s' "$INPUT" | jq -r '.context_window.total_input_tokens // empty' 2>/dev/null)
if [ -z "$TOKENS" ] || [ "$TOKENS" = "null" ]; then
  T=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -n "$T" ] && [ -f "$T" ]; then
    TOKENS=$(jq -rc 'select(.type == "assistant" and (.isSidechain != true))
        | (.message.usage // .usage) as $u | select($u != null)
        | (($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0))' "$T" 2>/dev/null | tail -n1)
  fi
fi
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9_-')
# Marker lives in a user-private dir (never world-writable /tmp) and is ignored if someone planted a symlink there.
if [ -n "${KIT_STATE_DIR:-}" ]; then STATE_DIR="$KIT_STATE_DIR"
elif [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then STATE_DIR="$XDG_RUNTIME_DIR"
else STATE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/kit/state"; mkdir -p "$STATE_DIR" 2>/dev/null && chmod 700 "$STATE_DIR" 2>/dev/null; fi
MARKER=""; [ -n "$SID" ] && [ -d "$STATE_DIR" ] && MARKER="$STATE_DIR/kit-ctx-band-$SID"
[ -n "$MARKER" ] && [ -L "$MARKER" ] && MARKER=""
[ -n "$TOKENS" ] && [ "$TOKENS" != "null" ] && [ "$TOKENS" -gt 0 ] 2>/dev/null || exit 0

if [ "$TOKENS" -lt "$SAVE_TOKENS" ]; then [ -n "$MARKER" ] && rm -f "$MARKER" 2>/dev/null; exit 0; fi
if [ "$TOKENS" -ge "$WARN_TOKENS" ]; then BAND=warn; else BAND=save; fi
LAST=""; [ -n "$MARKER" ] && [ -f "$MARKER" ] && LAST=$(cat "$MARKER" 2>/dev/null)
if [ "$LAST" = "$BAND" ] || { [ "$LAST" = "warn" ] && [ "$BAND" = "save" ]; }; then exit 0; fi
[ -n "$MARKER" ] && echo "$BAND" > "$MARKER" 2>/dev/null

K=$(( TOKENS / 1000 ))
if [ "$BAND" = "save" ]; then
  MSG="CONTEXT AT ${K}k TOKENS; auto-compact at $(( WARN_TOKENS / 1000 ))k. Before answering: (1) commit work in progress if appropriate, (2) call mem_session_summary in Engram (done, decisions, files touched, concrete next step) and mem_save each pending decision, (3) then continue. After compaction resume with mem_context; do not re-read files already covered."
else
  MSG="CONTEXT AT ${K}k TOKENS: compaction threshold ($(( WARN_TOKENS / 1000 ))k) reached. If there is no recent mem_session_summary, save one to Engram now, finish the current phase and continue after compaction with mem_context. Do not launch new subagents from a context this large."
fi
jq -nc --arg msg "$MSG" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
