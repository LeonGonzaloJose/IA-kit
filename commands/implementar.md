---
description: Trabajar un documento de tarea de docs/tasks, tarea por tarea y con evidencia
argument-hint: "[feature o ruta del documento]"
model: sonnet
---
Documento: $ARGUMENTS (vacío = el único de `docs/tasks/` con tareas abiertas; si hay más de uno, preguntar cuál). Sin documento: es una tarea chica, hacerla directo, o pedir `/plan` si resulta grande.
Por cada tarea de la checklist, en orden:
1. Test primero si aplica; implementar lo mínimo (ponytail).
2. Verificar con `bash scripts/verify.sh`; si la tarea toca SQL, migraciones o el contrato, `bash scripts/verify.sh --full` (compose levantado). Sin arnés: sugerir `/arnes` y usar los tests/lint del proyecto.
3. Marcar la tarea hecha y pegar en **Evidencia** el resumen de la verificación (la línea `verify: PASS|FAIL`, pasos fallidos y `SKIPPED`), nunca la salida completa. Una tarea con verificación fallida no se marca hecha.
4. Actualizar **Progreso** y **Siguiente paso** en el documento y en Engram (`topic_key: tasks/<feature>`).
**Commits**: un commit por grupo coherente de tareas (no uno por tarea suelta ni uno gigante al final), con `verify` en verde, rutas explícitas y mensaje conventional. Nunca `git push`: al terminar, avisar qué commits quedaron sin subir y esperar la decisión del desarrollador.
**Hallazgos de revisión** (tabla de `/revisar`, comentarios de un PR): cada hallazgo aceptado es una tarea más de la checklist, ordenadas por severidad; resolverlas de a una, con su verificación, antes de pasar a la siguiente. Los descartados se anotan en el documento con el motivo; si uno es ambiguo, preguntar antes de tocar código.
Si cambia el alcance: actualizar el documento ANTES de seguir — conservar lo válido, agregar tareas, reabrir lo invalidado anotando el motivo. Si el documento resulta incorrecto, parar y avisar en vez de improvisar.
Cierre: `bash scripts/verify.sh --full` si hay Postgres, comprobar cada criterio de aceptación contra la evidencia y correr `/revisar` (profundidad por riesgo; las áreas siempre grandes — auth, SQL/migraciones, secretos, dependencias, CI — exigen `/revisar high`); `/code-review` solo si se va a abrir un PR. Informar implementado, verificado y pendiente.
