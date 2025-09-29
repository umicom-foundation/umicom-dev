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
: "${MISTRAL_API_KEY:?Set MISTRAL_API_KEY environment variable}"
base="${UENG_MISTRAL_BASE_URL:-https://api.mistral.ai}"
curl -sS "${base}/v1/fim/completions"       -H "Authorization: Bearer ${MISTRAL_API_KEY}"       -H "Content-Type: application/json"       -d '{"model":"codestral-latest","prompt":"def add(a,b):\n    ","suffix":"\n\nprint(add(2,3))","max_tokens":64,"temperature":0.2}'
echo
