// Package api embeds the OpenAPI contract, the single source of truth for the HTTP API.
package api

import _ "embed"

//go:embed openapi.yaml
var Spec []byte
