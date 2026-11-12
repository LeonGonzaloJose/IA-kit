# Plan: reorientar el kit a ODD (Organic Driven Development) con el arnés en los proyectos

Estado: BORRADOR, esperando OK. Toca Docker, dependencias y el flujo base del kit → `/revisar high` por fase.

## Objetivo
1. El kit trabaja en formato ODD: la ceremonia escala con la tarea (comprensión, riesgo, retomabilidad). Tarea chica: directo, sin documento. Tarea grande: UN documento vivo con evidencia, copiado a Engram.
2. El arnés es, ante todo, de los proyectos: cualquier proyecto donde participa el kit (nuevo o existente) tiene un comando único de verificación, y su salida es la evidencia de "hecho".
3. El arnés del propio kit queda como está; solo se arreglan sus falsos verdes.

## Decisiones de diseño (cambiar acá si no convencen)
- Documento de tarea: `docs/tasks/<feature>.md` en el proyecto (no `odd/tasks/`, para no sumar otra carpeta raíz). Secciones: objetivo, problema, alcance (incluye qué NO tocar), tareas, criterios de aceptación, evidencia, progreso, siguiente paso. Copia en Engram con topic `tasks/<feature>`.
- `docs/plans/` queda solo para el roadmap de `/nuevo-proyecto` (`00-roadmap.md`).
- Se conservan los nombres `/plan` e `/implementar` (cambian por dentro) y se agrega `/arnes`.
- Verificación única por proyecto: `make verify` (rápido, sin Docker: lint + unit + contrato + front) y `make verify-full` (suma integración con Postgres). El `CLAUDE.md` del proyecto declara ambos.
- Se mantiene lo que ODD no trae: áreas "siempre grandes" con documento obligatorio y `/revisar` con lentes independientes (el agente no se autoevalúa el riesgo).

## Fase 1 — Cerrar el arnés actual (hallazgos de `/revisar high`)  [HECHA]
Evidencia: `run-all.sh` verde; `KIT_TEST_DOCKER=1 tests/test-new-project.sh` verde dos veces (27 ok, sin contenedores ni volúmenes sobrantes); a mano con Docker: corrida limpia, SIGINT y SIGTERM en medio de una migración, migración rota y puerto equivocado → 0 bases `app_test_*` sobrantes y la base `app` intacta.
Desviaciones: (a) el contrato exige ruta registrada en el router + status declarado, no "2xx/3xx" (una ruta con auth puede declarar 401 legítimamente); (b) parser de YAML propio por líneas con error ante formatos no soportados, sin `yaml.v3`; (c) no se agregó el chequeo `model:` vs tabla de `tools.md` (ya lo cubre `test-models.sh`); (d) no se creó `tests/lib.sh` ni se partió el diff en 3 commits; (e) corrección: la primera corrida "verde" de `make test-integration` informada antes en realidad fallaba por el test de docs con el placeholder de Scalar (`--no-vendor`); los tests de integración sí pasaban.
Segunda `/revisar high` (4 lentes, sin bloqueos) aplicada: catch-all del router no cuenta como ruta registrada, claves de path desconocidas (`$ref`) y tabs dan error, `2XX`, hosts de fallback rechazados, señales reenviadas al hijo (`wait`), barrido solo de bases sin sesiones, DSN de goose por entorno, más controles negativos. Límite aceptado: GET con parámetros solo verifica registro; `poolConfig` se prueba solo con la etiqueta `integration`.
Pendiente detectado: `bin/post-edit.sh` devuelve error bloqueante con "0 issues" al editar archivos Go fuera de un módulo (plantillas).
Archivos: `templates/go-vue/backend/cmd/api/contract_test.go`, `templates/harness/**`, `tests/harness.sh`, `tests/cases/*.tsv`, `tests/test-harness.sh`, `tests/test-new-project.sh`, `bin/new-project.sh`.
1. `contract_test.go`: acotar al bloque `get:`, exigir status 2xx/3xx declarado y ruta registrada en el mux (un 404 nunca es verde), fallar si un GET no declara códigos; documentar el formato de YAML asumido; test del parser con spec sintético. Corregir `HARNESS.md` ("GET sin parámetros").
2. `tests/harness.sh`: fallar si el hook sale con código ≠ 0, exigir `rg`/`jq`, fallar con 0 casos o `--hook` inexistente, rama por defecto en `payload`; chequear `-x` de los hooks; restaurar la línea `goose up` y el patrón `PASSWORD`. Controles negativos nuevos (hook que hace `exit 1`, causa del fallo verificada por texto).
3. Arnés de integración → script legible `backend/scripts/test-integration.sh` (reemplaza la receta de `harness.mk`): prechecks de docker y goose, espera por TCP desde el host, `trap` para EXIT/INT/TERM/HUP, `go mod tidy` solo si falta `go.sum`, limpieza de bases `*_test_*` huérfanas.
4. `testutil/db.go`: `Ping` con timeout, `MaxConns=4`, nombre validado con regex `_test_\d+_\d+$` + host loopback, tabla de casos; contextos con timeout.
5. `test-new-project.sh` (opt-in Docker): proyecto compose único `-p kit-test-$$` y `trap`.
Aceptación: `bash tests/run-all.sh` verde; ruta GET no implementada → test de contrato rojo; hook con `exit 1` → arnés rojo; Ctrl-C en `test-integration` no deja bases huérfanas (probado a mano con Docker); `KIT_TEST_DOCKER=1` verde. Commit: `feat: project harness (v0.10.0)`.

