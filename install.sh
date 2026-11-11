#!/usr/bin/env bash
# Installs the kit into the global Claude config (symlinks + plugins + merged settings). Idempotent.
# Usage: install.sh [--dry-run] [--skip-plugins]
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DRY=0 SKIP_PLUGINS=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; --skip-plugins) SKIP_PLUGINS=1 ;; *) echo "unknown option: $a" >&2; exit 2 ;; esac; done
run() { if [ "$DRY" -eq 1 ]; then echo "dry   $*"; else "$@"; fi; }
[ "$DRY" -eq 1 ] && echo "DRY RUN: nothing will be written (config: $DEST)"
# Validate before creating any link so a broken settings.json leaves the config untouched.
if [ -f "$DEST/settings.json" ] && ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$DEST/settings.json" 2>/dev/null; then
  echo "ERROR: $DEST/settings.json no es JSON válido. Corregilo (o movelo) y volvé a ejecutar install.sh; no se tocó nada." >&2; exit 1
fi
run mkdir -p "$DEST"

link() { # link <source> <dest>
  if [ -e "$2" ] && [ ! -L "$2" ]; then run mv "$2" "$2.bak.$(date +%s)"; fi
  run ln -sfn "$1" "$2"; echo "link  ${2#$DEST/}"
}
for f in CLAUDE.md tools.md RTK.md; do [ -e "$KIT/$f" ] && link "$KIT/$f" "$DEST/$f"; done
run mkdir -p "$DEST/kit"; link "$KIT" "$DEST/kit/root"; link "$KIT/bin" "$DEST/kit/bin"; link "$KIT/services" "$DEST/kit/services"
for d in commands agents skills; do
  run mkdir -p "$DEST/$d"
  for e in "$KIT/$d"/*; do [ -e "$e" ] && link "$e" "$DEST/$d/$(basename "$e")"; done
  # remove links that point into the kit but whose target was deleted
  for l in "$DEST/$d"/*; do
    if [ -L "$l" ] && [ ! -e "$l" ] && [[ "$(readlink "$l")" == "$KIT/"* ]]; then run rm -f "$l"; echo "clean ${l#$DEST/}"; fi
  done
done

if [ "$SKIP_PLUGINS" -eq 0 ] && command -v claude >/dev/null 2>&1; then
  grep -v '^\s*#' "$KIT/marketplaces.txt" | while read -r name src; do
    [ -n "${name:-}" ] || continue
    claude plugin marketplace list 2>/dev/null | grep -q "❯ $name\$" && continue
    if [ "$src" = builtin ]; then echo "FAIL marketplace $name: debería venir con Claude Code (actualizá claude)"; continue; fi
    run claude plugin marketplace add "$src" || echo "FAIL marketplace $name"
  done
  installed="$(claude plugin list 2>/dev/null || true)"
  grep -v '^\s*#' "$KIT/plugins.txt" | while read -r p; do
    [ -n "${p:-}" ] || continue
    if echo "$installed" | grep -q "❯ $p\$"; then echo "ok    $p"; else run claude plugin install "$p" || echo "FAIL $p"; fi
  done
else echo "skip  plugins"; fi

python3 - "$KIT" "$DEST" "$DRY" <<'PY'
import json, os, shutil, sys, time
kit, dest, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
sp = os.path.join(dest, "settings.json")
cur = json.load(open(sp)) if os.path.exists(sp) else {}
before = json.dumps(cur, sort_keys=True)
frag = json.load(open(os.path.join(kit, "config/settings.fragment.json")))

for k in frag.get("_remove_env", []):
    cur.get("env", {}).pop(k, None)
for k, v in frag.get("env", {}).items():
    cur.setdefault("env", {})[k] = v
for k in ("autoCompactWindow", "statusLine"):
    if k in frag: cur[k] = frag[k]
for kind, items in frag.get("permissions", {}).items():
    lst = cur.setdefault("permissions", {}).setdefault(kind, [])
    for i in items:
        if i not in lst: lst.append(i)

def kit_owned(entry):  # hooks installed by this kit live under .../kit/bin/
    return any("/kit/bin/" in h.get("command", "") for h in entry.get("hooks", []))
for ev, entries in frag.get("hooks", {}).items():
    lst = [e for e in cur.setdefault("hooks", {}).get(ev, []) if not kit_owned(e)]
    for e in entries:
        if e not in lst: lst.append(e)
    cur["hooks"][ev] = lst

if json.dumps(cur, sort_keys=True) == before:
    print("settings.json already up to date")
elif dry:
    print("dry   settings.json would change")
else:
    if os.path.exists(sp): shutil.copy(sp, f"{sp}.bak.{int(time.time())}")
    json.dump(cur, open(sp, "w"), indent=2, ensure_ascii=False)
    print("merge settings.json")

hp = os.path.join(dest, "plugins/claude-hud/config.json")
if os.path.isdir(os.path.dirname(hp)):
    h = json.load(open(hp)) if os.path.exists(hp) else {}
    new = {**h, **json.load(open(os.path.join(kit, "config/hud.json")))}
    if new != h and not dry:
        json.dump(new, open(hp, "w"), indent=2, ensure_ascii=False); print("merge hud config")
PY
echo "done (kit v$(cat "$KIT/VERSION"))"
