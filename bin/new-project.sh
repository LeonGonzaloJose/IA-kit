#!/usr/bin/env bash
# Generates a Go + Vue + Postgres project from the kit templates. Files only: no git init, no installs, no builds
# (the docs vendor step downloads the Scalar JS unless --no-vendor). JSON summary on stdout, progress on stderr.
#
#   new-project.sh <kebab-name> [--dir PATH] [--module GO/MODULE] [--port N] [--title TEXT]
#                  [--services postgres,redis,elasticsearch,floci] [--no-front|--no-back] [--no-vendor] [--dry-run]
# Exit codes: 0 ok, 2 usage/validation, 3 target not empty, 4 template missing, 5 missing dependency.
set -eu
KIT="${KIT_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
die() { echo "error: $1" >&2; exit "${2:-2}"; }
log() { echo "• $1" >&2; }

name="${1:-}"; [ -n "$name" ] || die "usage: new-project.sh <kebab-name> [options]"; shift
dir="" module="" port="8080" title="" services="postgres" front=1 back=1 vendor=1 dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2:-}"; shift ;;
    --module) module="${2:-}"; shift ;;
    --port) port="${2:-}"; shift ;;
    --title) title="${2:-}"; shift ;;
    --services) services="${2:-}"; shift ;;
    --no-front) front=0 ;;
    --no-back) back=0 ;;
    --no-vendor) vendor=0 ;;
    --dry-run) dry=1 ;;
    *) die "unknown option: $1" ;;
  esac; shift
done

[[ "$name" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] || die "name must be kebab-case, e.g. my-app"
[[ "$port" =~ ^[0-9]{2,5}$ ]] && [ "$port" -le 65535 ] || die "invalid port: $port"
[ -n "$module" ] || module="example.com/$name"
[[ "$module" =~ ^[A-Za-z0-9._~/-]+$ ]] || die "invalid go module path: $module"
[ -n "$title" ] || title="$name"
[[ "$title" =~ ^[A-Za-z0-9\ áéíóúÁÉÍÓÚñÑ._-]{1,60}$ ]] || die "invalid title"
[ "$front" -eq 1 ] || [ "$back" -eq 1 ] || die "--no-front and --no-back together leave nothing to generate"
IFS=',' read -ra SVC <<< "$services"
for s in "${SVC[@]}"; do
  case "$s" in postgres|redis|elasticsearch|floci) [ -f "$KIT/services/$s.compose.yml" ] || die "service file missing: $s" 4 ;; *) die "unknown service: $s (postgres|redis|elasticsearch|floci)" ;; esac
done
T="$KIT/templates/go-vue"; D="$KIT/templates/go-docs"
[ -d "$T" ] && [ -d "$D" ] || die "templates missing under $KIT/templates" 4
python3 -c "import yaml" 2>/dev/null || die "python3 with PyYAML is required to compose docker-compose.yml" 5
target="${dir:-$PWD/$name}"
if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then die "target directory is not empty: $target" 3; fi

if [ "$dry" -eq 1 ]; then
  log "dry-run: would create $target (back=$back front=$front services=$services module=$module port=$port)"
  printf '{"dry_run":true,"target":"%s","backend":%s,"frontend":%s,"services":"%s"}\n' "$target" "$([ $back -eq 1 ] && echo true || echo false)" "$([ $front -eq 1 ] && echo true || echo false)" "$services"
  exit 0
fi

mkdir -p "$target"
copy() { # copy <src dir> <dst dir>
  (cd "$1" && find . -type f) | while read -r f; do
    mkdir -p "$2/$(dirname "$f")"; cp "$1/$f" "$2/$f"
  done
}
sub() { # substitute placeholders in text files under $1
  find "$1" -type f \( -name '*.go' -o -name '*.mod' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.md' -o -name '*.ts' -o -name '*.vue' -o -name '*.html' -o -name 'Makefile' -o -name 'Dockerfile' -o -name '.gitignore' \) -print0 |
    xargs -0 sed -i -e "s#__MODULE__#$module#g" -e "s#__NAME__#$name#g" -e "s#__TITLE__#$title#g" -e "s#__PORT__#$port#g"
}

log "root files"
for f in .gitignore README.md CLAUDE.md; do cp "$T/$f" "$target/$f"; done
mkdir -p "$target/docs/plans"

if [ "$back" -eq 1 ]; then
  log "backend"; copy "$T/backend" "$target/backend"
  log "api manual (Scalar)"; copy "$D" "$target/backend/internal/docs"; rm -f "$target/backend/internal/docs/README.md"
  scalar=placeholder
  if [ "$vendor" -eq 1 ]; then
    if (cd "$target/backend/internal/docs" && ./vendor.sh >&2); then scalar=vendored
    else log "WARNING: Scalar download or integrity check failed (see above); wrote a placeholder. Run backend/internal/docs/vendor.sh with network access."; fi
  fi
  [ "$scalar" = vendored ] || echo "// PLACEHOLDER: run ./vendor.sh" > "$target/backend/internal/docs/scalar.standalone.js"
fi
if [ "$front" -eq 1 ]; then log "frontend"; copy "$T/frontend" "$target/frontend"; fi
sub "$target"

log "docker-compose.yml + .env.example ($services)"
python3 - "$KIT" "$target" "$services" "$name" <<'PY'
import sys, yaml, os
kit, target, services, name = sys.argv[1:5]
merged = {"name": name, "services": {}, "volumes": {}}
env = ["APP_ENV=development", "PORT=" + os.environ.get("PORT", "8080")]
ENV = {
  "postgres": ["DATABASE_URL=postgres://app:app@localhost:5432/app?sslmode=disable"],
  "redis": ["REDIS_ADDR=localhost:6379"],
  "elasticsearch": ["ELASTICSEARCH_URL=http://localhost:9200"],
  "floci": ["AWS_ENDPOINT_URL=http://localhost:4566", "AWS_REGION=us-east-1", "AWS_ACCESS_KEY_ID=test", "AWS_SECRET_ACCESS_KEY=test"],
}
for s in services.split(","):
    data = yaml.safe_load(open(os.path.join(kit, "services", f"{s}.compose.yml")))
    merged["services"].update(data.get("services", {}))
    merged["volumes"].update(data.get("volumes") or {})
    env += ENV[s]
if not merged["volumes"]: del merged["volumes"]
open(os.path.join(target, "docker-compose.yml"), "w").write(
    "# Local infrastructure only. Generated from kit/services; the app runs on the host.\n" + yaml.safe_dump(merged, sort_keys=False))
open(os.path.join(target, ".env.example"), "w").write("\n".join(env) + "\n")
PY
files=$(find "$target" -type f | wc -l)
printf '{"target":"%s","files":%s,"module":"%s","services":"%s","backend":%s,"frontend":%s,"scalar":"%s"}\n' "$target" "$files" "$module" "$services" "$([ $back -eq 1 ] && echo true || echo false)" "$([ $front -eq 1 ] && echo true || echo false)" "${scalar:-skipped}"
