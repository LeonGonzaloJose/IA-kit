#!/usr/bin/env bash
# Kit harness: declarative hook cases (tests/cases/<hook>.tsv) + static contract checks.
# usage: harness.sh [--hook NAME] [--list] [--bin DIR] [--no-contract]
# TSV columns: name, want(deny|ask|allow), tool(Bash|Read|Grep|Edit|Write|raw), arg1, arg2 ('\\' '\t' '\n' escapes).
# arg1 must not be empty: consecutive tabs collapse when the line is read.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin"; ONLY=""; LIST=0; CONTRACT=1
while [ $# -gt 0 ]; do case "$1" in
  --hook) ONLY="$2"; shift ;; --bin) BIN="$2"; shift ;; --list) LIST=1 ;; --no-contract) CONTRACT=0 ;;
  *) echo "unknown option: $1" >&2; exit 2 ;; esac; shift; done
CASES="$ROOT/tests/cases"
for t in jq rg; do command -v "$t" >/dev/null || { echo "harness needs $t" >&2; exit 2; }; done
fail=0; total=0
ok()  { total=$((total+1)); echo "ok   $1"; }
bad() { total=$((total+1)); echo "FAIL $1"; fail=1; }
dec() { local s=${1//\\\\/$'\x01'}; s=${s//\\t/$'\t'}; s=${s//\\n/$'\n'}; printf '%s' "${s//$'\x01'/\\}"; }
payload() { # tool arg1 arg2
  case "$1" in
    Bash)  jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' ;;
    Read)  jq -nc --arg p "$2" '{tool_name:"Read",tool_input:{file_path:$p}}' ;;
    Grep)  jq -nc --arg p "$2" '{tool_name:"Grep",tool_input:{pattern:"PASSWORD",path:$p}}' ;;
    Edit|Write) jq -nc --arg t "$1" --arg p "$2" --arg c "$3" '{tool_name:$t,tool_input:{file_path:$p,new_string:$c,content:$c}}' ;;
    raw)   printf '%s' "$2" ;;
    *)     return 1 ;;
  esac; }
verdict() { # hook output -> deny|ask|allow
  case "$1" in *'"permissionDecision":"deny"'*) echo deny ;; *'"permissionDecision":"ask"'*) echo ask ;; "") echo allow ;; *) echo "other" ;; esac; }
run_hook() {
  local h="$1" f="$CASES/$1.tsv" n=0 name want tool a1 a2 in out got
  [ -f "$f" ] || { bad "$h: cases file missing"; return; }
  [ -f "$BIN/$h.sh" ] || { bad "$h: hook script missing in $BIN"; return; }
  while IFS=$'\t' read -r name want tool a1 a2 || [ -n "$name" ]; do
    [ -z "$name" ] && continue
    n=$((n+1))
    if ! in=$(payload "$tool" "$(dec "$a1")" "$(dec "${a2:-}")"); then bad "$h: $name (unknown tool '$tool')"; continue; fi
    # a crashing hook prints nothing, which would read as "allow": the exit code tells them apart
    if ! out=$(printf '%s' "$in" | bash "$BIN/$h.sh" 2>/dev/null); then bad "$h: $name (hook exited non-zero)"; continue; fi
    got=$(verdict "$out")
    if [ "$got" = "$want" ]; then ok "$h: $name"; else bad "$h: $name (want $want, got $got)"; fi
  done < "$f"
  [ "$n" -gt 0 ] || bad "$h: no cases"; }
