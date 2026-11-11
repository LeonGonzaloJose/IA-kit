# go-docs — manual de la API (reemplazo de Swagger UI)

Renderiza `api/openapi.yaml` con [Scalar](https://scalar.com) (MIT), embebido en el binario.
El contrato OpenAPI es la fuente de verdad; esto es solo el visor/manual.

## Uso en un proyecto
1. Copiar esta carpeta a `backend/internal/docs/` y ejecutar `./vendor.sh` (descarga `scalar.standalone.js`).
2. En `backend/api/embed.go`: `package api` + `//go:embed openapi.yaml` + `var Spec []byte`.
3. Montar: `mux.Handle("/docs/", http.StripPrefix("/docs", docs.Handler(api.Spec)))`.
4. Mostrar solo en desarrollo o detrás de autenticación en producción.
