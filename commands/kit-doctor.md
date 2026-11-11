---
description: Diagnostica la salud del kit (enlaces, settings, plugins, herramientas, Docker, proyecto)
argument-hint: "[--fix]"
model: haiku
---
Ejecutar `bash ${CLAUDE_CONFIG_DIR:-~/.claude}/kit/bin/doctor.sh` y mostrar el resultado tal cual, sin releer archivos (el script ya hace los chequeos; no gastar tokens en repetirlos).

Luego, en máx. 6 líneas:
1. Veredicto: sano / con avisos / roto.
2. Lo que hay que arreglar, ordenado por impacto, con el comando o paso exacto. FAIL primero, después WARN.
3. Si hay problemas y el argumento es `--fix` (o el usuario lo pide): proponer el arreglo y preguntar antes de aplicarlo, de a uno.
   - enlaces rotos o sin enlazar, settings o hooks faltantes → `install.sh` del kit.
   - herramientas, perfiles o servicios → `/setup-kit <sección>`.
   - plugin deshabilitado → `claude plugin enable <p>`.
   Nunca arreglar nada sin confirmación.
4. Recordar que los avisos del repo del kit (sin commits, sin remoto) son normales mientras no se publique en GitHub.
