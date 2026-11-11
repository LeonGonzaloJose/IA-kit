---
description: Ejecutar un plan de docs/plans paso a paso
model: sonnet
---
Plan: $ARGUMENTS (si vacío, el más reciente en `docs/plans/`).
Por cada paso: test primero si aplica, implementar lo mínimo (ponytail), correr lint/tests, marcar el paso hecho en el plan. Guardar avances clave en engram. Si el plan resulta incorrecto, parar y avisar en vez de improvisar. Al final, `/revisar` sobre el diff (profundidad por riesgo); `/code-review` solo si se va a abrir un PR. Cambios de las áreas siempre grandes (auth, SQL/migraciones, secretos, dependencias, CI) exigen `/revisar high`.
