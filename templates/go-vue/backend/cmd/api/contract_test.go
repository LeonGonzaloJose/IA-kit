package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"testing"

	"__MODULE__/api"
)

// Layout parseGETs understands: block-style YAML, 2-space indentation.
const (
	pathIndent    = 2 // "  /users:"
	opIndent      = 4 // "    get:"
	sectionIndent = 6 // "      responses:"
	codeIndent    = 8 // `        "200":`
)

var (
	pathParam = regexp.MustCompile(`\{[^}]+\}`)
	// keys allowed next to the operations of a path; anything else (e.g. $ref) is rejected, not skipped
	pathItemKeys = []string{"get", "put", "post", "delete", "patch", "head", "options", "trace", "parameters", "summary", "description", "servers"}
)

// yamlKey splits `key: rest # comment`; a key may contain colons (`/items:batch:`).
func yamlKey(line string) (key, rest string, ok bool) {
	s := strings.TrimSpace(line)
	if i := strings.Index(s, " #"); i >= 0 {
		s = strings.TrimSpace(s[:i])
	}
	if k, found := strings.CutSuffix(s, ":"); found {
		return strings.Trim(k, `"'`), "", true
	}
	k, r, found := strings.Cut(s, ": ")
	return strings.Trim(k, `"'`), strings.TrimSpace(r), found
}

// parseGETs returns, for every path with a GET operation, the response codes it declares.
// It returns an error on any layout it does not understand, so an unsupported file can never
// look like a passing contract.
func parseGETs(spec string) (map[string][]string, error) {
	gets := map[string][]string{}
	var inPaths bool
	var path, op, section string
	for i, line := range strings.Split(spec, "\n") {
		lineNo := i + 1
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		indent := len(line) - len(strings.TrimLeft(line, " "))
		if strings.HasPrefix(line[indent:], "\t") {
			return nil, fmt.Errorf("line %d: tab in indentation", lineNo)
		}
		if indent == 0 {
			inPaths = trimmed == "paths:"
			continue
		}
		if !inPaths {
			continue
		}
		key, rest, ok := yamlKey(line)
		switch indent {
		case pathIndent:
			if !ok || !strings.HasPrefix(key, "/") || rest != "" {
				return nil, fmt.Errorf("line %d: unsupported path entry %q", lineNo, trimmed)
			}
			path, op, section = key, "", ""
		case opIndent:
			if !ok || (!slices.Contains(pathItemKeys, key) && !strings.HasPrefix(key, "x-")) {
				return nil, fmt.Errorf("line %d: unsupported path item %q", lineNo, trimmed)
			}
			op, section = key, ""
			if op == "get" {
				if rest != "" {
					return nil, fmt.Errorf("line %d: only block-style operations are supported", lineNo)
				}
				gets[path] = nil
			}
		case sectionIndent:
			section = key
		case codeIndent:
			if ok && op == "get" && section == "responses" {
				gets[path] = append(gets[path], key)
			}
		}
	}
	if len(gets) == 0 {
		return nil, fmt.Errorf("no GET operation found under paths")
	}
	for p, codes := range gets {
		if len(codes) == 0 {
			return nil, fmt.Errorf("GET %s declares no responses", p)
		}
	}
	return gets, nil
}

// declares reports whether a status is covered by the declared codes ("200", "2XX" or "default").
func declares(codes []string, status int) bool {
	s := strconv.Itoa(status)
	return slices.Contains(codes, s) || slices.Contains(codes, s[:1]+"XX") || slices.Contains(codes, "default")
}

// registered reports whether the mux has a route of its own for the request. Subtree and
// catch-all patterns ("/", "/api/", "{rest...}") do not count: they match everything.
func registered(mux *http.ServeMux, req *http.Request) bool {
	_, pattern := mux.Handler(req)
	if pattern == "" || strings.Contains(pattern, "...}") {
		return false
	}
	return !strings.HasSuffix(pattern, "/") || strings.HasSuffix(req.URL.Path, "/")
}

