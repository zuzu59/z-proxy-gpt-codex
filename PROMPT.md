# Objectif

Déployer LiteLLM avec Docker Compose pour partager une seule authentification ChatGPT Codex entre plusieurs clients Pi Agent sur le réseau local. Chaque Pi doit appeler LiteLLM pour l’inférence et conserver l’exécution de ses outils sur sa propre machine.

# Architecture

- Utiliser l’image `ghcr.io/berriai/litellm:main-stable` et le fournisseur ChatGPT/Codex natif de LiteLLM (`chatgpt/gpt-6-luna`).
- Effectuer le login OAuth par code d’appareil une seule fois sur le serveur, puis persister les jetons dans `litellm-auth/` monté sur `/root/.config/litellm/chatgpt`.
- Exposer LiteLLM directement en HTTPS sur le port `4000` du LAN avec un certificat auto-signé. Un petit endpoint sur le port `4001` distribue uniquement le certificat public pour `wget` côté clients ; ne pas utiliser de reverse proxy ni de port inférieur à `1000`.
- Déployer PostgreSQL pour la console LiteLLM et persister ses données dans un volume Docker.
- Configurer une master key locale `admin` pour l’interface et l’API. Documenter clairement que ce secret faible impose de limiter le port au LAN et de ne jamais l’exposer à Internet.
- Au démarrage, lire le catalogue ChatGPT Codex et générer `model_list` dans `litellm-config.yaml`.
- Documenter `pi install npm:pi-provider-litellm` et l’URL `https://<IP_SERVEUR>:4000`. Garder aussi `pi-extension/litellm-codex.ts`.
- Expliquer que Node rejette les certificats auto-signés par défaut : recommander `NODE_EXTRA_CA_CERTS` avec le certificat public, sans l’installer dans le magasin système. Ne pas désactiver la vérification TLS par défaut.

# Fichiers attendus

- `docker-compose.yml` avec LiteLLM et PostgreSQL
- `litellm-config.yaml`
- `.env.example` et `.env` local ignoré par Git
- `.gitignore` qui exclut les jetons OAuth
- `start_litellm.py`, `generate-self-signed-cert.sh` et `serve_cert.py`
- `pi-extension/litellm-codex.ts` pour la découverte native personnalisée
- `models.json` sans liste statique de modèles Pi
- `README.md` avec les étapes d’installation, d’authentification, de configuration Pi et de vérification

Ne jamais versionner les jetons OAuth, les secrets locaux ou `.env`. Ne pas déployer ni documenter d’autre proxy.
