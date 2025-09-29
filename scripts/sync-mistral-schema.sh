#!/usr/bin/env bash
set -euo pipefail
SRC="third_party/api-schemas/mistral/openapi.yaml"
AE="umicom-authorengine-ai/docs/api/mistral"
STUDIO="umicom-studio-ide/docs/api/mistral"
[ -f "$SRC" ] || { echo "Spec not found: $SRC" >&2; exit 1; }
mkdir -p "$AE" "$STUDIO"
cp "$SRC" "$AE/openapi.yaml"
cp "$SRC" "$STUDIO/openapi.yaml"
echo "Synced to: $AE and $STUDIO"