func TestParseGETs(t *testing.T) {
	const base = "openapi: 3.0.3\npaths:\n"
	const ok200 = "      responses:\n        \"200\":\n          description: ok\n"
	tests := []struct {
		name    string
		spec    string
		want    map[string][]string
		wantErr string
	}{
		{"plain", base + "  /a:\n    get:\n" + ok200, map[string][]string{"/a": {"200"}}, ""},
		{"quoted path, bare code", base + "  '/a':\n    get:\n      responses:\n        200:\n          description: ok\n", map[string][]string{"/a": {"200"}}, ""},
		{"colon inside the path", base + "  /items:batch:\n    get:\n" + ok200, map[string][]string{"/items:batch": {"200"}}, ""},
		{"other methods are not mixed in", base + "  /a:\n    post:\n      responses:\n        \"201\":\n          description: c\n    get:\n" + ok200, map[string][]string{"/a": {"200"}}, ""},
		{"comment at column 0, next section", base + "# note\n  /a:\n    get: # list\n      responses:\n        default:\n          description: x\ncomponents:\n  schemas: {}\n", map[string][]string{"/a": {"default"}}, ""},
		{"parameters at path and operation level", base + "  /a/{id}:\n    parameters:\n      - name: id\n        in: path\n    get:\n      parameters:\n        - name: q\n          in: query\n" + ok200, map[string][]string{"/a/{id}": {"200"}}, ""},
		{"path without get is ignored", base + "  /a:\n    get:\n" + ok200 + "  /b:\n    post:\n      responses:\n        \"201\":\n          description: c\n", map[string][]string{"/a": {"200"}}, ""},
		{"flow style", base + "  /a:\n    get: {responses: {\"200\": {description: ok}}}\n", nil, "block-style"},
		{"$ref path item", base + "  /a:\n    get:\n" + ok200 + "  /b:\n    $ref: './b.yaml'\n", nil, "unsupported path item"},
		{"tab indentation", base + "  /a:\n    get:\n" + ok200 + "\t/b:\n", nil, "tab in indentation"},
		{"get without responses", base + "  /a:\n    get:\n      summary: x\n", nil, "declares no responses"},
		{"no paths", "openapi: 3.0.3\n", nil, "no GET operation"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseGETs(tt.spec)
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("err = %v, want one containing %q", err, tt.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if len(got) != len(tt.want) {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
			for p, codes := range tt.want {
				if !slices.Equal(got[p], codes) {
					t.Errorf("%s: got %v, want %v", p, got[p], codes)
				}
			}
		})
	}
}

func TestRegisteredIgnoresCatchAll(t *testing.T) {
	noop := func(http.ResponseWriter, *http.Request) {}
	mux := http.NewServeMux()
	mux.HandleFunc("/", noop) // SPA fallback
	mux.HandleFunc("/api/", noop)
	mux.HandleFunc("GET /users/{id}", noop)
	mux.HandleFunc("GET /files/{rest...}", noop)
	tests := map[string]bool{"/users/1": true, "/ghost": false, "/api/ghost": false, "/files/a/b": false, "/api/": true}
	for path, want := range tests {
		if got := registered(mux, httptest.NewRequest(http.MethodGet, path, nil)); got != want {
			t.Errorf("registered(%s) = %v, want %v", path, got, want)
		}
	}
}

func TestDeclares(t *testing.T) {
	if !declares([]string{"2XX"}, 204) || !declares([]string{"default"}, 500) || declares([]string{"200", "404"}, 201) {
		t.Fatal("declares: wrong match")
	}
}

// Every GET in the contract must be a route of its own in the router, so a missing route fails even
// if the contract declares 404. GETs without path parameters must also answer with a declared status;
// with parameters only the registration is checked, since real values are unknown here.
func TestGetRoutesMatchContract(t *testing.T) {
	gets, err := parseGETs(string(api.Spec))
	if err != nil {
		t.Fatalf("api/openapi.yaml: %v", err)
	}
	mux := newMux("production") // production hides /docs: the contract covers the API only
	for path, codes := range gets {
		url := pathParam.ReplaceAllString(path, "1")
		hasParams := url != path
		req := httptest.NewRequest(http.MethodGet, url, nil)
		if !registered(mux, req) {
			t.Errorf("GET %s is in the contract but not registered in the router", path)
			continue
		}
		if hasParams {
			continue
		}
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if !declares(codes, rec.Code) {
			t.Errorf("GET %s answered %d, contract declares %v", path, rec.Code, codes)
		}
	}
}
