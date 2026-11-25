#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -z "${LITELLM_DOMAIN:-}" ]]; then
  LITELLM_DOMAIN="$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
fi
if [[ -z "$LITELLM_DOMAIN" ]]; then
  echo "Could not detect the server LAN address; set LITELLM_DOMAIN and retry." >&2
  exit 1
fi
export LITELLM_DOMAIN

./generate-self-signed-cert.sh
docker compose up -d --remove-orphans --force-recreate litellm cert-download
printf 'HTTPS LiteLLM URL: https://%s:4000\n' "$LITELLM_DOMAIN"
printf 'Certificate download: http://%s:4001/litellm.crt\n' "$LITELLM_DOMAIN"