## Fase 2 — Arnés para cualquier proyecto (`/arnes`)  [HECHA]
Archivos: `bin/harness-install.sh` (nuevo, determinista), `commands/arnes.md` (nuevo, sonnet), `templates/harness/**`, `bin/new-project.sh` (pasa a llamar al instalador), `tests/test-harness-install.sh` (nuevo), `bin/doctor.sh`.
1. `harness-install.sh <dir> [--dry-run]`: detecta Go (`go.mod`), Vue (`package.json` con vue), Postgres (compose o `db/migrations`); instala solo lo que aplica; NUNCA pisa un archivo existente (lo informa y sigue); salida JSON con lo instalado/omitido.
2. Entradas `verify` / `verify-full`: en proyectos con Makefile se agregan como `include harness.mk`; sin Makefile, `scripts/verify.sh`. `verify` = lint + unit + contrato (+ `typecheck lint test` del front si existe); `verify-full` = `verify` + integración.
3. DSN y credenciales de integración leídos de variables (`HARNESS_PG_URL`, por defecto la del compose del kit), no fijos.
4. `/arnes`: corre el instalador con `--dry-run`, muestra qué haría, pide OK, instala, corre `make verify` y agrega al `CLAUDE.md` del proyecto la línea de verificación. En proyectos existentes, si faltan tests propone los primeros (no los inventa en silencio).
5. Doctor (sección proyecto): WARN si el proyecto actual no tiene arnés (`/arnes`).
Aceptación: instalar en (a) proyecto generado, (b) repo Go existente sin Makefile, (c) repo solo-front → `verify` corre en los tres; segunda corrida no cambia nada (idempotente); archivo preexistente no se pisa (test); `new-project.sh` sigue pasando sus tests.

**Evidencia (2026-11-11):** `bash tests/run-all.sh` → ALL TESTS PASSED (incluye `tests/test-harness-install.sh`: proyecto generado, repo Go existente sin Makefile, repo solo front, idempotencia, archivo propio no sobrescrito, dry-run sin escrituras, test roto y gofmt hacen fallar `verify`). `KIT_TEST_DOCKER=1 bash tests/test-new-project.sh` → `make verify-full` con integración pasa, 0 bases descartables. `bash tests/harness.sh` → 110 checks, PASS.
**Desvíos:** la entrada única es `scripts/verify.sh [--full]`; `make verify` / `make verify-full` son alias de un Makefile raíz que solo se crea si el proyecto no tiene uno (si lo tiene, se avisa con una nota). Archivos gestionados llevan la marca `kit-harness: managed file` (se actualizan); sin marca nunca se tocan. Nuevo `HARNESS_PG_SERVICE`. El JSON de `new-project.sh` ahora da `harness: installed|verify|skipped`. El arnés detectó que los tests de las plantillas no pasaban su propio lint (`noctx`): corregido.
**Pendiente:** `/arnes` queda disponible al reinstalar el kit (Fase 4); el doctor marca `commands/arnes.md: sin enlazar` hasta entonces.

