#!/usr/bin/env bash
set -u
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$dir"/test-*.sh; do
  echo "== $(basename "$t")"
  bash "$t" || rc=1
done
[ "$rc" -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $rc
