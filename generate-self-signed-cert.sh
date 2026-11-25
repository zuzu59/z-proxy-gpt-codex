#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -z "${LITELLM_DOMAIN:-}" ]]; then
  LITELLM_DOMAIN="$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
fi
if [[ -z "$LITELLM_DOMAIN" ]]; then
  echo "Could not detect the server LAN IP; set LITELLM_DOMAIN and retry." >&2
  exit 1
fi

mkdir -p tls
if [[ -s tls/litellm.crt && -s tls/litellm.key ]]; then
  echo "Using existing self-signed certificate for $LITELLM_DOMAIN."
  exit 0
fi

if [[ "$LITELLM_DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  subject_alt_name="IP:$LITELLM_DOMAIN"
else
  subject_alt_name="DNS:$LITELLM_DOMAIN"
fi

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout tls/litellm.key \
  -out tls/litellm.crt \
  -subj "/CN=$LITELLM_DOMAIN" \
  -addext "subjectAltName=$subject_alt_name"
chmod 600 tls/litellm.key
chmod 644 tls/litellm.crt
echo "Generated self-signed TLS certificate for $LITELLM_DOMAIN in tls/."
