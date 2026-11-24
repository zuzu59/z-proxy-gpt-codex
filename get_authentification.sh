#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p litellm-auth

echo "Connecte-toi avec le code affiché sur https://auth.openai.com/codex/device"
docker run --rm -it \
  -v "$PWD/litellm-auth:/root/.config/litellm/chatgpt" \
  --entrypoint python ghcr.io/berriai/litellm:main-stable -c \
  'from litellm.llms.chatgpt.authenticator import Authenticator; Authenticator().get_access_token()'
