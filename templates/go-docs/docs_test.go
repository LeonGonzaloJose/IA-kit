package docs

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	h := http.StripPrefix("/docs", Handler([]byte("openapi: 3.0.3\n")))
	cases := map[string]string{
		"/docs/":                  "api-reference",
		"/docs/spec/openapi.yaml": "openapi: 3.0.3",
	}
	for path, want := range cases {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != 200 || !strings.Contains(rec.Body.String(), want) {
			t.Fatalf("%s: code=%d, falta %q", path, rec.Code, want)
		}
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/docs/scalar.standalone.js", nil))
	if rec.Code != 200 || rec.Body.Len() < 1000 {
		t.Fatalf("js no servido: code=%d len=%d", rec.Code, rec.Body.Len())
	}
}
