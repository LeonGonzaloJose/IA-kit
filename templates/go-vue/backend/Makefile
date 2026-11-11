.PHONY: run build test lint vuln sec docs-assets gen migrate-up migrate-down
DSN ?= $(DATABASE_URL)

docs-assets:
	@[ -s internal/docs/scalar.standalone.js ] && ! grep -q PLACEHOLDER internal/docs/scalar.standalone.js || ./internal/docs/vendor.sh

run: docs-assets
	go run ./cmd/api

build: docs-assets
	CGO_ENABLED=0 go build -o bin/api ./cmd/api

test:
	go test ./... -race -count=1

lint:
	golangci-lint run ./...

vuln:
	govulncheck ./...

sec:
	gosec -quiet ./...

gen:
	sqlc generate
	oapi-codegen -config oapi-codegen.yaml api/openapi.yaml

migrate-up:
	goose -dir db/migrations postgres "$(DSN)" up

migrate-down:
	goose -dir db/migrations postgres "$(DSN)" down
