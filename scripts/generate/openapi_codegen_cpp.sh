#!/usr/bin/env bash
set -euo pipefail
SCHEMA="third_party/api-schemas/mistral/openapi.yaml"
OUT="clients/mistral-cpp"
rm -rf "$OUT"
openapi-generator generate -i "$SCHEMA" -g cpp-httplib -o "$OUT"
echo "Generated C++ client in $OUT"
