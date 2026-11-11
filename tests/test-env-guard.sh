#!/usr/bin/env bash
set -u
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/env-guard.sh"
fail=0
run() { local name="$1" want="$2" json="$3" out
  out=$(printf '%s' "$json" | bash "$HOOK")
  if [ "$want" = deny ] && [[ "$out" == *'"permissionDecision":"deny"'* ]]; then echo "ok   $name"
  elif [ "$want" = allow ] && [ -z "$out" ]; then echo "ok   $name"
  else echo "FAIL $name: want $want got '$out'"; fail=1; fi; }
run "read .env"              deny  '{"tool_name":"Read","tool_input":{"file_path":"/repo/.env"}}'
run "read .env.production"   deny  '{"tool_name":"Read","tool_input":{"file_path":"/repo/.env.production"}}'
run "read .env.example"      allow '{"tool_name":"Read","tool_input":{"file_path":"/repo/.env.example"}}'
run "read credentials.json"  deny  '{"tool_name":"Read","tool_input":{"file_path":"/repo/credentials.json"}}'
run "read pem"               deny  '{"tool_name":"Read","tool_input":{"file_path":"/repo/certs/server.pem"}}'
run "read go source"         allow '{"tool_name":"Read","tool_input":{"file_path":"/repo/cmd/api/main.go"}}'
run "grep path .env"         deny  '{"tool_name":"Grep","tool_input":{"pattern":"PASSWORD","path":"/repo/.env"}}'
run "bash cat .env"          deny  '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}'
run "bash cat ssh key"       deny  '{"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_ed25519"}}'
run "bash cat aws creds"     deny  '{"tool_name":"Bash","tool_input":{"command":"cat ~/.aws/credentials"}}'
run "bash cat .env.example"  allow '{"tool_name":"Bash","tool_input":{"command":"cat .env.example"}}'
run "bash gitignore append"  allow '{"tool_name":"Bash","tool_input":{"command":"echo \".env\" >> .gitignore"}}'
run "bash go test"           allow '{"tool_name":"Bash","tool_input":{"command":"go test ./..."}}'
run "bash jq filter .env"    allow '{"tool_name":"Bash","tool_input":{"command":"jq -c \".env, .x\" settings.json"}}'
run "bash rtk cat .env.local" deny '{"tool_name":"Bash","tool_input":{"command":"rtk cat .env.local"}}'
run "bash pipeline cat .env" deny  '{"tool_name":"Bash","tool_input":{"command":"echo hi && cat ./backend/.env"}}'
run "bash cat quoted .env"   deny  '{"tool_name":"Bash","tool_input":{"command":"cat \".env.local\""}}'
# closed bypasses
run "bash /bin/cat .env"       deny  '{"tool_name":"Bash","tool_input":{"command":"/bin/cat .env"}}'
run "bash /usr/bin/cat .env"   deny  '{"tool_name":"Bash","tool_input":{"command":"/usr/bin/cat ./.env"}}'
run "bash xargs cat .env"      deny  '{"tool_name":"Bash","tool_input":{"command":"xargs -n1 cat .env"}}'
run "bash echo .env | xargs"   deny  '{"tool_name":"Bash","tool_input":{"command":"echo .env | xargs cat"}}'
run "bash git show HEAD:.env"  deny  '{"tool_name":"Bash","tool_input":{"command":"git show HEAD:.env"}}'
run "bash git cat-file .env"   deny  '{"tool_name":"Bash","tool_input":{"command":"git cat-file -p HEAD:backend/.env"}}'
run "bash git show example"    allow '{"tool_name":"Bash","tool_input":{"command":"git show HEAD:.env.example"}}'
run "bash git log"             allow '{"tool_name":"Bash","tool_input":{"command":"git log --oneline -5"}}'
run "bash python3 -c open .env" deny '{"tool_name":"Bash","tool_input":{"command":"python3 -c \"print(open(\u0027.env\u0027).read())\""}}'
run "bash node -e readFile"    deny  '{"tool_name":"Bash","tool_input":{"command":"node -e \"console.log(require(\u0027fs\u0027).readFileSync(\u0027.env.local\u0027,\u0027utf8\u0027))\""}}'
run "bash python3 -c harmless" allow '{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import os; print(os.environ.get(\u0027HOME\u0027), d.key)\""}}'
run "bash python3 -c example"  allow '{"tool_name":"Bash","tool_input":{"command":"python3 -c \"print(open(\u0027.env.example\u0027).read())\""}}'
run "bash cat glob .e*"        deny  '{"tool_name":"Bash","tool_input":{"command":"cat .e*"}}'
run "bash cat glob .en?"       deny  '{"tool_name":"Bash","tool_input":{"command":"cat .en?"}}'
run "bash cat glob .env*"      deny  '{"tool_name":"Bash","tool_input":{"command":"cat .env*"}}'
run "bash cat glob .env.ex*"   allow '{"tool_name":"Bash","tool_input":{"command":"cat .env.ex*"}}'
run "bash cat *.json"          allow '{"tool_name":"Bash","tool_input":{"command":"cat *.json"}}'
run "bash docker run env-file" deny  '{"tool_name":"Bash","tool_input":{"command":"docker run --rm --env-file .env alpine env"}}'
run "bash docker run env-file=" deny '{"tool_name":"Bash","tool_input":{"command":"docker run --env-file=./backend/.env.production alpine"}}'
run "bash docker run example"  allow '{"tool_name":"Bash","tool_input":{"command":"docker run --env-file .env.example alpine"}}'
run "bash docker compose up"   allow '{"tool_name":"Bash","tool_input":{"command":"docker compose --env-file .env up -d"}}'
# documented fail-open: the Bash path is best-effort (see header of env-guard.sh)
run "fail-open printenv"       allow '{"tool_name":"Bash","tool_input":{"command":"printenv"}}'
run "fail-open /proc environ"  allow '{"tool_name":"Bash","tool_input":{"command":"cat /proc/self/environ"}}'
run "fail-open redirection"    allow '{"tool_name":"Bash","tool_input":{"command":"while read -r l; do echo \"$l\"; done < .env"}}'
run "garbage fails open"     allow 'not json'
exit $fail
