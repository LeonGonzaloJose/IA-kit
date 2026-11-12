# Plan: arnés (test harness) del kit y de los proyectos generados

Estado: EJECUTADO (v0.10.0), pendiente /revisar high y commit. Área "siempre grande" (Docker, dependencias, tests de integración) → `/revisar` high al terminar.

## Decisiones ya tomadas (usuario)
- Proyectos: arnés de **integración backend** (Postgres real en Docker, migraciones, fixtures, test de contrato contra `openapi.yaml`). Sin e2e de navegador ni AWS en esta etapa.
- Kit: arnés **determinista y offline** para hooks + instalación + generador (sin evals con LLM).

## Objetivo
1. `tests/harness.sh`: un runner único, con casos declarativos (entrada → decisión esperada) para hooks, merge de settings, generador y modelos; reemplaza el copy-paste de `tests/test-*.sh` y demuestra que detecta regresiones.
2. Cada proyecto con Postgres generado por `new-project.sh` incluye un arnés de integración listo: `make test-integration`.

## Parte A — arnés del kit  [HECHA: pasos 1-5, run-all verde, 109 chequeos]
Archivos: `tests/harness.sh` (nuevo), `tests/cases/*.tsv` (nuevo, un archivo por hook: `nombre<TAB>esperado<TAB>comando|json`), `tests/test-harness.sh` (nuevo), `tests/run-all.sh` (llama al arnés), `tests/test-guard.sh` y `test-env-guard.sh` (migrar sus casos a `cases/`, dejar un wrapper de una línea).
Pasos:
1. Definir formato de casos y adaptadores por hook (cómo se arma el JSON de entrada y cómo se interpreta la salida: deny/ask/allow/contexto). Verificar: los casos existentes migrados dan el mismo conteo (hoy: env-guard 18+22 nuevos, guard 22+11 nuevos).
2. Escribir `harness.sh` con `--hook <nombre>`, `--list`, salida resumida (ok/FAIL por caso + total) y código de salida ≠ 0 si falla.
3. Control negativo (mutación): `test-harness.sh` ejecuta el arnés contra un hook falso "siempre allow" en un directorio temporal y exige que FALLE; así se prueba que el arnés no da falsa confianza.
4. Chequeos de contrato estáticos en el arnés: cada comando/agente tiene `model:` válido y coincide con la tabla de `tools.md`; cada hook de `settings.fragment.json` existe en `bin/` y es ejecutable; ningún "25%" ni umbral contradictorio; marketplaces de `plugins.txt` declarados en `marketplaces.txt` (el bug que encontró la auditoría).
5. Casos de instalación/generador ya cubiertos por `test-install.sh` / `test-new-project.sh`: se invocan desde el arnés (no se duplican).
Criterios de aceptación:
- `bash tests/run-all.sh` pasa y el total de casos ≥ al actual (no se pierde cobertura).
- Romper a propósito un hook (p. ej. env-guard siempre allow) hace fallar el arnés (verificado en `test-harness.sh`).
- Introducir un marketplace faltante en `plugins.txt` hace fallar el chequeo de contrato.

## Parte B — arnés de integración en las plantillas  [HECHA]
Desviaciones respecto al plan inicial: (a) sin `kin-openapi` ni `yaml.v3`: el contrato se verifica con stdlib sobre `api.Spec`; (b) `contract_test.go` va sin etiqueta y corre en `make test` (no necesita Docker); (c) fixtures embebidos en `internal/testutil/fixtures/`; (d) el arnés vive en `templates/harness/` y se enlaza con `-include harness.mk`; (e) única dependencia nueva: `pgx/v5 v5.13.0`. Evidencia: `make test-integration` verde en proyecto scratch con Docker; migración inválida → falla y la base descartable se borra; cambiar un status en openapi.yaml → el test de contrato falla.
Archivos (en `templates/go-vue/backend/`): `internal/testutil/db.go`, `internal/testutil/fixtures.go`, `testdata/fixtures/*.sql`, `internal/store/store_integration_test.go` (humo: aplica migraciones y consulta), `cmd/api/api_integration_test.go` (humo + contrato), Makefile (`test-integration`, `db-test-create`, `db-test-drop`), `go.mod` (dependencias), `CLAUDE.md` y `README.md` de la plantilla. En el kit: `bin/new-project.sh`, `tests/test-new-project.sh`.
Diseño (recomendado):
- Tests con build tag `//go:build integration`, así `make test` sigue siendo rápido y sin Docker.
- Usan el servicio `postgres` del compose existente (sin testcontainers): `make test-integration` crea una base descartable `<name>_test_<rand>`, aplica `goose up` con el CLI y la borra al terminar (también si falla).
- Aislamiento: DSN por variable `DATABASE_URL_TEST`; el arnés se niega a correr si el nombre de la base no termina en `_test_*` (protege datos de desarrollo).
- Fixtures SQL idempotentes cargadas por `testutil.Load(t, "users.sql")`.
- Contrato: el test recorre los paths de `api/openapi.yaml` y verifica que cada ruta responde con un código declarado.
- Se genera solo si `--services` incluye `postgres`; flag `--no-harness` para omitirlo.
Pasos:
1. Dependencias mínimas: `pgx/v5` (ya implícita por `sqlc.yaml`) y `kin-openapi` (contrato). **Requieren aprobación explícita** (guard pregunta; área dependencias). Alternativa sin kin-openapi: parsear el YAML de paths con la stdlib + `gopkg.in/yaml.v3`.
2. `testutil` + Makefile con creación/borrado de la base y la salvaguarda del sufijo.
3. Tests de humo (store + API) y un fixture de ejemplo.
4. `new-project.sh`: copiar el arnés condicionalmente y registrar en el JSON de salida `"harness":"installed|skipped"`.
5. `/nuevo-proyecto`: añadir "arnés de integración" a la Etapa 0 del roadmap; `/plan` e `/implementar`: citar `make test-integration` como verificación cuando haya cambios de SQL/migraciones; `tools.md`, `/kit-help` (tema nuevo `arnes`).
6. `VERSION` → 0.10.0.
Criterios de aceptación:
- Proyecto generado con postgres: `docker compose up -d && cd backend && make test-integration` pasa en verde (evidencia: salida pegada).
- `make test` sigue sin requerir Docker; con `--no-harness` o sin postgres no se generan archivos del arnés.
- El arnés falla si se rompe una migración (probado a mano con una migración inválida) y NO toca la base de desarrollo.
- `test-new-project.sh` verifica presencia/ausencia de los archivos; `KIT_TEST_DOCKER=1` ejecuta además la corrida real (opt-in, por defecto omitido).

## Fuera de alcance (decirlo, no hacerlo)
CI (GitHub Actions) para correr el arnés, Playwright/e2e, tests de S3/SQS con floci, evals de comandos con LLM. Cada uno sería su propio plan.

## Riesgos
- Dependencias nuevas en la plantilla (supply chain): fijar versiones y revisar con `/revisar` high.
- El test de integración borra bases: salvaguarda de sufijo + prueba negativa.
- Migrar casos a `cases/*.tsv` puede perder casos con comillas/saltos: comparar conteo antes/después.
- Puerto 5432 ocupado o Docker caído: el Makefile debe fallar con mensaje claro, no colgarse (timeout en la espera de Postgres).
- Go 1.27 local vs `go.mod` de la plantilla: verificar con la versión real al generar.

## Orden y verificación
A (pasos 1–5) → `run-all.sh` verde → B (pasos 1–6) → corrida real en proyecto de scratch → `/revisar` high → commit (sin push hasta aprobar).
