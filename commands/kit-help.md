---
description: Explica el kit: qué incluye, cuándo usar cada cosa y cómo configurarlo
argument-hint: "[comandos | plugins | perfiles | flujo | modelos | arnes | ahorro | <nombre>]"
model: haiku
---
Explicar el kit al desarrollador. Leer solo lo necesario desde `${CLAUDE_CONFIG_DIR:-~/.claude}/kit/root` (`VERSION`, `tools.md`, `plugins.txt`, `profiles/*.txt`, `commands/*.md` leyendo únicamente el front-matter). Tema pedido: "$ARGUMENTS" (vacío = visión general). No inventar: si algo no está en esos archivos, decirlo.

## Visión general (sin argumento), máx. ~25 líneas
1. Qué es: kit personal para trabajar Go + Vue + Postgres en Docker, con poco gasto de tokens y código limpio. Versión `VERSION`.
2. **Flujo recomendado**: `/plan` → OK → `/implementar` → `/revisar` (lentes por riesgo) → `/commit` (commit-commands); `/code-review` para PRs; `/auditar` antes de publicar. Cambios triviales se hacen directo.
3. Tabla de comandos del kit con una línea cada uno (leer sus `description`): `/setup-kit`, `/kit-doctor`, `/estudio`, `/revisar`, `/nuevo-proyecto`, `/plan`, `/implementar`, `/auditar`, `/kit-help`.
4. Plugins activos y para qué sirven (de `tools.md`), en una línea cada uno.
5. Perfiles: `backend` (Go) y `front` (Vue); se instalan por proyecto con `/setup-kit perfiles`.
6. Ahorro de tokens: auto-compact a 250k tokens (guardado en engram a 200k), `rtk`, subagentes de solo lectura, engram.
7. Cierre: "Pedime `/kit-help <tema>` para el detalle".

## Con argumento
- `comandos`: cada comando con descripción, argumentos y un ejemplo.
- `plugins`: cada plugin, cuándo se invoca solo y cuándo conviene pedirlo.
- `perfiles`: qué trae cada uno y cómo activarlo.
- `flujo`: el ciclo plan → implementar → revisar → auditar → commit, con cuándo saltarlo (cambios triviales).
- `modelos`: tabla de qué modelo (haiku/sonnet/opus) se usa en cada tarea, leída de la sección "Models per task" de `tools.md`, y cómo escalar o cambiar con `/model`.
- `arnes`: el arnés del kit (`bash tests/harness.sh`: casos de hooks en `tests/cases/*.tsv` + chequeos de contrato) y el de integración que genera cada proyecto con Postgres (`make test-integration`, `docs/HARNESS.md`); leer `docs/plans/arnes.md`.
- `ahorro`: cómo funcionan los umbrales (guardar en engram a 200k tokens, auto-compact a 250k), qué se guarda en engram antes de compactar y cómo retomar.
- `<nombre>` de un comando o plugin: explicarlo en detalle leyendo su archivo.
Si algo no funciona, sugerir `/kit-doctor`. Si el usuario parece perdido, sugerir `/setup-kit estado`.