## Fase 3 — Flujo ODD  [HECHA, falta la prueba manual]
Archivos: `CLAUDE.md`, `tools.md`, `commands/plan.md`, `commands/implementar.md`, `commands/revisar.md`, `commands/nuevo-proyecto.md`, `commands/kit-help.md`, `templates/go-vue/CLAUDE.md`, `bin/compact-handoff.sh`, `tests/harness.sh` (chequeos de contrato).
1. `CLAUDE.md` "How to work": protocolo ordenado en pocas líneas — explorar → resolver dudas (preguntar solo decisiones de producto) → clasificar (chica / grande / siempre grande, criterios actuales) → registrar antes de la primera escritura si es grande → implementar tarea por tarea → cerrar con evidencia. Sin crecer en tokens (reemplaza el bloque actual de tamaños).
2. `/plan`: abre o actualiza `docs/tasks/<feature>.md` y lo copia a Engram; los criterios de aceptación son comprobaciones ejecutables del arnés cuando se pueda. Espera OK.
3. `/implementar`: trabaja el documento tarea por tarea; test primero si aplica; tras cada tarea corre `make verify` y pega el resultado resumido en "evidencia"; actualiza progreso y siguiente paso (documento + Engram). Si cambia el alcance: conserva lo válido, agrega tareas, reabre lo invalidado con motivo. Cierre: `make verify-full` + `/revisar`.
4. `/revisar`: recibe el documento de tarea; primero comprueba criterios de aceptación contra la evidencia, después las lentes.
5. `compact-handoff.sh`: tras compactar, retomar desde el documento de tarea / topic de Engram.
6. `tools.md`, `/kit-help` (tema `odd`), plantilla de `CLAUDE.md` de proyecto, `/nuevo-proyecto` (crea `docs/tasks/`, etapa 0 incluye el arnés).
7. Chequeos de contrato del kit: ningún comando referencia `docs/plans/<slug>` para tareas; `plan.md` e `implementar.md` mencionan `docs/tasks` y `make verify`.
Aceptación: `run-all.sh` verde; `CLAUDE.md` + `tools.md` no crecen más de ~10 líneas en total; prueba end-to-end en un proyecto scratch: tarea chica sin documento, tarea grande con documento + evidencia + topic en Engram, y reanudación después de `/compact` (manual, con salida pegada).

**Evidencia (2026-11-11):** `bash tests/run-all.sh` → ALL TESTS PASSED; `bash tests/harness.sh` → 113 checks, PASS (nuevos chequeos de contrato ODD + 2 controles negativos). `CLAUDE.md` + `tools.md`: 81 → 82 líneas.
**Desvíos:** los comandos nombran `bash scripts/verify.sh [--full]` (entrada real) en vez de `make verify`. `new-project.sh` crea `docs/tasks/.gitkeep`.
**Pendiente:** prueba end-to-end manual en un proyecto scratch (tarea chica sin documento, tarea grande con documento + evidencia + topic en Engram, reanudación tras `/compact`): necesita una sesión nueva con el kit reinstalado.

## Fase 4 — Cierre  [HECHA, sin push]
`VERSION` 0.11.0, reinstalar (`install.sh`), `bash tests/run-all.sh`, doctor, `/revisar high`, commit `feat: ODD workflow (v0.11.0)`. Push solo con aprobación.

**Evidencia (2026-11-11):** `/revisar high` (4 lentes): sin bloqueantes, 11 mayores, todos corregidos con test. `bash tests/run-all.sh` → ALL TESTS PASSED; `bash tests/harness.sh` → 116 checks, PASS; `KIT_TEST_DOCKER=1 bash tests/test-new-project.sh` → `make verify-full` con integración pasa, 0 bases descartables; reinstalado (v0.11.0), doctor 0 FAIL.
**Corregido tras la revisión:** instalador — marca solo en las 3 primeras líneas, no escribe a través de symlinks, escritura atómica, `jq` exigido antes de escribir, detección de Postgres sin comentarios ni imágenes parecidas, `package.json` raíz solo es front si depende de vue, aviso de `go.work`/varios módulos, Makefile raíz se crea una sola vez (es del proyecto), dry-run anuncia lo mismo que la corrida real. `verify.sh` — timeout por paso y sin stdin, falta de go/node es falla, `gofmt` con error es falla, una corrida sin ningún test es FAIL. `test-integration.sh` — falla rápido si el servicio no está en el compose, `go mod tidy` también con `go.sum` existente. Docs y comandos nombran solo `bash scripts/verify.sh`.
**Aceptado sin corregir:** `verify.sh` cubre un solo módulo Go y un front; `--full` sin script de integración es SKIPPED y no falla; `KIT_DIR` puede redirigir las plantillas; el doctor no tiene test del aviso de arnés; `verify-full` con front no se prueba de punta a punta; renombrar/partir tests y helper de aserciones.

## Fuera de alcance
CI (GitHub Actions), e2e de navegador, floci/AWS en el arnés, evals con LLM, modo TDD configurable, migrar planes viejos.

## Riesgos
- ODD apoya "hecho" en tests verdes: un falso verde es un resultado mal aprobado → por eso la Fase 1 va primero y `/revisar` sigue siendo independiente.
- Instalar el arnés en proyectos existentes: nunca pisar, siempre `--dry-run` + OK.
- Cambiar `/plan` e `/implementar` altera el hábito actual: los nombres se conservan y `/kit-help odd` lo explica.
- `CLAUDE.md` se carga siempre: cada línea cuesta tokens en todas las sesiones.
- Comportamiento de comandos solo verificable en vivo (requiere reiniciar Claude Code).
