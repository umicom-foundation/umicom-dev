#!/usr/bin/env bash
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "Usage: $0 <MISTRAL_API_KEY>" >&2
  exit 1
fi
KEY="$1"
shell_rc="${HOME}/.bashrc"
if [ -n "${ZSH_VERSION:-}" ]; then shell_rc="${HOME}/.zshrc"; fi
if ! grep -q "MISTRAL_API_KEY" "$shell_rc" 2>/dev/null; then
  echo "export MISTRAL_API_KEY=${KEY}" >> "$shell_rc"
else
  sed -i.bak -E "s|export MISTRAL_API_KEY=.*|export MISTRAL_API_KEY=${KEY}|g" "$shell_rc"
fi
echo "Key saved to $shell_rc. Run: source $shell_rc"
