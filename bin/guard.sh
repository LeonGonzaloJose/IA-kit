#!/usr/bin/env bash
# PreToolUse (Bash|Edit|Write|MultiEdit): asks the developer before risky changes. Never blocks; fails open.
#   dependencies (go get / npm add / editing go.mod or package.json), applying/rolling back DB migrations,
#   editing an EXISTING migration, CI/CD files, destructive docker volume removal, go directive changes.
set -u
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
PY=$(for c in python3 python; do "$c" -c "import sys" >/dev/null 2>&1 && { echo "$c"; break; }; done)
[ -n "$PY" ] || exit 0

REASON=$(KIT_GUARD_INPUT="$INPUT" "$PY" -I - <<'PY'
import json, os, re, shlex
try: data = json.loads(os.environ.get("KIT_GUARD_INPUT", ""))
except ValueError: raise SystemExit
tool = data.get("tool_name", ""); args = data.get("tool_input") or {}
WRAPPERS = {"sudo","rtk","env","time","nice","command","builtin"}
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

def bash_reason(command):
    for segment in re.split(r"[;&|\n]+|\$\(|`|\(|\)", command):
        try: words = shlex.split(segment, posix=True)
        except ValueError: continue
        while words and (os.path.basename(words[0]) in WRAPPERS or ASSIGN.match(words[0])): words.pop(0)
        if not words: continue
        head, rest = os.path.basename(words[0]), words[1:]
        pos = [w for w in rest if not w.startswith("-")]
        if head == "go" and pos[:1] == ["get"]:
            return "Adding or upgrading a Go dependency (go get) needs your approval."
        if head == "go" and pos[:1] == ["install"] and any("@" in w for w in pos[1:]):
            return "go install of a remote module (pkg@version) fetches and runs third-party code. Needs your approval."
        if head == "go" and pos[:2] == ["mod", "edit"] and any(w.startswith("-require") or w.startswith("-replace") or w.startswith("-go=") for w in rest):
            return "Editing go.mod dependencies/version needs your approval."
        if head in ("npm","pnpm","yarn","bun"):
            verb = pos[:1]
            if (verb in (["install"],["i"],["add"]) and len(pos) > 1) or (head in ("yarn","pnpm","bun") and verb == ["add"]):
                return "Adding an npm package needs your approval."
        if head in ("goose","migrate","atlas","dbmate") and any(v in pos for v in ("up","down","reset","redo","drop","apply","rollback","fix","force","up-by-one","down-to","up-to")):
            return "Applying or rolling back database migrations needs your approval."
        if head == "make" and any(w.startswith("migrate-") for w in pos):
            return "make migrate-* applies or rolls back database migrations. Needs your approval."
        if (head == "docker-compose" or (head == "docker" and "compose" in pos)) and "down" in pos and any(w in ("-v","--volumes") for w in rest):
            return "docker compose down -v deletes the data volumes (Postgres/Redis/Elastic). Needs your approval."
        if head == "docker" and (pos[:2] in (["volume","rm"], ["volume","prune"]) or (pos[:2] == ["system","prune"] and "--volumes" in rest)):
            return "Removing or pruning Docker volumes deletes data. Needs your approval."
    return None

CI = re.compile(r"(^|/)(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.ya?ml|azure-pipelines[^/]*\.ya?ml|Jenkinsfile|\.circleci/config\.yml|bitbucket-pipelines\.yml)$")
GOMOD = re.compile(r"(^|/)go\.mod$")
PKG = re.compile(r"(^|/)package\.json$")
MIGR = re.compile(r"(^|/)(db/)?migrations/[^/]+\.sql$")
NPM_DEP = re.compile(r'"(?!(?:version|packageManager|node|npm)")(@?[A-Za-z0-9][\w.\-]*(/[\w.\-]+)?)"\s*:\s*"([~^>=<]*\d|workspace:|npm:|file:|git|latest)')

def edit_reason(args, tool):
    path = args.get("file_path", "") or ""
    texts = [args.get("new_string", ""), args.get("content", "")]
    texts += [e.get("new_string", "") for e in args.get("edits", []) if isinstance(e, dict)]
    texts = [t for t in texts if isinstance(t, str)]
    if CI.search(path): return "Editing CI/CD pipeline files needs your approval."
    if GOMOD.search(path) and any(re.search(r"^\s*(require|replace)\b|^\s*go\s+1\.|^\s*toolchain\b|^\s+\S+\s+v\d", t, re.M) for t in texts):
        return "Changing go.mod (dependencies or Go version) needs your approval."
    if PKG.search(path) and any(NPM_DEP.search(t) for t in texts):
        return "Adding an npm dependency by editing package.json needs your approval."
    if MIGR.search(path) and tool in ("Edit","MultiEdit"):
        return "Editing an EXISTING migration is unsafe if it was already applied: create a new migration instead. Needs your approval."
    return None

reason = None
if tool == "Bash": reason = bash_reason(args.get("command", "") or "")
elif tool in ("Edit","Write","MultiEdit"): reason = edit_reason(args, tool)
if reason: print(reason)
PY
)
[ -n "$REASON" ] || exit 0
jq -nc --arg reason "$REASON" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
exit 0
