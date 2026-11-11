#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SL="$ROOT/bin/statusline.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CLAUDE_CONFIG_DIR="$TMP/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR/kit/state"
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; fail=1; }
G="git -c user.name=t -c user.email=t@t"
R="$TMP/repo"; mkdir -p "$R"; cd "$R"; git init -q -b main; $G commit -q --allow-empty -m a
git checkout -q -b feat; $G commit -q --allow-empty -m b; $G commit -q --allow-empty -m c
run() { printf '{"workspace":{"current_dir":"%s"}}' "$1" | bash "$SL" | tail -1 | sed 's/\x1b\[[0-9;]*m//g'; }
VER=$(cat "$ROOT/VERSION")
out=$(run "$R"); [[ "$out" == "kit v$VER │ vs main: ↑2 ↓0" ]] && ok "ahead of main + version" || bad "ahead" "$out"
git checkout -q main; out=$(run "$R"); [[ "$out" == "kit v$VER │ en main" ]] && ok "on main" || bad "on main" "$out"
out=$(run "$TMP"); [[ "$out" == "kit v$VER" ]] && ok "no git: version only" || bad "no git" "$out"
echo '{"fail":0,"warn":0}' > "$CLAUDE_CONFIG_DIR/kit/state/doctor.json"; out=$(run "$TMP"); [[ "$out" == *"doctor ✓"* ]] && ok "doctor healthy" || bad "doctor ok" "$out"
echo '{"fail":0,"warn":3}' > "$CLAUDE_CONFIG_DIR/kit/state/doctor.json"; out=$(run "$TMP"); [[ "$out" == *"doctor ⚠3"* ]] && ok "doctor warnings" || bad "doctor warn" "$out"
echo '{"fail":2,"warn":3}' > "$CLAUDE_CONFIG_DIR/kit/state/doctor.json"; out=$(run "$TMP"); [[ "$out" == *"doctor ✗2"* ]] && ok "doctor failures" || bad "doctor fail" "$out"
rm -f "$CLAUDE_CONFIG_DIR/kit/state/doctor.json"
start=$(date +%s%N); printf '{}' | bash "$ROOT/bin/doctor-sessionstart.sh"; el=$(( ($(date +%s%N) - start) / 1000000 ))
[ "$el" -lt 1500 ] && ok "sessionstart hook returns fast (${el}ms)" || bad "sessionstart slow" "${el}ms"
exit $fail
