---
description: Define un proyecto nuevo (entrevista → tecnologías → plan por etapas) y arma la base
argument-hint: "<nombre> [idea en una frase]"
model: opus
---
Proyecto: "$ARGUMENTS". Raíz del kit: `${CLAUDE_CONFIG_DIR:-~/.claude}/kit/root`.

Este comando NO escribe código de negocio. Produce: definición, decisiones técnicas, plan por etapas y la base (etapa 0). Reglas: una pregunta a la vez con AskUserQuestion; recomendar una opción y justificar en una línea; no avanzar de fase sin el OK; respuestas cortas. Antes de empezar, `mem_search` por decisiones previas del usuario y reutilizarlas como valores por defecto.

## Fase 1 — Descubrimiento (entrevista)
Si la idea es difusa, usar la skill de brainstorming de superpowers. Cubrir, en este orden, saltando lo que ya se sepa:
1. Problema y usuarios; qué es el MVP y qué queda fuera.
2. Forma: solo backend, solo frontend o cliente-servidor.
3. Datos: Postgres (siempre). ¿Necesita **Redis**? (caché, sesiones, rate limiting, colas livianas, locks). ¿Necesita **Elasticsearch**? (búsqueda de texto, filtros/facets, logs). Preguntar por el caso de uso concreto y recomendar NO usarlos si Postgres alcanza.
4. Integraciones: S3 / SQS (floci en desarrollo), auth (propia, OIDC), pagos, correo, terceros.
5. Cómo se trabaja: ramas y PRs, convención de commits, nivel de pruebas (unitarias / integración / e2e), CI, entornos (dev/staging/prod), despliegue.
6. No funcionales: volumen esperado, latencia, seguridad/datos sensibles, disponibilidad.
Guardar todo en `docs/PROJECT.md` (secciones: Problema, Alcance MVP, Usuarios, Integraciones, Forma de trabajo, No funcionales). Mostrar un resumen de máx. 12 líneas y pedir OK.

## Fase 2 — Tecnologías y decisiones
Proponer el stack con una línea de justificación por pieza: Go + Vue 3 + Postgres por defecto, más lo decidido (Redis, Elastic, floci). Documentar en `docs/DECISIONS.md` (decisión, alternativa descartada, motivo). Puntos fijos del kit: contrato `api/openapi.yaml` como fuente de verdad, **Scalar** para el manual de la API (nunca swaggo), sqlc + goose sin ORM, todo en Docker. Pedir OK.

## Fase 3 — Plan por etapas
Escribir `docs/plans/00-roadmap.md`: etapas chicas y verificables. Cada etapa: objetivo, entregables, criterio de aceptación, dependencias, riesgos, estimación en tamaño (S/M/L). Etapa 0 = base técnica; etapa 1 = el camino más delgado de extremo a extremo (un flujo real de front a base de datos); luego el resto ordenado por valor y riesgo. Mostrar el roadmap en tabla corta y pedir OK. Cada etapa se detalla recién cuando toca, con `/plan <etapa>`.

## Fase 4 — Base (etapa 0)
Usar el generador determinista (no escribir el esqueleto a mano; ahorra tokens y es reproducible):
1. `bash ${CLAUDE_CONFIG_DIR:-~/.claude}/kit/root/bin/new-project.sh <nombre-kebab> --module <go/module> --services <lista> [--port N] [--title "…"] [--no-front|--no-back]` con `--dry-run` primero y mostrar el resultado. Servicios: `postgres` siempre; `redis`, `elasticsearch`, `floci` solo si se decidieron. Si Elastic: avisar de `vm.max_map_count` y ~1 GB de RAM.
2. Generado: `backend/` (Go, `cmd/api`, `api/openapi.yaml` + `embed.go`, `db/migrations` goose, `db/queries` sqlc, Makefile, Dockerfile, `.golangci.yml`, manual Scalar en `internal/docs`), `frontend/` (Vue 3 + Vite + TS + Pinia + ESLint + Vitest), `docker-compose.yml` solo de infraestructura, `.env.example`, `.gitignore` (incluye `.vibe-wise/`), `README.md` y `CLAUDE.md` del proyecto.
3. Después: `git init`, mover/crear `docs/PROJECT.md`, `docs/DECISIONS.md` y `docs/plans/00-roadmap.md` dentro del proyecto; ajustar el `CLAUDE.md` del proyecto con las decisiones. Si el scaffold ya está en el directorio de trabajo, pasar `--dir`.
4. Activar perfiles según la forma (backend y/o front) con `/setup-kit perfiles`; no instalar nada sin confirmar.

## Fase 5 — Cierre
Verificar con `docker compose config -q`, `cd backend && go vet ./... && go test ./...` y `cd frontend && npm install && npm run typecheck && npm run lint && npm test` (confirmar antes de instalar dependencias). Guardar en engram (`mem_save`) las decisiones y el roadmap. Resumen final de máx. 8 líneas con el siguiente paso: `/plan etapa-1`.
