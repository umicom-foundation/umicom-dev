#!/usr/bin/env bash

# =============================================================================
#  Umicom Dev Tools - {FILENAME}
#  Project: Umicom AuthorEngine AI / Workspace Utilities
#  Purpose: Keep credits & licensing visible in every file.
#  
#  © 2025 Umicom Foundation - License: MIT

#  Credits: Umicom Foundation engineering. 
#  NOTE: Do not remove this credits banner. Keep credits in all scripts/sources.
# =============================================================================

set -euo pipefail
SCHEMA="third_party/api-schemas/mistral/openapi.yaml"
OUT="clients/mistral-cpp"
rm -rf "$OUT"
openapi-generator generate -i "$SCHEMA" -g cpp-httplib -o "$OUT"
echo "Generated C++ client in $OUT"
