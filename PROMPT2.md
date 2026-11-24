# Spécification de reconstruction — LiteLLM Codex Gateway

## Objectif

Construire un service local LiteLLM qui partage un unique login OAuth ChatGPT/Codex entre plusieurs Pi Agent. Le service fournit l’inférence via une API OpenAI-compatible ; les outils agentiques doivent rester exécutés par Pi sur chaque client, et non sur le serveur LiteLLM.

## Contraintes fonctionnelles

- Fournisseur LiteLLM : `chatgpt/gpt-6-luna`, interface Responses API.
- Authentification : OAuth ChatGPT/Codex par code d’appareil, réalisée une seule fois sur le serveur. Monter `litellm-auth/` vers `/root/.config/litellm/chatgpt` afin de persister et renouveler les jetons.
- Endpoint LAN : port hôte `4000`, conteneur LiteLLM sur `4000`.
- Console d’administration : `/ui`, utilisateur `admin`, master key de développement `admin`.
- PostgreSQL est requis pour la console de gestion. Le service doit attendre l’état healthy de PostgreSQL. Persister les données dans un volume Docker nommé `litellm_db`.
- Pi Agent utilise un fournisseur nommé `litellm`, `api: openai-responses`, `baseUrl: http://<IP_SERVEUR>:4000/v1`, `apiKey: admin`, modèle `gpt-6-luna`.
- Le secret `admin` est faible et destiné uniquement à un réseau local isolé. Signaler qu’il ne faut jamais exposer le port `4000` sur Internet ; restreindre l’accès au LAN avec le pare-feu.
- Aucun service ou fichier de configuration d’un autre proxy ne doit être inclus.

## Fichiers attendus

- `docker-compose.yml` : services LiteLLM et PostgreSQL, healthcheck Postgres, dépendance healthy, port 4000, volumes persistants et variables venant de `.env`.
- `litellm-config.yaml` : déclaration du modèle ChatGPT/Codex `gpt-6-luna`.
- `.env.example` : master key locale et mot de passe DB d’exemple.
- `.env` : local, ignoré par Git ; ne jamais committer secrets.
- `.gitignore` : au minimum `.env` et `litellm-auth/`.
- `litellm-auth/` : stockage local OAuth, jamais versionné.
- `models.json` : entrée du fournisseur Pi Agent, avec une IP d’exemple clairement modifiable.
- `README.md` : procédure complète de démarrage et dépannage.

## Procédure d’installation attendue

1. Vérifier les versions et la configuration LiteLLM documentées ; ne pas inventer les paramètres du fournisseur.
2. Copier `.env.example` vers `.env` et configurer les valeurs.
3. Créer `litellm-auth/`, lancer l’image LiteLLM avec une commande Python appelant `Authenticator().get_access_token()`, puis demander à l’utilisateur de saisir le code sur `https://auth.openai.com/codex/device`.
4. Démarrer avec `docker compose up -d`, vérifier la santé LiteLLM/PostgreSQL, la découverte de `gpt-6-luna` et une requête réelle.
5. Installer ou fusionner `models.json` dans `~/.pi/agent/models.json` sur chaque client. Préserver les autres fournisseurs configurés.
6. Vérifier qu’un tool call est renvoyé à Pi pour exécution locale ; ne pas prétendre que les outils locaux ont été validés uniquement par un test d’inférence du serveur.
7. Ne jamais supprimer les volumes persistants contenant base de données ou jetons sans autorisation explicite.
