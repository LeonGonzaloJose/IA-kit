#!/usr/bin/env bash
# Negative controls: the harness must FAIL, and for the right reason, when a hook or the contract is broken.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$ROOT/tests/harness.sh"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# expect_failure <name> <text expected in the output> <harness args...>: the run must fail AND print that text
expect_failure() { local name="$1" text="$2" out; shift 2
  if out=$(bash "$@" 2>&1); then bad "$name: went undetected"
  elif [[ "$out" == *"$text"* ]]; then ok "$name"
  else bad "$name: failed for another reason: $(tail -n 1 <<<"$out")"; fi; }
fake_hooks() { mkdir -p "$T/bin"; for h in guard env-guard; do printf '%s\n' "$1" > "$T/bin/$h.sh"; done; }

bash "$H" >/dev/null && ok "harness passes on the real kit" || bad "harness fails on the real kit"
counts="$(bash "$H" --list)"
[ "$(awk '$1=="env-guard"{print $2}' <<<"$counts")" -ge 42 ] && [ "$(awk '$1=="guard"{print $2}' <<<"$counts")" -ge 33 ] && ok "case counts did not shrink" || bad "case counts shrank: $counts"

fake_hooks 'exit 0';                                        expect_failure "always-allow hook" "want deny, got allow" "$H" --bin "$T/bin" --no-contract
fake_hooks 'printf "{\"permissionDecision\":\"deny\"}"';    expect_failure "always-deny hook" "want allow, got deny" "$H" --bin "$T/bin" --no-contract
fake_hooks 'printf "{\"permissionDecision\":\"ask\"}"';     expect_failure "always-ask hook" "want allow, got ask" "$H" --bin "$T/bin" --no-contract
fake_hooks 'exit 1';                                        expect_failure "crashing hook" "hook exited non-zero" "$H" --bin "$T/bin" --no-contract
rm -rf "$T/bin"; mkdir "$T/bin";                            expect_failure "missing hook script" "hook script missing" "$H" --bin "$T/bin" --no-contract
expect_failure "unknown --hook" "unknown hook" "$H" --hook nope

copy_kit() { rm -rf "$T/kit"; mkdir "$T/kit"; cp -r "$ROOT"/{agents,commands,config,bin,tests,plugins.txt,marketplaces.txt,CLAUDE.md,tools.md} "$T/kit/"; }
copy_kit; echo "ghost@nowhere" >> "$T/kit/plugins.txt"
expect_failure "undeclared marketplace" "plugin ghost@nowhere uses undeclared marketplace" "$T/kit/tests/harness.sh"
copy_kit; sed -i '0,/^model:.*/s//model: gpt/' "$T/kit/commands/plan.md"
expect_failure "invalid model" "commands/plan has no valid model" "$T/kit/tests/harness.sh"
copy_kit; chmod -x "$T/kit/bin/guard.sh"
expect_failure "non-executable hook" "missing or non-executable kit/bin/guard.sh" "$T/kit/tests/harness.sh"
copy_kit; echo "compact at 25%" >> "$T/kit/tools.md"
expect_failure "stale 25% threshold" "stale '25%' threshold" "$T/kit/tests/harness.sh"
copy_kit; : > "$T/kit/tests/cases/guard.tsv"
expect_failure "empty cases file" "guard: no cases" "$T/kit/tests/harness.sh"
copy_kit; rm "$T/kit/bin/guard.sh"
expect_failure "hook script deleted" "hook script missing" "$T/kit/tests/harness.sh"
copy_kit; rm "$T/kit/config/settings.fragment.json"
expect_failure "settings fragment missing" "no hook scripts found" "$T/kit/tests/harness.sh"
copy_kit; rm -r "$T/kit/agents"
expect_failure "docs path missing" "could not scan docs" "$T/kit/tests/harness.sh"
copy_kit; printf 'bad tool\tallow\tNope\tx\t\n' >> "$T/kit/tests/cases/guard.tsv"
expect_failure "unknown tool in a case" "unknown tool 'Nope'" "$T/kit/tests/harness.sh"
exit $fail
