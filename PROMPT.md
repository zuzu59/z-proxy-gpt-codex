# Objectif

Déployer LiteLLM avec Docker Compose pour partager une seule authentification ChatGPT Codex entre plusieurs clients Pi Agent sur le réseau local. Chaque Pi doit appeler LiteLLM pour l’inférence et conserver l’exécution de ses outils sur sa propre machine.

# Architecture

- Utiliser l’image `ghcr.io/berriai/litellm:main-stable` et le fournisseur ChatGPT/Codex natif de LiteLLM (`chatgpt/gpt-6-luna`).
- Effectuer le login OAuth par code d’appareil une seule fois sur le serveur, puis persister les jetons dans `litellm-auth/` monté sur `/root/.config/litellm/chatgpt`.
- Exposer l’API sur le port `4000` pour le LAN.
- Déployer PostgreSQL pour la console LiteLLM et persister ses données dans un volume Docker.
- Configurer une master key locale `admin` pour l’interface et l’API. Documenter clairement que ce secret faible impose de limiter le port au LAN et de ne jamais l’exposer à Internet.
- Fournir une configuration Pi `models.json` utilisant l’API OpenAI Responses à `http://<IP_SERVEUR>:4000/v1`, modèle `gpt-6-luna`.

# Fichiers attendus

- `docker-compose.yml` avec LiteLLM et PostgreSQL
- `litellm-config.yaml`
- `.env.example` et `.env` local ignoré par Git
- `.gitignore` qui exclut les jetons OAuth
- `models.json` pour Pi Agent
- `README.md` avec les étapes d’installation, d’authentification, de configuration Pi et de vérification

Ne jamais versionner les jetons OAuth, les secrets locaux ou `.env`. Ne pas déployer ni documenter d’autre proxy.