hooks() { for f in "$CASES"/*.tsv; do basename "$f" .tsv; done; }
if [ "$LIST" = 1 ]; then for h in $(hooks); do echo "$h $(grep -c . "$CASES/$h.tsv")"; done; exit 0; fi
if [ -n "$ONLY" ] && [ ! -f "$CASES/$ONLY.tsv" ]; then echo "unknown hook: $ONLY (see --list)" >&2; exit 2; fi
for h in $(hooks); do [ -n "$ONLY" ] && [ "$ONLY" != "$h" ] && continue; run_hook "$h"; done

contract() {
  local f m n
  model_of() { awk '/^---$/{c++;next} c==1 && /^model:/{print $2; exit}' "$1"; }
  for f in "$ROOT"/agents/*.md "$ROOT"/commands/*.md; do
    m=$(model_of "$f"); n=$(basename "$(dirname "$f")")/$(basename "$f" .md)
    case "$m" in haiku|sonnet|opus) ok "contract: $n model=$m" ;; *) bad "contract: $n has no valid model ('$m')" ;; esac
  done
  # every hook command in settings.fragment.json points to an existing, executable script under bin/
  local scripts; scripts=$(jq -r '.. | .command? // empty' "$ROOT/config/settings.fragment.json" 2>/dev/null | rg -o 'kit/bin/[A-Za-z0-9_.-]+' | sort -u)
  [ -n "$scripts" ] || bad "contract: no hook scripts found in config/settings.fragment.json"
  [ -s "$ROOT/plugins.txt" ] || bad "contract: plugins.txt missing or empty"
  for s in $scripts; do
    if [ -x "$ROOT/bin/${s#kit/bin/}" ]; then ok "contract: hook script ${s#kit/bin/} exists"; else bad "contract: settings references missing or non-executable ${s}"; fi
  done
  # plugins@marketplace must be declared in marketplaces.txt
  while read -r p; do
    case "$p" in ''|'#'*) continue ;; esac
    mk="${p#*@}"
    awk -v m="$mk" '$1==m{f=1} END{exit !f}' "$ROOT/marketplaces.txt" && ok "contract: marketplace $mk declared" || bad "contract: plugin $p uses undeclared marketplace $mk"
  done < "$ROOT/plugins.txt"
  # ODD flow: task documents live in docs/tasks, and the harness output is the evidence
  for f in plan implementar; do
    if rg -q 'docs/tasks' "$ROOT/commands/$f.md" 2>/dev/null && rg -q 'scripts/verify\.sh' "$ROOT/commands/$f.md"; then ok "contract: $f uses docs/tasks and verify.sh"
    else bad "contract: commands/$f must reference docs/tasks and scripts/verify.sh"; fi
  done
  # the developer decides when to push: /implementar commits per task group and must say it never pushes
  if rg -q 'Nunca `git push`' "$ROOT/commands/implementar.md" 2>/dev/null; then ok "contract: implementar never pushes"; else bad "contract: commands/implementar must forbid git push"; fi
  for f in bin/compact-handoff.sh templates/go-vue/CLAUDE.md commands/revisar.md; do
    if rg -q 'docs/tasks' "$ROOT/$f" 2>/dev/null; then ok "contract: $f knows docs/tasks"; else bad "contract: $f must reference docs/tasks"; fi
  done
  rg -q 'docs/plans' "$ROOT"/commands/{plan,implementar,revisar}.md 2>/dev/null
  case $? in 1) ok "contract: task commands do not use docs/plans" ;; 0) bad "contract: docs/plans is only for the /nuevo-proyecto roadmap" ;; *) bad "contract: could not scan task commands" ;; esac
  # stale compaction thresholds must not come back
  # rg exits 1 for "no match" and 2 for an error (e.g. a missing path): only 1 is a pass
  rg -q '25 ?%' "$ROOT/CLAUDE.md" "$ROOT/tools.md" "$ROOT/commands" "$ROOT/agents" 2>/dev/null
  case $? in 1) ok "contract: no stale 25% threshold" ;; 0) bad "contract: stale '25%' threshold in docs" ;; *) bad "contract: could not scan docs for stale thresholds" ;; esac
}
[ "$CONTRACT" = 1 ] && [ -z "$ONLY" ] && contract
[ "$total" -gt 0 ] || { echo "harness: no checks ran" >&2; exit 1; }
echo "harness: $total checks, $([ $fail = 0 ] && echo PASS || echo FAIL)"
exit $fail
