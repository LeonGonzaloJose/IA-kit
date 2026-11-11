#!/usr/bin/env bash
# Diagnóstico del kit. Salida: una línea por chequeo (ok/WARN/FAIL). Exit 1 si hay FAIL.
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
KIT="$(dirname "$(dirname "$(readlink -f "$0")")")"
fails=0; warns=0
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
ok()   { [ "$QUIET" -eq 1 ] || printf '  ok    %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; warns=$((warns+1)); }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
sec()  { [ "$QUIET" -eq 1 ] || printf '\n%s\n' "$1"; }
manifest() { grep -v '^\s*#' "$1" | sed '/^\s*$/d'; }

[ "$QUIET" -eq 1 ] || { echo "kit v$(cat "$KIT/VERSION" 2>/dev/null || echo '?')  ($KIT)"; echo "config: $DEST"; }

sec "Enlaces"
for f in CLAUDE.md tools.md RTK.md kit/root kit/bin kit/services; do
  if [ -L "$DEST/$f" ] && [ -e "$DEST/$f" ]; then ok "$f"
  elif [ -L "$DEST/$f" ]; then fail "$f: enlace roto"
  else fail "$f: falta (ejecutar install.sh)"; fi
done
for d in commands agents skills; do
  for e in "$KIT/$d"/*; do [ -e "$e" ] || continue
    [ -L "$DEST/$d/$(basename "$e")" ] && [ -e "$DEST/$d/$(basename "$e")" ] || fail "$d/$(basename "$e"): sin enlazar"
  done
  broken=$(find "$DEST/$d" -xtype l 2>/dev/null | wc -l); [ "$broken" -gt 0 ] && warn "$d: $broken enlace(s) roto(s)"
done
[ "$fails" -eq 0 ] && ok "comandos, agentes y skills enlazados"

sec "settings.json"
S="$DEST/settings.json"
if [ -f "$S" ] && jq -e . "$S" >/dev/null 2>&1; then
  [ "$(jq -r '.autoCompactWindow // empty' "$S")" = "250000" ] && ok "auto-compact at 250k tokens" || warn "autoCompactWindow not 250000 (run install.sh)"
  jq -e '.env|has("CLAUDE_AUTOCOMPACT_PCT_OVERRIDE")' "$S" >/dev/null && warn "deprecated CLAUDE_AUTOCOMPACT_PCT_OVERRIDE still set (run install.sh)"
  hook() { jq -e --arg n "$1" '[.hooks[]?[]?.hooks[]?.command]|any(test($n))' "$S" >/dev/null; }
  for pair in "rtk hook:rtk" "env-guard:env-guard (secrets)" "kit/bin/guard.sh:guard (risky changes)" "post-edit:post-edit lint" \
              "context-threshold:context threshold" "study-keyword:study keyword" "precompact-snapshot:precompact snapshot" \
              "compact-handoff:compact handoff" "doctor-sessionstart:doctor at session start"; do
    hook "${pair%%:*}" && ok "hook ${pair#*:}" || fail "hook ${pair#*:} missing (run install.sh)"
  done
  jq -e '.statusLine.command|test("statusline.sh")' "$S" >/dev/null && ok "kit statusline" || warn "statusline is not the kit's"
  jq -e '.permissions.ask|index("Bash(git push*)")' "$S" >/dev/null && ok "git push asks" || warn "permissions.ask incomplete"
  jq -e '.permissions.deny|index("Read(**/.env)")' "$S" >/dev/null && ok "secret read deny rules" || warn "permissions.deny incomplete"
else fail "settings.json invalid or missing"; fi
command -v engram >/dev/null && ok "engram CLI (precompact snapshot)" || warn "engram CLI missing: precompact snapshot is a no-op"

sec "Plugins"
list="$(claude plugin list 2>/dev/null)"
for p in $(manifest "$KIT/plugins.txt"); do
  if echo "$list" | grep -q "❯ $p\$"; then
    echo "$list" | grep -A3 "❯ $p\$" | grep -q "enabled" && ok "$p" || warn "$p: instalado pero deshabilitado"
  else fail "$p: no instalado"; fi
