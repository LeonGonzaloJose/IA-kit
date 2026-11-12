---
description: Explorar y abrir o actualizar el documento vivo de una tarea grande (docs/tasks) antes de codear
argument-hint: "<tarea o feature>"
model: opus
---
Tarea: $ARGUMENTS
Solo para tareas grandes o de las áreas "siempre grandes" (ver `CLAUDE.md`). Si la tarea es chica (entendida, local, retomable desde el diff), decirlo y hacerla directo, sin documento.
1. **Explorar** solo lo necesario (rg primero; context7 para APIs externas; `mem_search` por decisiones previas y por el topic `tasks/<feature>`).
2. **Resolver dudas**: las decisiones de producto se preguntan (una a la vez); las técnicas se responden leyendo el código.
3. **Registrar** en `docs/tasks/<feature>.md` (kebab-case; si ya existe, actualizarlo conservando lo válido, nunca crear otro). Secciones: Objetivo · Problema · Alcance (incluye qué NO tocar) · Tareas (checklist chica y verificable) · Criterios de aceptación · Evidencia (vacía) · Progreso · Siguiente paso. Los criterios de aceptación son comprobaciones ejecutables cuando se pueda (`bash scripts/verify.sh`, un test con nombre, un comando con su salida esperada); si el proyecto no tiene `scripts/verify.sh`, la primera tarea es `/arnes`.
4. **Copiar a Engram**: `mem_save` con `topic_key: tasks/<feature>` (objetivo, alcance, tareas, siguiente paso).
5. Mostrar un resumen de máx. 10 líneas y ESPERAR el OK. No escribir código.
