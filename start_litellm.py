"""Refresh the ChatGPT Codex catalog, write LiteLLM's config, then launch LiteLLM."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

import httpx
import yaml
from litellm.llms.chatgpt.authenticator import Authenticator
from litellm.llms.chatgpt.common_utils import get_chatgpt_default_headers

CONFIG_PATH = Path(os.getenv("LITELLM_CONFIG", "/app/litellm-config.yaml"))
CLIENT_VERSION = os.getenv("CODEX_CLIENT_VERSION", "0.166.0")


def fetch_catalog() -> list[dict[str, Any]]:
    authenticator = Authenticator()
    access_token = authenticator.get_access_token()
    headers = get_chatgpt_default_headers(access_token, authenticator.get_account_id(access_token))
    headers.update({"accept": "application/json", "user-agent": f"codex_cli_rs/{CLIENT_VERSION}"})
    response = httpx.get(
        "https://chatgpt.com/backend-api/codex/models",
        params={"client_version": CLIENT_VERSION},
        headers=headers,
        timeout=30,
    )
    response.raise_for_status()
    payload = response.json()
    models = payload.get("models") if isinstance(payload, dict) else None
    if not isinstance(models, list):
        raise RuntimeError("Unexpected ChatGPT Codex catalog response")
    return [model for model in models if isinstance(model, dict) and isinstance(model.get("slug"), str)]


def main() -> None:
    config = yaml.safe_load(CONFIG_PATH.read_text()) or {}
    models = fetch_catalog()
    if not models:
        raise RuntimeError("The ChatGPT Codex catalog contains no models")

    config["model_list"] = [
        {
            "model_name": model["slug"],
            "litellm_params": {"model": f"chatgpt/{model['slug']}"},
            "model_info": {
                "mode": "responses",
                "max_input_tokens": model.get("context_window", 272_000),
                "max_output_tokens": 32_768,
            },
        }
        for model in models
    ]
    CONFIG_PATH.write_text(yaml.safe_dump(config, sort_keys=False))
    print(f"Loaded {len(models)} ChatGPT Codex models into {CONFIG_PATH}", flush=True)
    os.execvp("litellm", ["litellm", "--config", str(CONFIG_PATH), *sys.argv[1:]])


if __name__ == "__main__":
    main()
