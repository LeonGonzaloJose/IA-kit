// Package docs sirve el manual interactivo de la API (Scalar) a partir de openapi.yaml.
// Todo va embebido: sin CDN, funciona sin internet.
package docs

import (
	_ "embed"
	"net/http"
)

//go:embed scalar.standalone.js
var scalarJS []byte

const page = `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Manual de la API</title>
</head>
<body>
  <script id="api-reference" data-url="spec/openapi.yaml"></script>
  <script src="scalar.standalone.js"></script>
</body>
</html>`

// Handler devuelve un http.Handler para montar bajo un prefijo (ej. /docs/)
// con http.StripPrefix. spec son los bytes de openapi.yaml, que el proyecto
// embebe con //go:embed desde su paquete api.
func Handler(spec []byte) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		// unsafe-inline/unsafe-eval are required by the Scalar bundle; acceptable only because /docs is never mounted in production.
		w.Header().Set("Content-Security-Policy",
			"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'")
		_, _ = w.Write([]byte(page))
	})
	mux.HandleFunc("GET /scalar.standalone.js", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/javascript; charset=utf-8")
		_, _ = w.Write(scalarJS)
	})
	mux.HandleFunc("GET /spec/openapi.yaml", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
		_, _ = w.Write(spec)
	})
	return mux
}
