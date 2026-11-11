---
description: Activa/pausa el modo estudio (vibe-wise): aprendés mientras Claude escribe el código
argument-hint: "[on | off | estado]"
model: sonnet
---
Modo estudio basado en el plugin `vibe-wise` (tú diseñas, Claude explica y escribe lo acordado). Argumento: "$ARGUMENTS" (vacío = `on`). Alternativa sin comando: empezar el mensaje con `estudio:` (activa) o `trabajo:` (pausa).

## on
1. Si el plugin `vibe-wise` no está instalado: avisarlo y sugerir `/setup-kit modelos`; parar.
2. Invocar la skill `vibe-wise:learn` y seguir su protocolo. La primera vez en el proyecto hace unas preguntas de configuración (una a la vez); ofrecer "Use defaults" para saltarlas.
3. Si el directorio es un repo git y `.vibe-wise/` no está en `.gitignore`, ofrecer agregarlo (las notas son personales); no tocar el archivo sin confirmar.

## off
Pausar tal como define vibe-wise: dejar `Learning mode: paused` en `.vibe-wise/profile.md` (no borrar las notas). Confirmar en una línea y volver al flujo normal del kit. Retomar con `/estudio on`.

## estado
Leer solo `.vibe-wise/profile.md` y decir en 3 líneas: activo o pausado, nivel/objetivos declarados, y cuántos temas hay en `progress.md`. Si no existe `.vibe-wise/`, decir que el modo estudio no está iniciado en este proyecto.

## Convivencia con el resto del kit
En modo estudio manda el ciclo de vibe-wise: no ejecutar `/implementar` ni escribir código sin que el usuario haya expuesto su diseño. Las reglas de ahorro de tokens, seguridad y `/code-review` siguen vigentes. Importante: vibe-wise se reanuda solo en cada sesión de un proyecto con notas activas; para trabajar sin él en ese proyecto, usar `/estudio off`.
