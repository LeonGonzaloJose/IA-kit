#!/usr/bin/env bash
# PreToolUse (Read|Bash|Grep|Glob): blocks reading secret files. Fails open on anything it does not recognize.
#
# The Bash path is a BEST-EFFORT brake, not a security boundary: it only matches known reader commands and
# literal paths. It deliberately fails open on e.g. `printenv`, `cat /proc/self/environ`, redirections
# (`while read; do ...; done < .env`), scripts on disk, or any encoding it cannot see. The real limits are the
# settings.json deny rules for the Read/Edit tools and the developer's own review of commands.
set -u
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

SENSITIVE='(^|[/ "'"'"'=])(\.env(\.[A-Za-z0-9_.-]+)?|credentials\.(json|txt)|secrets\.json|[A-Za-z0-9_.-]+\.(pfx|p12|pem|key)|id_(rsa|ed25519|ecdsa)|\.ssh/[^ ]*|\.aws/credentials|\.npmrc|\.pgpass)($|[ "'"'"';&|)<>])'
SAFE='\.env\.(example|sample|template|dist)($|[ "'"'"';&|)<>])'

deny() {
  jq -nc --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}
is_sensitive() {
  local text="$1"
  printf '%s' "$text" | grep -qE "$SAFE" && text=$(printf '%s' "$text" | sed -E "s/$SAFE//g")
  printf '%s' "$text" | grep -qE "$SENSITIVE"
}

case "$TOOL" in
  Read|Grep|Glob)
    for field in file_path path pattern glob; do
      value=$(printf '%s' "$INPUT" | jq -r --arg f "$field" '.tool_input[$f] // empty')
      [ -n "$value" ] || continue
      is_sensitive "$value" && deny "Blocked by env-guard: '$value' looks like a secrets file. Use the .env.example template or ask the user for the specific non-secret value."
    done ;;
  Bash)
    cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
    [ -n "$cmd" ] || exit 0
    PY=$(for c in python3 python; do "$c" -c "import sys" >/dev/null 2>&1 && { echo "$c"; break; }; done)
    [ -n "$PY" ] || exit 0
    hit=$(KIT_GUARD_CMD="$cmd" "$PY" -I - <<'PY'
import fnmatch, os, re, shlex
READERS = {"cat","less","more","head","tail","grep","egrep","rg","sed","awk","bat","source",".","cp","mv","xxd","strings",
           "base64","openssl","nl","tac","cut","sort","diff","jq","yq","scp"}
WRAPPERS = {"sudo","rtk","env","time","nice","command","builtin","xargs","nohup","timeout"}
INLINE = {"python","python3","node","ruby","perl"}  # interpreters whose -c/-e/-p argument is code we can scan
SAFE_ENV = re.compile(r"\.env\.(example|sample|template|dist)$")
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
GLOB = re.compile(r"[*?\[]")
SECRET_NAMES = [".env", ".env.local", ".env.production", "credentials.json", "secrets.json", "id_rsa", "id_ed25519", ".npmrc", ".pgpass"]
NAMES = re.compile(r"credentials\.(json|txt)|secrets\.json|id_(rsa|ed25519|ecdsa)|\.npmrc|\.pgpass")
EXT = re.compile(r".+\.(pfx|p12|pem|key)")
def sensitive(token, by_ext=True):
    path = os.path.expanduser(token)
    base = os.path.basename(path.rstrip("/"))
    if "/.ssh/" in path or path.startswith(".ssh/") or path.endswith("/.ssh"): return True
    if path.endswith("/.aws/credentials"): return True
    if base.startswith(".") and GLOB.search(base):  # a dotfile glob that could expand to a secret (.e*, .en?, .env*)
        return any(fnmatch.fnmatch(n, base) for n in SECRET_NAMES)
    if re.fullmatch(r"\.env(\.[\w.-]+)?", base): return not SAFE_ENV.search(base)
    if NAMES.fullmatch(base): return True
    return by_ext and bool(EXT.fullmatch(base))
def strip_wrappers(words):
    via_xargs = False
    while words and (os.path.basename(words[0]) in WRAPPERS or ASSIGN.match(words[0])):
        via_xargs |= os.path.basename(words[0]) == "xargs"
        words.pop(0)
        while words and words[0].startswith("-"): words.pop(0)
    return words, via_xargs
command = os.environ.get("KIT_GUARD_CMD", "")
segments = []
# coarse split keeps quoted inline code intact; the fine split also looks inside $(...), backticks and parentheses
for pattern in (r"[;&|\n]+", r"[;&|\n]+|\$\(|`|\(|\)"):
    for segment in re.split(pattern, command):
        try: segments.append(shlex.split(segment, posix=True))
        except ValueError: continue
all_words = [w for s in segments for w in s]
def hit(): print("hit"); raise SystemExit
for words in segments:
    words, via_xargs = strip_wrappers(list(words))
    if not words: continue
    head, rest = os.path.basename(words[0]), words[1:]
    if head in READERS:
        if any(not w.startswith("-") and sensitive(w) for w in rest): hit()
        if via_xargs and any(sensitive(w) for w in all_words): hit()  # `echo .env | xargs cat`
    elif head == "git" and rest[:1] and rest[0] in ("show", "cat-file", "diff"):
        if any(sensitive(w.split(":")[-1]) for w in rest[1:] if not w.startswith("-")): hit()  # HEAD:.env
    elif head in INLINE and any(w in ("-c", "-e", "-p") for w in rest):
        code = " ".join(w for w in rest if not w.startswith("-"))
        if any(sensitive(t, by_ext=False) for t in re.findall(r"[\w./~*?-]+", code)): hit()
    elif head == "docker" and rest[:1] and rest[0] in ("run", "create"):
        for i, w in enumerate(rest):
            f = w.split("=", 1)[1] if w.startswith("--env-file=") else (rest[i + 1] if w == "--env-file" and i + 1 < len(rest) else "")
            if f and sensitive(f): hit()
PY
)
    [ "$hit" = "hit" ] && deny "Blocked by env-guard: this command reads a secrets file (.env*, credentials, keys). Ask the user for the specific non-secret value instead." ;;
esac
exit 0
