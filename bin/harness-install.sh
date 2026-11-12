#!/usr/bin/env bash
# Installs or updates the project harness in any project, new or existing:
#   scripts/verify.sh (+ root Makefile aliases), docs/HARNESS.md and, when the project has Go + Postgres
#   migrations, the integration harness (scripts/test-integration.sh, internal/testutil, harness.mk).
#
#   harness-install.sh <project-dir> [--dry-run]
# It never overwrites a file it does not manage: managed files carry the marker in their first lines.
# JSON summary on stdout, progress on stderr. Exit codes: 0 ok, 2 usage, 4 template missing, 5 missing dependency.
set -eu
KIT="${KIT_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
TPL="$KIT/templates/harness"
MARKER="kit-harness: managed file"
PGX_REQUIRE="github.com/jackc/pgx/v5 v5.13.0"
VERIFY_LINE='- Verify (evidence of done): `bash scripts/verify.sh` (fast, no Docker) · `bash scripts/verify.sh --full` (adds Postgres integration). See `docs/HARNESS.md`.'
die() { echo "error: $1" >&2; exit "${2:-2}"; }
log() { echo "• $1" >&2; }

# before any write: without jq the summary would fail after a complete install
command -v jq >/dev/null || die "jq not found" 5
target="${1:-}"; [ -n "$target" ] || die "usage: harness-install.sh <project-dir> [--dry-run]"; shift
dry=0
while [ $# -gt 0 ]; do case "$1" in --dry-run) dry=1 ;; *) die "unknown option: $1" ;; esac; shift; done
[ -d "$target" ] || die "not a directory: $target"
[ -d "$TPL" ] || die "templates missing: $TPL" 4
target="$(cd "$target" && pwd -P)"

installed=(); updated=(); kept=(); notes=()
contains() { local wanted="$1" item; shift; for item in "$@"; do [ "$item" = "$wanted" ] && return 0; done; return 1; }
will_install() { contains "$1" ${installed[@]+"${installed[@]}"}; }

inside_project() { # the nearest existing ancestor of <path> must resolve inside the project (no symlink leading out)
  local dir; dir="$(dirname "$1")"
  while [ ! -d "$dir" ]; do dir="$(dirname "$dir")"; done
  case "$(cd "$dir" && pwd -P)/" in "$target"/*) return 0 ;; *) return 1 ;; esac
}
put() { # put <template file> <path relative to the project> [once]: "once" files belong to the project after the first copy
  local src="$1" rel="$2" dst="$target/$2"
  if [ -L "$dst" ] || ! inside_project "$dst"; then
    kept+=("$rel"); notes+=("$rel is a symlink or sits behind one: not touched"); return 0
  fi
  if [ ! -e "$dst" ]; then installed+=("$rel")
  elif cmp -s "$src" "$dst" || [ "${3:-}" = once ]; then return 0
  # first lines only: a project file that merely mentions the marker further down is not ours
  elif head -n 3 "$dst" | grep -qF -- "$MARKER"; then updated+=("$rel")
  else kept+=("$rel"); return 0; fi
  [ "$dry" -eq 0 ] || return 0
  mkdir -p "$(dirname "$dst")"
  # temp file + mv: an interrupted copy must not leave a truncated file that lost its marker
  cp "$src" "$dst.kit-tmp.$$"
  if [ -x "$src" ]; then chmod +x "$dst.kit-tmp.$$"; fi
  mv -f "$dst.kit-tmp.$$" "$dst"
}
ensure_line() { # ensure_line <relative file> <ERE that proves it is there> <line to append>; 1 = the file does not exist
  local rel="$1" dst="$target/$1"
  if [ ! -f "$dst" ]; then will_install "$rel"; return; fi
  if grep -Eq -- "$2" "$dst"; then return 0; fi
  updated+=("$rel")
  [ "$dry" -eq 1 ] || printf '\n%s\n' "$3" >> "$dst"
}
rel_dir_of_first() { local f; for f in "$@"; do if [ -f "$target/$f" ]; then dirname "$f"; return; fi; done; }
in_dir() { local p="$1/$2"; echo "${p#./}"; } # in_dir <dir> <path>: project-relative path, without the "./" of a root module
json_list() { if [ $# -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -R . | jq -sc .; fi; }

go_dir="$(rel_dir_of_first backend/go.mod go.mod)"
front_dir=""
if [ -f "$target/frontend/package.json" ]; then front_dir=frontend
# a root package.json is often tooling only (husky, commitlint): it is the front only when it depends on vue
elif [ -f "$target/package.json" ] && grep -q '"vue"' "$target/package.json"; then front_dir=.
elif [ -f "$target/package.json" ]; then notes+=("root package.json does not depend on vue: not treated as a front"); fi
[ -n "$go_dir$front_dir" ] || die "no go.mod or Vue package.json under $target: nothing to verify"

modules="$(find "$target" -maxdepth 4 -name go.mod -not -path '*/node_modules/*' -not -path '*/vendor/*' | wc -l)"
if [ "$modules" -gt 1 ] || [ -f "$target/go.work" ]; then
  notes+=("several Go modules or a go.work found: verify.sh only checks ${go_dir:-none of them}")
fi

compose=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  # comments dropped first; the image name must end there, so postgres-exporter or postgrest do not count
  if [ -f "$target/$f" ] && grep -Ev '^[[:space:]]*#' "$target/$f" |
      grep -Eq "image:[[:space:]]*[\"']?([a-z0-9._-]+/)*(postgres|postgresql|postgis)([:\"'[:space:]]|\$)"; then compose="$f"; break; fi
done
postgres=false
if [ -n "$go_dir" ] && [ -n "$compose" ] && [ -d "$target/$(in_dir "$go_dir" db/migrations)" ]; then postgres=true; fi

log "verification entry point (scripts/verify.sh)"
put "$TPL/scripts/verify.sh" scripts/verify.sh
put "$TPL/docs/HARNESS.md" docs/HARNESS.md
put "$TPL/Makefile.root" Makefile once
if ! will_install Makefile && ! { grep -q '^verify:' "$target/Makefile" && grep -q '^verify-full:' "$target/Makefile"; } 2>/dev/null; then
  notes+=("root Makefile is the project's own: no make verify / verify-full aliases, use bash scripts/verify.sh")
fi

if [ "$postgres" = true ]; then
  log "integration harness ($(in_dir "$go_dir" scripts/test-integration.sh))"
  put "$TPL/backend/scripts/test-integration.sh" "$(in_dir "$go_dir" scripts/test-integration.sh)"
  put "$TPL/backend/harness.mk" "$(in_dir "$go_dir" harness.mk)"
  put "$TPL/backend/internal/testutil/db.go" "$(in_dir "$go_dir" internal/testutil/db.go)"
  put "$TPL/backend/internal/testutil/db_integration_test.go" "$(in_dir "$go_dir" internal/testutil/db_integration_test.go)"
  put "$TPL/backend/internal/testutil/fixtures/00_example.sql" "$(in_dir "$go_dir" internal/testutil/fixtures/00_example.sql)" once
  gomod="$(in_dir "$go_dir" go.mod)"
  ensure_line "$gomod" '^[[:space:]]*(require[[:space:]]+)?github\.com/jackc/pgx/v5[[:space:]]' "require $PGX_REQUIRE"
  if contains "$gomod" ${updated[@]+"${updated[@]}"}; then
    notes+=("$gomod: pgx added; the first integration run executes go mod tidy, commit go.mod and go.sum after it")
  fi
  ensure_line "$(in_dir "$go_dir" Makefile)" '^-?include[[:space:]]+harness\.mk' "include harness.mk" ||
    notes+=("no Makefile in ${go_dir}: run the integration harness with bash $(in_dir "$go_dir" scripts/test-integration.sh)")
  grep -Eq '^[[:space:]]+postgres:[[:space:]]*$' "$target/$compose" ||
    notes+=("no compose service named postgres in ${compose}: set HARNESS_PG_SERVICE")
  notes+=("integration defaults to postgres://app:app@localhost:5432: set HARNESS_PG_URL for other development credentials")
elif [ -n "$go_dir" ]; then
  notes+=("integration harness skipped: needs a compose file with a postgres image and $(in_dir "$go_dir" db/migrations)")
fi

ensure_line CLAUDE.md 'scripts/verify\.sh' "$VERIFY_LINE" ||
  notes+=("no CLAUDE.md: declare scripts/verify.sh as the verification command there")

jq -nc --arg target "$target" --arg go_dir "$go_dir" --arg front_dir "$front_dir" --argjson postgres "$postgres" --argjson dry "$dry" \
  --argjson installed "$(json_list ${installed[@]+"${installed[@]}"})" --argjson updated "$(json_list ${updated[@]+"${updated[@]}"})" \
  --argjson kept "$(json_list ${kept[@]+"${kept[@]}"})" --argjson notes "$(json_list ${notes[@]+"${notes[@]}"})" \
  '{target: $target, go_dir: $go_dir, front_dir: $front_dir, postgres: $postgres, dry_run: ($dry == 1), installed: $installed, updated: $updated, kept: $kept, notes: $notes}'
