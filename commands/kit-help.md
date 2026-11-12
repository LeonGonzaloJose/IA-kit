---
description: Explica el kit: qué incluye, cuándo usar cada cosa y cómo configurarlo
argument-hint: "[comandos | plugins | perfiles | flujo | odd | modelos | arnes | ahorro | <nombre>]"
model: haiku
---
Explicar el kit al desarrollador. Leer solo lo necesario desde `${CLAUDE_CONFIG_DIR:-~/.claude}/kit/root` (`VERSION`, `tools.md`, `plugins.txt`, `profiles/*.txt`, `commands/*.md` leyendo únicamente el front-matter). Tema pedido: "$ARGUMENTS" (vacío = visión general). No inventar: si algo no está en esos archivos, decirlo.

## Visión general (sin argumento), máx. ~25 líneas
1. Qué es: kit personal para trabajar Go + Vue + Postgres en Docker, con poco gasto de tokens y código limpio. Versión `VERSION`.
2. **Flujo recomendado (ODD)**: tarea chica → directo, sin documento. Tarea grande → `/plan` (documento vivo en `docs/tasks/`) → OK → `/implementar` (tarea por tarea, con evidencia de `scripts/verify.sh`) → `/revisar` (lentes por riesgo) → `/commit` (commit-commands); `/code-review` para PRs; `/auditar` antes de publicar.
3. Tabla de comandos del kit con una línea cada uno (leer sus `description`): `/setup-kit`, `/kit-doctor`, `/estudio`, `/revisar`, `/nuevo-proyecto`, `/arnes`, `/plan`, `/implementar`, `/auditar`, `/kit-help`.
4. Plugins activos y para qué sirven (de `tools.md`), en una línea cada uno.
5. Perfiles: `backend` (Go) y `front` (Vue); se instalan por proyecto con `/setup-kit perfiles`.
6. Ahorro de tokens: auto-compact a 250k tokens (guardado en engram a 200k), `rtk`, subagentes de solo lectura, engram.
7. Cierre: "Pedime `/kit-help <tema>` para el detalle".

## Con argumento
- `comandos`: cada comando con descripción, argumentos y un ejemplo.
- `plugins`: cada plugin, cuándo se invoca solo y cuándo conviene pedirlo.
- `perfiles`: qué trae cada uno y cómo activarlo.
- `flujo` / `odd`: Organic Driven Development — la ceremonia crece con la tarea (comprensión, riesgo, retomabilidad), no con las líneas. Protocolo de `CLAUDE.md`: explorar → resolver dudas → clasificar (chica / grande / siempre grande) → registrar antes de la primera escritura (`docs/tasks/<feature>.md` + Engram `tasks/<feature>`) → implementar tarea por tarea → cerrar con evidencia (`scripts/verify.sh`). Explicar qué hace cada comando en ese ciclo (`/plan`, `/implementar`, `/revisar`, `/arnes`) y los límites conocidos: el agente clasifica el riesgo (por eso las áreas siempre grandes son fijas y `/revisar` usa lentes independientes) y un verify verde no prueba lo que no tiene test.
- `modelos`: tabla de qué modelo (haiku/sonnet/opus) se usa en cada tarea, leída de la sección "Models per task" de `tools.md`, y cómo escalar o cambiar con `/model`.
- `arnes`: el arnés de los proyectos, que es el principal: `/arnes` lo instala o actualiza en cualquier proyecto (nuevo o existente) y deja `bash scripts/verify.sh` (rápido, sin Docker) y `bash scripts/verify.sh --full` (suma integración con Postgres) como evidencia de "terminado"; detalle en `templates/harness/docs/HARNESS.md`. Secundario: el arnés del propio kit (`bash tests/harness.sh`).
- `ahorro`: cómo funcionan los umbrales (guardar en engram a 200k tokens, auto-compact a 250k), qué se guarda en engram antes de compactar y cómo retomar.
- `<nombre>` de un comando o plugin: explicarlo en detalle leyendo su archivo.
Si algo no funciona, sugerir `/kit-doctor`. Si el usuario parece perdido, sugerir `/setup-kit estado`.
