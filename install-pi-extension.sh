#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}/extensions"
mkdir -p "$EXTENSIONS_DIR"
install -m 644 "$SCRIPT_DIR/pi-extension/litellm-codex.ts" "$EXTENSIONS_DIR/litellm-codex.ts"
printf 'Installed LiteLLM Codex provider extension to %s\n' "$EXTENSIONS_DIR/litellm-codex.ts"
