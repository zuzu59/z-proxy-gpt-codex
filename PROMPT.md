# Objectif
Déployer le proxy local OpenAI-compatible `mehdic/codex-proxy` (https://github.com) dans un environnement Docker avec Docker Compose, afin d'exposer mon abonnement ChatGPT/Codex via une API HTTP locale (`/v1/chat/completions` et `/v1/responses`) sur le port `3466`.

# Architecture & Contraintes techniques
1. **Authentification déléguée à la CLI officielle :**
   - Utiliser la CLI officielle `@openai/codex` installée dans le conteneur (pas de clé API OpenAI payante).
   - La session OAuth (`~/.codex/auth.json`) doit être persistée via un volume Docker nommé pour survivre aux redémarrages et reconstructions du conteneur.
2. **Configuration réseau :**
   - `codex-proxy` écoute par défaut sur `127.0.0.1:3466`. Dans Docker, configurer `CODEX_PROXY_HOST=0.0.0.0` et `CODEX_PROXY_PORT=3466` pour permettre aux autres conteneurs/machines du réseau local (ex: containers LXC) d'y accéder.
3. **Performance & Sécurité :**
   - Utiliser le mode `CODEX_PROXY_RUNTIME=pool` avec `CODEX_PROXY_POOL_MAX=16` pour absorber des requêtes parallèles provenant de plusieurs agents.
   - Appliquer une politique sandbox conservatrice par défaut (`CODEX_PROXY_SANDBOX=read-only` et `CODEX_PROXY_APPROVAL_POLICY=never`).

# Tâches à réaliser

## 1. Créer la structure du projet
Crée un dossier `codex-proxy-docker` (ou travaille dans le répertoire courant s'il est vide) contenant :
- `Dockerfile`
- `docker-compose.yml`
- `.env.example` et `.env`
- `README.md` (avec les instructions de démarrage et d'authentification)

## 2. Rédiger le `Dockerfile`
- Image de base : `node:20-bookworm-slim`
- Installer les paquets système minimaux : `git`, `ca-certificates`, `curl` (et nettoyer le cache apt).
- Installer globalement `@openai/codex` via `npm install -g @openai/codex`.
- Cloner le dépôt `https://github.com.git` dans `/app`, installer les dépendances (`npm install`) et compiler le projet (`npm run build`).
- Exposer le port `3466` et définir `CMD ["npm", "start"]`.

## 3. Rédiger le `docker-compose.yml`
- Définir un service `codex-proxy` avec `build: .`, `container_name: codex-proxy` et `restart: unless-stopped`.
- Mapper le port `${CODEX_PROXY_PORT:-3466}:3466`.
- Charger les variables d'environnement depuis `.env` avec des valeurs par défaut sûres :
  - `CODEX_PROXY_HOST=0.0.0.0`
  - `CODEX_PROXY_PORT=3466`
  - `CODEX_PROXY_RUNTIME=pool`
  - `CODEX_PROXY_POOL_MAX=16`
  - `CODEX_PROXY_SANDBOX=read-only`
  - `CODEX_PROXY_APPROVAL_POLICY=never`
- Monter un volume nommé `codex_auth:/root/.codex` pour conserver la session OAuth.
- Ajouter un `healthcheck` Docker interrogeant `http://127.0.0`.

## 4. Construire, lancer et valider le conteneur
1. Exécute `docker compose up -d --build`.
2. Vérifie que le conteneur est en état `running` / `healthy` et que l'endpoint `curl -s http://127.0.0` répond correctement.
3. Affiche-moi clairement la commande exacte à exécuter manuellement pour finaliser la connexion OAuth navigateur (`docker exec -it codex-proxy codex login --device-auth`), puis la commande de vérification finale (`curl -s http://127.0.0z/deep`) ainsi que la configuration client (`BASE_URL=http://<IP_HOTE>:3466/v1`, `API_KEY=local`).


