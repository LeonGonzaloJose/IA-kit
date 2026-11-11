---
description: Auditoría de seguridad y calidad del proyecto completo (Go, Vue, Postgres, AWS)
argument-hint: "[seguridad | dependencias | secretos | sql | api | aws | todo]"
model: sonnet
---
Auditar el proyecto actual. Alcance: "$ARGUMENTS" (vacío = `todo`). Esto es distinto de `/code-review` (solo el diff): aquí se revisa el proyecto entero.

Delegar al subagente `auditor-seguridad` (solo lectura) para no llenar el contexto; que devuelva conclusiones, no volcados. Detectar el stack primero (`go.mod`, `package.json`, `docker-compose.yml`, `api/openapi.yaml`) y auditar solo lo que exista.

## Áreas
- **dependencias**: Go → `govulncheck ./...`; Vue → `npm audit --omit=dev`. Reportar solo vulnerabilidades alcanzables o de severidad alta/crítica.
- **seguridad (código)**: Go → `gosec ./...` y `golangci-lint run`; revisar validación de entrada, manejo de errores, concurrencia, `context` y timeouts, CORS, autenticación/autorización, logs con datos sensibles. Vue → `v-html`, XSS, tokens en `localStorage`, rutas sin guard.
- **secretos**: buscar con `rg` claves, tokens y contraseñas en el árbol y en `git log -p` reciente; verificar `.gitignore` y que exista `.env.example`. Reportar sin mostrar valores.
- **sql**: concatenación de strings en consultas, permisos del usuario de base de datos, migraciones destructivas sin guardas, índices faltantes en claves foráneas, datos sensibles en claro.
- **api**: el contrato `api/openapi.yaml` contra los handlers (rutas o campos desincronizados), endpoints sin autenticación, falta de límites de tamaño o paginación.
- **aws**: S3 (buckets públicos, ACL, cifrado), SQS (políticas abiertas, DLQ, visibilidad); credenciales no hardcodeadas; endpoints de floci solo en desarrollo.
- **docs de la API**: que `/docs` no quede expuesto sin autenticación en producción y que `openapi.yaml` no filtre endpoints internos ni ejemplos con datos reales.
- **docker**: imágenes sin versión fija, contenedores como root, puertos expuestos de más, secretos en el compose.

## Salida
1. Resumen: conteo por severidad y las 3 acciones más importantes.
2. Informe completo en `docs/audits/AAAA-MM-DD.md` (hallazgos, `archivo:línea`, arreglo propuesto, "no verificado").
3. Preguntar si corregir los críticos y altos; si sí, proponer un plan corto (`/plan`) en vez de arreglar todo de golpe.
4. Guardar en engram un resumen de lo encontrado.
