#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
model_of() { awk '/^---$/{n++;next} n==1 && /^model:/{print $2; exit}' "$1"; }
for f in "$ROOT"/agents/*.md "$ROOT"/commands/*.md; do
  m="$(model_of "$f")"; n="$(basename "$f" .md)"
  case "$m" in haiku|sonnet|opus) ok "$n -> $m" ;; *) bad "$n has no valid model ('$m')" ;; esac
done
want() { [ "$(model_of "$ROOT/$1.md")" = "$2" ] && ok "policy: $1 = $2" || bad "policy: $1 should be $2"; }
want commands/nuevo-proyecto opus; want commands/plan opus
want commands/kit-help haiku; want commands/kit-doctor haiku; want agents/review-readability haiku
want commands/implementar sonnet; want agents/auditor-seguridad sonnet; want agents/review-risk sonnet
rg -q 'Models per task' "$ROOT/tools.md" && ok "tools.md documents the table" || bad "tools.md table missing"
exit $fail
