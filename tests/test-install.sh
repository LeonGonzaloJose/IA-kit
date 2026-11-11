#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CLAUDE_CONFIG_DIR="$TMP/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR/commands"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
cat > "$CLAUDE_CONFIG_DIR/settings.json" <<'JSON'
{"theme":"dark","env":{"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE":"25","MY_VAR":"1"},
 "permissions":{"ask":["Bash(my cmd*)"]},
 "hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/my/own/hook.sh"}]},
  {"matcher":"Bash","hooks":[{"type":"command","command":"bash /old/kit/bin/guard.sh"}]}]}}
JSON
touch "$CLAUDE_CONFIG_DIR/commands/mine.md"
S="$CLAUDE_CONFIG_DIR/settings.json"
bash "$ROOT/install.sh" --dry-run --skip-plugins >/dev/null; [ ! -e "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && ok "dry-run writes nothing" || bad "dry-run wrote files"
bash "$ROOT/install.sh" --skip-plugins >/dev/null 2>&1 && ok "install runs" || bad "install failed"
[ -L "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && [ -L "$CLAUDE_CONFIG_DIR/kit/bin" ] && ok "symlinks created" || bad "symlinks"
[ -f "$CLAUDE_CONFIG_DIR/commands/mine.md" ] && [ ! -L "$CLAUDE_CONFIG_DIR/commands/mine.md" ] && ok "user's own command untouched" || bad "user command"
jq -e '.theme=="dark" and .env.MY_VAR=="1"' "$S" >/dev/null && ok "user settings preserved" || bad "user settings lost"
jq -e '.env|has("CLAUDE_AUTOCOMPACT_PCT_OVERRIDE")|not' "$S" >/dev/null && ok "deprecated env removed" || bad "deprecated env"
jq -e '.autoCompactWindow==250000' "$S" >/dev/null && ok "autoCompactWindow set" || bad "autoCompactWindow"
jq -e '[.hooks.PreToolUse[].hooks[].command]|any(.=="/my/own/hook.sh")' "$S" >/dev/null && ok "foreign hook preserved" || bad "foreign hook"
[ "$(jq '[.hooks.PreToolUse[].hooks[].command|select(test("guard.sh"))]|length' "$S")" -eq 2 ] && ok "old kit hook replaced (env-guard + guard, no duplicate)" || bad "stale kit hook"
jq -e '.permissions.ask|index("Bash(my cmd*)") and index("Bash(git push*)")' "$S" >/dev/null && ok "permissions merged" || bad "permissions"
h1=$(sha256sum "$S"); bash "$ROOT/install.sh" --skip-plugins >/dev/null 2>&1; h2=$(sha256sum "$S")
[ "$h1" = "$h2" ] && ok "second run is idempotent" || bad "not idempotent"
ls "$CLAUDE_CONFIG_DIR"/settings.json.bak.* >/dev/null 2>&1 && ok "backup created" || bad "no backup"
for c in $(jq -r '.. | .command? // empty' "$S" | rg -o 'kit/bin/[a-z-]+\.sh' | sort -u); do [ -x "$ROOT/bin/$(basename $c)" ] || bad "hook script missing: $c"; done; ok "all hook scripts exist"
# invalid settings.json: clear error, nothing written, non-zero exit
export CLAUDE_CONFIG_DIR="$TMP/bad"; mkdir -p "$CLAUDE_CONFIG_DIR"; printf '{"theme": "dark",' > "$CLAUDE_CONFIG_DIR/settings.json"
out=$(bash "$ROOT/install.sh" --skip-plugins 2>&1); rc=$?
[ "$rc" -ne 0 ] && [[ "$out" == *"no es JSON válido"* ]] && ok "invalid settings.json: clear error, exit $rc" || bad "invalid settings.json (rc=$rc): $out"
[ "$(cat "$CLAUDE_CONFIG_DIR/settings.json")" = '{"theme": "dark",' ] && [ ! -e "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && [ ! -e "$CLAUDE_CONFIG_DIR/kit" ] && ok "invalid settings.json: nothing touched" || bad "invalid settings.json touched files"
exit $fail
