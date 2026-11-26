#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: install_litllm_pi.sh <server-ip-or-hostname>" >&2
  exit 2
fi
SERVER_HOST="$1"
if [[ ! "$SERVER_HOST" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "Usage: install_litllm_pi.sh [server-ip-or-hostname]" >&2
  exit 2
fi

for cmd in curl openssl node pi; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

PI_DIR="$HOME/.pi/agent"
CERT_PATH="$PI_DIR/litellm.crt"
SETTINGS_PATH="$PI_DIR/settings.json"
mkdir -p "$PI_DIR"
chmod 700 "$PI_DIR"

TMP_CERT="$(mktemp)"
trap 'rm -f "$TMP_CERT"' EXIT
CERT_URL="http://${SERVER_HOST}:4001/litellm.crt"
if ! curl --fail --silent --show-error --location "$CERT_URL" --output "$TMP_CERT"; then
  echo "Could not download the certificate from $CERT_URL" >&2
  exit 1
fi
if [[ "$SERVER_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  openssl x509 -in "$TMP_CERT" -noout -checkip "$SERVER_HOST" >/dev/null
else
  openssl x509 -in "$TMP_CERT" -noout -checkhost "$SERVER_HOST" >/dev/null
fi
install -m 644 "$TMP_CERT" "$CERT_PATH"

API_KEY="${LITELLM_API_KEY:-}"
HAS_TTY=false
if { exec 3<>/dev/tty; } 2>/dev/null; then
  HAS_TTY=true
  if [[ -z "$API_KEY" ]]; then
    read -r -s -p "LiteLLM API key [admin]: " API_KEY <&3
    printf '\n' >&3
  fi
fi
API_KEY="${API_KEY:-admin}"

# Install the official package via Pi so it is both downloaded and registered.
if [[ "$HAS_TTY" == true ]]; then
  pi install npm:pi-provider-litellm <&3
  exec 3>&-
else
  pi install npm:pi-provider-litellm </dev/null
fi

# Merge only the required provider settings, preserving the user's other Pi settings.
node - "$SETTINGS_PATH" "$SERVER_HOST" "$API_KEY" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const [settingsPath, host, apiKey] = process.argv.slice(2);
let settings = {};
if (fs.existsSync(settingsPath)) {
  settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  if (!settings || Array.isArray(settings) || typeof settings !== 'object') {
    throw new Error(`Expected a JSON object in ${settingsPath}`);
  }
}
if (!Array.isArray(settings.packages)) settings.packages = [];
if (!settings.packages.includes('npm:pi-provider-litellm')) {
  settings.packages.push('npm:pi-provider-litellm');
}
if (!settings.litellm || typeof settings.litellm !== 'object' || Array.isArray(settings.litellm)) {
  settings.litellm = {};
}
if (!settings.litellm.providers || typeof settings.litellm.providers !== 'object' || Array.isArray(settings.litellm.providers)) {
  settings.litellm.providers = {};
}
settings.litellm.providers.litellm = {
  ...(settings.litellm.providers.litellm || {}),
  baseUrl: `https://${host}:4000`,
  apiKey,
  allowInsecureHttp: false,
};
const tempPath = `${settingsPath}.tmp`;
fs.writeFileSync(tempPath, `${JSON.stringify(settings, null, 2)}\n`, { mode: 0o600 });
fs.renameSync(tempPath, settingsPath);
fs.chmodSync(settingsPath, 0o600);
NODE

ENV_LINE="export NODE_EXTRA_CA_CERTS=\"$CERT_PATH\""
add_env_line() {
  local profile="$1"
  touch "$profile"
  if ! grep -Fqx "$ENV_LINE" "$profile"; then
    printf '\n# Trust the self-signed certificate for the LAN LiteLLM proxy\n%s\n' "$ENV_LINE" >> "$profile"
  fi
}
case "$(basename "${SHELL:-/bin/bash}")" in
  zsh)
    add_env_line "$HOME/.zshrc"
    ;;
  bash)
    add_env_line "$HOME/.bashrc"
    add_env_line "$HOME/.bash_profile"
    ;;
  *)
    add_env_line "$HOME/.profile"
    ;;
esac

printf '\nInstallation terminée. Certificat : %s\n' "$CERT_PATH"
printf 'Serveur LiteLLM : https://%s:4000\n' "$SERVER_HOST"
printf 'Ferme et rouvre ton terminal, puis lance simplement : pi\n'
