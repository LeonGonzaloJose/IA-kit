#!/usr/bin/env bash
# UserPromptSubmit: palabra clave para activar/pausar el modo estudio (vibe-wise).
#   Activar: el prompt empieza con  "estudio:"  o  "#estudio"
#   Pausar : el prompt empieza con  "trabajo:"  o  "#trabajo"
# Silencioso en cualquier otro prompt (cero tokens).
p="$(python3 -c 'import sys,json;print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null)"
head="$(printf '%s' "$p" | head -c 40 | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//')"
case "$head" in
  "estudio:"*|"#estudio"*)
    echo "[kit] Modo estudio ACTIVADO por palabra clave. Invoca ahora la skill vibe-wise:learn y sigue su protocolo durante toda la sesión: el usuario lidera el diseño, tú explicas y escribes el código acordado. Mientras esté activo, /plan e /implementar ceden ante ese ciclo (preguntar el enfoque del usuario antes de implementar). El resto del mensaje es la petición real." ;;
  "trabajo:"*|"#trabajo"*)
    echo "[kit] Modo estudio PAUSADO por palabra clave. Aplica la pausa de vibe-wise (Learning mode: paused en .vibe-wise/profile.md) y vuelve al flujo normal del kit (/plan, /implementar). El resto del mensaje es la petición real." ;;
esac
exit 0
