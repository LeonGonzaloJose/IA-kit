#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/bin/context-threshold.sh"
export KIT_STATE_DIR="$(mktemp -d)"; trap 'rm -rf "$KIT_STATE_DIR"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; fail=1; }
inp() { printf '{"session_id":"s1","context_window":{"context_window_size":1000000,"total_input_tokens":%s}}' "$1"; }
out=$(inp 100000 | bash "$HOOK"); [ -z "$out" ] && ok "below save band: silent" || bad "below" "$out"
out=$(inp 210000 | bash "$HOOK"); [[ "$out" == *"mem_session_summary"* && "$out" == *"auto-compact at 250k"* ]] && ok "save band fires" || bad "save" "$out"
out=$(inp 215000 | bash "$HOOK"); [ -z "$out" ] && ok "save band fires once" || bad "once" "$out"
out=$(inp 260000 | bash "$HOOK"); [[ "$out" == *"threshold"* ]] && ok "warn band fires" || bad "warn" "$out"
out=$(inp 270000 | bash "$HOOK"); [ -z "$out" ] && ok "warn band fires once" || bad "warn once" "$out"
out=$(inp 50000 | bash "$HOOK"); [ -z "$out" ] && ok "reset after compaction" || bad "reset" "$out"
out=$(inp 210000 | bash "$HOOK"); [ -n "$out" ] && ok "re-arms after reset" || bad "rearm" "$out"
out=$(printf 'garbage' | bash "$HOOK"); [ -z "$out" ] && ok "garbage fails open" || bad "garbage" "$out"
echo keep > "$KIT_STATE_DIR/target"; ln -sfn "$KIT_STATE_DIR/target" "$KIT_STATE_DIR/kit-ctx-band-s2"
out=$(printf '{"session_id":"s2","context_window":{"context_window_size":1000000,"total_input_tokens":210000}}' | bash "$HOOK")
[ -n "$out" ] && [ "$(cat "$KIT_STATE_DIR/target")" = keep ] && ok "symlinked marker is ignored, not followed" || bad "symlink" "$out / $(cat "$KIT_STATE_DIR/target")"
CFG="$KIT_STATE_DIR/cfg"; out=$(KIT_STATE_DIR= XDG_RUNTIME_DIR= CLAUDE_CONFIG_DIR="$CFG" bash -c 'printf "{\"session_id\":\"s3\",\"context_window\":{\"context_window_size\":1000000,\"total_input_tokens\":210000}}" | bash "$0"' "$HOOK")
[ -n "$out" ] && [ "$(stat -c %a "$KIT_STATE_DIR/cfg/kit/state")" = 700 ] && [ -f "$KIT_STATE_DIR/cfg/kit/state/kit-ctx-band-s3" ] && ok "fallback state dir under config is 0700" || bad "state dir fallback" "$out"
out=$(bash "$ROOT/bin/compact-handoff.sh" | jq -r '.hookSpecificOutput.additionalContext' | head -c 40); [[ "$out" == "The session was just compacted"* ]] && ok "compact handoff JSON valid" || bad "handoff" "$out"
out=$(printf '{"session_id":"s1","cwd":"/nonexistent"}' | bash "$ROOT/bin/precompact-snapshot.sh"; echo "rc=$?"); [[ "$out" == *"rc=0" ]] && ok "precompact never fails" || bad "precompact" "$out"
exit $fail