done

sec "Herramientas"
for t in $(manifest "$KIT/cli-tools.txt"); do
  command -v "$t" >/dev/null && ok "$t" || warn "$t: falta (/setup-kit herramientas)"
done
case ":$PATH:" in *":$(go env GOPATH 2>/dev/null)/bin:"*) ok "GOPATH/bin en PATH";; *) warn "GOPATH/bin no está en PATH";; esac

sec "Docker y servicios"
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  ok "demonio docker activo"
  for p in 5432 6379 9200 4566; do
    ss -ltn 2>/dev/null | grep -q ":$p " && echo "        puerto $p en uso (ok si es el servicio del proyecto)"
  done
else warn "docker no disponible o demonio detenido"; fi

sec "Modo estudio"
list2="$(claude plugin list 2>/dev/null)"
echo "$list2" | grep -q "❯ vibe-wise@" && ok "vibe-wise instalado" || warn "vibe-wise no instalado"
command -v python3 >/dev/null && ok "python3 (requerido por vibe-wise)" || fail "python3 falta"
jq -e '.hooks.UserPromptSubmit[]?|select(.hooks[]?.command|test("study-keyword"))' "$S" >/dev/null 2>&1 && ok "palabra clave estudio:/trabajo:" || warn "hook de palabra clave ausente"
[ -d .vibe-wise ] && { git check-ignore -q .vibe-wise 2>/dev/null && ok ".vibe-wise ignorado por git" || warn ".vibe-wise/ no está en .gitignore"; }

sec "Plantillas y docs de API"
[ -f "$KIT/templates/go-docs/docs.go" ] && [ -x "$KIT/templates/go-docs/vendor.sh" ] && ok "plantilla go-docs (Scalar)" || fail "plantilla go-docs incompleta"
[ -f "$KIT/templates/go-docs/scalar.standalone.js" ] && warn "scalar.standalone.js (5 MB) no debe estar en el kit"
[ -f "$KIT/profiles/backend.txt" ] && [ -f "$KIT/profiles/front.txt" ] && ok "profiles backend/front" || fail "profile lists missing"
[ -f "$KIT/profiles/go.md" ] && [ -f "$KIT/profiles/vue.md" ] && [ -f "$KIT/profiles/postgres.md" ] && ok "stack rule profiles (go/vue/postgres)" || fail "stack profiles missing"
[ -x "$KIT/bin/new-project.sh" ] && [ -d "$KIT/templates/go-vue" ] && ok "project generator" || fail "project generator incomplete"
for a in review-risk review-resilience review-readability review-reliability auditor-seguridad; do [ -f "$KIT/agents/$a.md" ] || fail "agent $a missing"; done

sec "Proyecto actual ($(basename "$PWD"))"
[ -f go.mod ] && ok "Go detectado" ; [ -f package.json ] && ok "Node/Vue detectado"
[ -f api/openapi.yaml ] || [ -f backend/api/openapi.yaml ] && ok "contrato openapi.yaml" || echo "        (sin contrato OpenAPI en este directorio)"
rg -q 'swaggo|swagger-ui' go.mod backend/go.mod 2>/dev/null && warn "usa swaggo/swagger-ui: el kit usa Scalar por defecto"
[ -f .env ] && ! git check-ignore -q .env 2>/dev/null && fail ".env no está en .gitignore"

sec "Repo del kit"
if git -C "$KIT" rev-parse --git-dir >/dev/null 2>&1; then
  n=$(git -C "$KIT" status --porcelain | wc -l)
  git -C "$KIT" rev-parse HEAD >/dev/null 2>&1 || warn "repo sin commits"
  [ "$n" -gt 0 ] && echo "        $n cambio(s) sin commitear"
  git -C "$KIT" remote -v | grep -q . || warn "sin remoto (GitHub pendiente)"
else warn "el kit no es un repo git"; fi

printf '\nResultado: %d FAIL, %d WARN\n' "$fails" "$warns"
[ "$fails" -eq 0 ]
