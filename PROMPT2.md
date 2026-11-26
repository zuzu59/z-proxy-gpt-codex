# Spécification de reconstruction — LiteLLM Codex Gateway

## Objectif

Construire un service local LiteLLM qui partage un unique login OAuth ChatGPT/Codex entre plusieurs Pi Agent. Le service fournit l’inférence via une API OpenAI-compatible ; les outils agentiques doivent rester exécutés par Pi sur chaque client, et non sur le serveur LiteLLM.

## Contraintes fonctionnelles

- Fournisseur LiteLLM : catalogue Codex dynamique récupéré au démarrage ; créer un alias pour chaque slug via Responses API.
- Authentification : OAuth ChatGPT/Codex par code d’appareil, réalisée une seule fois sur le serveur. Monter `litellm-auth/` vers `/root/.config/litellm/chatgpt` afin de persister et renouveler les jetons.
- Endpoint LAN : LiteLLM sert HTTPS directement sur le port hôte/conteneur `4000`, avec un certificat auto-signé. Un minuscule serveur HTTP sur le port `4001` ne distribue que le certificat public pour permettre `wget` côté clients. Ne pas ajouter Caddy, Nginx, reverse proxy ou port inférieur à `1000`.
- Console d’administration : `/ui`, utilisateur `admin`, master key de développement `admin`.
- PostgreSQL est requis pour la console de gestion. Le service doit attendre l’état healthy de PostgreSQL. Persister les données dans un volume Docker nommé `litellm_db`.
- Au démarrage, `start_litellm.py` lit le catalogue du compte ChatGPT Codex et régénère le `model_list` de `litellm-config.yaml`.
- Pi utilise uniquement le package officiel `pi-provider-litellm`, avec `https://<IP_SERVEUR>:4000` et `/login litellm`.
- Le certificat auto-signé n’est pas accepté par Node par défaut. Documenter `NODE_EXTRA_CA_CERTS` pointant vers le certificat public pour faire confiance sans modifier le magasin système. Ne jamais désactiver la validation TLS globalement par défaut.
- Le secret `admin` est faible et destiné uniquement à un réseau local isolé. Signaler qu’il ne faut jamais exposer le port `4000` sur Internet ; restreindre l’accès au LAN avec le pare-feu.
- Aucun service ou fichier de configuration d’un autre proxy ne doit être inclus.

## Fichiers attendus

- `docker-compose.yml` : services LiteLLM et PostgreSQL, healthcheck Postgres, dépendance healthy, port 4000 avec TLS, certificat/key montés en lecture seule et volumes persistants.
- `generate-self-signed-cert.sh` : génération d’un certificat SAN correspondant à l’IP ou au nom LAN.
- `serve_cert.py` : serveur de téléchargement qui ne sert que `litellm.crt` sur le port 4001, jamais la clé privée.
- `start.sh` : détecte l’adresse LAN, crée le certificat à la première exécution et relance le proxy pour régénérer le catalogue.
- `litellm-config.yaml` : configuration de base que `start_litellm.py` complète avec les modèles disponibles.
- `.env.example` : master key locale et mot de passe DB d’exemple.
- `.env` : local, ignoré par Git ; ne jamais committer secrets.
- `.gitignore` : au minimum `.env` et `litellm-auth/`.
- `litellm-auth/` : stockage local OAuth, jamais versionné.
- `install_litllm_pi.sh` : installateur client appelé par une commande `curl | bash`, télécharge le certificat, installe le package Pi officiel, fusionne les paramètres requis dans `settings.json` sans écraser le reste et configure `NODE_EXTRA_CA_CERTS`.
- `README.md` : procédure de démarrage et commande `curl | bash` complète pour les clients Pi.

## Procédure d’installation attendue

1. Vérifier les versions et la configuration LiteLLM documentées ; ne pas inventer les paramètres du fournisseur.
2. Copier `.env.example` vers `.env` et configurer les valeurs.
3. Créer `litellm-auth/`, lancer l’image LiteLLM avec `Authenticator().get_access_token()` et demander le code sur `https://auth.openai.com/codex/device`.
4. Lancer `./start.sh` : générer si nécessaire le certificat SAN auto-signé, récupérer le catalogue, lancer LiteLLM sur HTTPS/4000 et le serveur de certificat sur 4001.
5. Sur chaque client, exécuter la commande documentée `curl | bash` pour lancer `install_litllm_pi.sh` ; celui-ci télécharge et valide le certificat par rapport à l’IP, installe `pi-provider-litellm`, fusionne `litellm.providers.litellm` dans `settings.json`, demande la clé API, et ajoute `NODE_EXTRA_CA_CERTS` au profil shell. Après ouverture d’un nouveau terminal, Pi doit démarrer directement avec `pi`.
6. Vérifier `/v1/models`, une vraie requête HTTPS et l’exécution locale d’un outil Pi.
7. Ne jamais supprimer les volumes persistants contenant base de données ou jetons sans autorisation explicite.
