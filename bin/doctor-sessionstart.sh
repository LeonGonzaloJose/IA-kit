#!/usr/bin/env bash
# SessionStart: refreshes the kit health state in the background (never delays startup).
# The statusline reads $CFG/kit/state/doctor.json; run /kit-doctor for details.
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
KIT="$(dirname "$(dirname "$(readlink -f "$0")")")"
[ -x "$KIT/bin/doctor.sh" ] || exit 0
mkdir -p "$CFG/kit/state" 2>/dev/null || exit 0
(
  out="$(timeout 20 bash "$KIT/bin/doctor.sh" --quiet 2>/dev/null)"
  f=$(printf '%s\n' "$out" | grep -c '^  FAIL'); w=$(printf '%s\n' "$out" | grep -c '^  WARN')
  printf '{"fail":%s,"warn":%s}\n' "$f" "$w" > "$CFG/kit/state/doctor.json.$$" && mv -f "$CFG/kit/state/doctor.json.$$" "$CFG/kit/state/doctor.json"
) >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
