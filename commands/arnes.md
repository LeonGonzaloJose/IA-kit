---
description: Instala o actualiza el arnés de verificación (scripts/verify.sh) en el proyecto actual, nuevo o existente
argument-hint: "[directorio del proyecto]"
model: sonnet
---
Proyecto: "$ARGUMENTS" (vacío = directorio actual). Instalador determinista: `bash ${CLAUDE_CONFIG_DIR:-~/.claude}/kit/root/bin/harness-install.sh <dir> [--dry-run]` (JSON por stdout; pasar la ruta siempre entre comillas). No escribir a mano lo que el instalador ya hace.

1. **Simular**: correr con `--dry-run` y mostrar en una tabla corta qué detectó (`go_dir`, `front_dir`, `postgres`) y qué haría: `installed`, `updated`, `kept` (archivos propios del proyecto que NO se tocan) y `notes`. Si agrega `pgx` a `go.mod` o líneas al `Makefile`/`CLAUDE.md`, decirlo explícitamente; avisar que un archivo en `updated` es gestionado por el kit y pierde sus ediciones locales. ESPERAR el OK.
2. **Instalar**: correr sin `--dry-run`. Resolver cada `note` con el desarrollador (p. ej. Makefile propio sin target `verify`, servicio de compose con otro nombre → `HARNESS_PG_SERVICE`, sin `CLAUDE.md`), una a la vez; nunca sobrescribir un archivo `kept`.
3. **Verificar**: `bash scripts/verify.sh` y pegar el resumen final (`verify: PASS|FAIL`, pasos fallidos y `SKIPPED`). Con Postgres detectado y compose levantado, también `bash scripts/verify.sh --full`; si Docker no está disponible, decir que quedó sin correr.
4. **Proyecto existente**: si `verify` falla por deuda previa (lint, formato, tests rotos), NO arreglarla en silencio: listar las fallas agrupadas por causa raíz (no una por una) y preguntar qué hacer. Si se decide arreglarlas: primero infraestructura (imports, dependencias, configuración, build), después lógica; un grupo por vez, verificando ese grupo antes de pasar al siguiente. Si no hay tests, proponer los 2-3 primeros (qué comportamiento cubren y por qué) y esperar el OK antes de escribirlos; nunca inventar tests que solo pasan.
5. Cerrar con: qué se instaló, qué se verificó (con la salida) y qué quedó pendiente. Detalle del arnés en `docs/HARNESS.md` del proyecto.
