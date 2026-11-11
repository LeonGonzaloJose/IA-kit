#!/usr/bin/env bash
# Descarga el JS de Scalar (MIT) para embeberlo: la documentación funciona sin internet.
# Uso: ./vendor.sh [version]   (sin versión usa SCALAR_VERSION, fijada abajo; actualizarla a mano)
# Verifica el sha512 del tarball contra dist.integrity del registro y aborta si no coincide.
set -euo pipefail
cd "$(dirname "$0")"
SCALAR_VERSION="1.78.0"
pkg="@scalar/api-reference"
v="${1:-$SCALAR_VERSION}"
die() { echo "vendor.sh: $1" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || die "npm no está instalado"
want="$(npm view "$pkg@$v" dist.integrity 2>/dev/null || true)"
[[ "$want" == sha512-* ]] || die "no se pudo obtener dist.integrity de $pkg@$v (¿sin red o versión inexistente?)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && npm pack "$pkg@$v" --silent >/dev/null) || die "npm pack $pkg@$v falló (¿sin red?)"
tgz="$(ls "$tmp"/*.tgz)"
got="sha512-$(openssl dgst -sha512 -binary "$tgz" | base64 -w0)"
[ "$got" = "$want" ] || die "integridad NO coincide para $pkg@$v (registro: $want, descargado: $got)"
tar -xzf "$tgz" -C "$tmp" package/dist/browser/standalone.js
cp "$tmp/package/dist/browser/standalone.js" scalar.standalone.js
echo "$v" > scalar.version
echo "Scalar $v ($want) -> scalar.standalone.js"
