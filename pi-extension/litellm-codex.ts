import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import type { OAuthCredentials } from "@earendil-works/pi-ai";

interface GatewayCredentials extends OAuthCredentials {
  gatewayUrl: string;
}

interface LiteLLMModel {
  id: string;
  max_input_tokens?: number;
  max_output_tokens?: number;
}

function trimTrailingSlash(value: string): string {
  return value.trim().replace(/\/+$/, "");
}

export default function (pi: ExtensionAPI) {
  pi.registerProvider("litellm-codex", {
    name: "LiteLLM Codex",
    baseUrl: "http://localhost:4000/v1",
    api: "openai-responses",
    models: [],
    oauth: {
      name: "LiteLLM Codex Gateway",
      isSubscription: true,
      async login(callbacks): Promise<GatewayCredentials> {
        const gatewayUrl = trimTrailingSlash(
          await callbacks.onPrompt({
            message: "LiteLLM API base URL (including /v1)",
            placeholder: "http://<server>:4000/v1",
          }),
        );
        if (!/^https?:\/\//i.test(gatewayUrl)) throw new Error("Enter a valid HTTP(S) URL.");

        const apiKey = await callbacks.onPrompt({
          message: "LiteLLM API key",
          placeholder: "admin",
        });
        if (!apiKey) throw new Error("An API key is required.");

        return {
          type: "oauth",
          access: apiKey,
          refresh: "",
          expires: Number.MAX_SAFE_INTEGER,
          gatewayUrl,
        };
      },
      async refreshToken(credentials): Promise<GatewayCredentials> {
        return credentials as GatewayCredentials;
      },
      getApiKey(credentials): string {
        return credentials.access;
      },
    },
    async refreshModels(context): Promise<ProviderModelConfig[]> {
      const credentials = context.credential as GatewayCredentials | undefined;
      if (!credentials?.gatewayUrl || !credentials.access) return [];
      if (!context.allowNetwork || context.signal.aborted) return [];

      const response = await fetch(`${credentials.gatewayUrl}/models`, {
        headers: { Authorization: `Bearer ${credentials.access}`, Accept: "application/json" },
        signal: context.signal,
      });
      if (!response.ok) throw new Error(`LiteLLM model list request failed (${response.status}).`);
      const payload = (await response.json()) as { data?: LiteLLMModel[] };
      if (!Array.isArray(payload.data)) throw new Error("LiteLLM returned an invalid model list.");

      return payload.data
        .filter((model) => typeof model.id === "string")
        .map((model) => ({
          id: model.id,
          name: model.id,
          api: "openai-responses",
          baseUrl: credentials.gatewayUrl,
          input: ["text", "image"],
          reasoning: true,
          contextWindow: model.max_input_tokens || 272_000,
          maxTokens: model.max_output_tokens || 32_768,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        }));
    },
  });
}
