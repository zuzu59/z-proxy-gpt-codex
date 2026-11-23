# Déployer `codex-proxy` avec Docker Compose

## Objectif

Créer un déploiement Docker Compose du proxy OpenAI-compatible [`mehdic/codex-proxy`](https://github.com/mehdic/codex-proxy). Il doit exposer les API `/v1/chat/completions` et `/v1/responses` sur le port `3466` et utiliser l’authentification de la CLI officielle Codex, sans clé API OpenAI payante.

## Contraintes

- Utiliser `@openai/codex` pour l’authentification et les appels Codex.
- Persister les données d’authentification sous `/root/.codex` dans un volume Docker nommé, afin qu’elles survivent aux redémarrages et reconstructions.
- Écouter sur `0.0.0.0:3466` dans le conteneur pour permettre l’accès depuis l’hôte et le réseau Docker/LAN.
- Valeurs par défaut :
  - `CODEX_PROXY_RUNTIME=pool`
  - `CODEX_PROXY_POOL_MAX=16`
  - `CODEX_PROXY_SANDBOX=read-only`
  - `CODEX_PROXY_APPROVAL_POLICY=never`
- Ne pas inventer de nom de variable, de route de santé ou de commande : vérifier d’abord les fichiers et la documentation du dépôt amont. Si une exigence ci-dessous est incompatible avec le projet, expliquer pourquoi et proposer l’équivalent correct.

## Fichiers à créer

Créer le projet dans `codex-proxy-docker/`, sauf si le répertoire courant est vide — dans ce cas, travailler dans le répertoire courant. Fournir :

- `Dockerfile`
- `docker-compose.yml`
- `.env.example`
- `.env` (valeurs locales sûres, sans secrets)
- `README.md` avec les instructions de construction, démarrage, authentification et vérification

Ne jamais inclure de jeton OAuth ou autre secret dans les fichiers suivis par Git. Ajouter les fichiers sensibles et `.env` à `.gitignore` si nécessaire.

## Dockerfile

- Image de base : `node:20-bookworm-slim`.
- Installer uniquement les dépendances système requises, notamment `git`, `ca-certificates` et `curl`, puis nettoyer le cache APT.
- Installer globalement `@openai/codex` avec npm.
- Récupérer le dépôt amont à l’URL `https://github.com/mehdic/codex-proxy.git` dans `/app`.
- Installer les dépendances et compiler avec les commandes réellement prévues par le dépôt (vérifier `package.json` avant de choisir `npm install` ou une autre commande).
- Exposer le port `3466` et démarrer le serveur avec la commande correspondant au script de démarrage défini par le dépôt.

## Docker Compose

Définir un service `codex-proxy` avec `build: .`, `container_name: codex-proxy` et `restart: unless-stopped`.

- Publier le port configurable : `${CODEX_PROXY_PORT:-3466}:3466`.
- Charger `.env` et fournir des valeurs par défaut sûres pour les variables listées plus haut, ainsi que `CODEX_PROXY_HOST=0.0.0.0` et `CODEX_PROXY_PORT=3466`.
- Monter le volume nommé `codex_auth` sur `/root/.codex`.
- Déclarer un healthcheck uniquement après avoir identifié une route HTTP de santé valide dans le dépôt. Ne pas supposer que `/`, `/health` ou une URL tronquée fonctionne. Si aucune route adaptée n’existe, proposer une vérification réaliste et le signaler dans le README.

## Mise en œuvre et validation

1. Examiner la documentation et les scripts du dépôt amont pour confirmer les noms de variables, les commandes de build/démarrage, les routes et les exigences runtime.
2. Créer les fichiers demandés, puis expliquer brièvement les choix et toute incompatibilité constatée.
3. Si Docker est disponible, lancer `docker compose up -d --build`, puis vérifier l’état du service et les journaux en cas d’échec. Ne pas déclarer le déploiement réussi sans preuve.
4. Tester une route documentée appropriée. Avant l’authentification, distinguer clairement un service joignable d’une requête nécessitant une session OAuth valide. Ne pas supposer que `/v1/models` ou une route de santé particulière existe.
5. Ne pas tenter de finaliser une authentification navigateur interactive à la place de l’utilisateur. Fournir la commande exacte confirmée par la documentation du projet pour qu’il lance lui-même la connexion depuis son terminal. Si la commande documentée est bien celle-ci :

   ```sh
   docker exec -it codex-proxy codex login --device-auth
   ```

6. Après authentification, indiquer une commande de vérification utilisant une route réellement prise en charge. Pour un client compatible OpenAI, préciser :
   - `BASE_URL=http://<IP_HOTE>:3466/v1`
   - `API_KEY=local` (uniquement si le proxy accepte une valeur arbitraire ou n’exige pas de clé valide)

Remplacer les exemples incomplets ou mal formés par des commandes exécutables. Ne pas utiliser d’URL tronquée telle que `http://127.0.0` ou `http://127.0.0z/deep`.
