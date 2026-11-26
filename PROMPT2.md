# Spécification de reconstruction — LiteLLM Codex Gateway

## Contexte et objectif

Construire et maintenir un proxy LiteLLM local qui partage une authentification
ChatGPT/Codex centralisée entre plusieurs clients Pi. Le serveur gère OAuth et
l’inférence. Chaque client Pi exécute ses outils sur sa propre machine.

Avant de modifier le dépôt, inspecter son état et ses fichiers actuels.
Adapter la solution existante ; ne pas recréer aveuglément des fichiers déjà
présents ni restaurer d’anciens composants supprimés.

## Architecture cible

- Docker Compose orchestre l’image `ghcr.io/berriai/litellm:main-stable`,
  PostgreSQL et un serveur de téléchargement minimal.
- LiteLLM sert l’API et la console directement en HTTPS sur le port `4000`.
- Le service de téléchargement sert en HTTP sur le port `4001` uniquement le
  certificat public et l’installateur Pi. Il ne doit jamais accéder à la
  clé privée TLS.
- PostgreSQL est accessible uniquement dans le réseau Compose et conserve
  ses données dans le volume Docker `litellm_db`.
- Pi utilise le package officiel `pi-provider-litellm`. Ne pas réintroduire
  d’extension Pi personnalisée, de service catalogue supplémentaire ou de
  configuration client statique `models.json`.
- Les outils Pi (terminal, accès aux fichiers, etc.) restent exécutés sur
  chaque client, jamais sur le serveur LiteLLM.

N’ajouter aucun reverse proxy ni port inférieur à `1000`.

## Authentification et découverte des modèles

- Effectuer le login OAuth ChatGPT/Codex une seule fois sur le serveur, avec le
  flux par code d’appareil. Persister les jetons dans `litellm-auth/`, monté
  dans le conteneur sous `/root/.config/litellm/chatgpt`.
- Ne jamais exposer ni copier ces jetons OAuth vers les clients Pi.
- Au démarrage de LiteLLM, `start_litellm.py` doit récupérer le catalogue du
  compte et régénérer `model_list` dans `litellm-config.yaml` avant de lancer
  LiteLLM.
- L’endpoint amont observé est
  `https://chatgpt.com/backend-api/codex/models`. C’est une API interne, non
  garantie comme stable. Construire les en-têtes avec l’authentificateur
  LiteLLM et `CODEX_CLIENT_VERSION`, puis valider la réponse avant
  de l’utiliser.
- Pour chaque slug reçu, exposer le slug comme nom LiteLLM et router vers
  `chatgpt/<slug>` en mode `responses`. Utiliser `context_window` si présent,
  sinon `272000`, et définir la limite de sortie à `32768` tokens.
- Réécrire uniquement `model_list` et préserver les autres paramètres YAML,
  notamment `litellm_settings.drop_params`. Ne pas faire dépendre la liste
  effective d’un catalogue statique ou de modifications manuelles de Pi.
- Si le login, le réseau, le statut HTTP ou le format du catalogue échoue,
  signaler l’erreur et ne pas lancer LiteLLM avec une liste présentée comme
  actualisée.

## TLS et distribution du certificat

- Générer un certificat auto-signé avec SAN IP ou DNS correspondant à
  `LITELLM_DOMAIN`. La clé privée `tls/litellm.key` doit rester locale, avec
  des permissions restrictives. Le certificat public est `tls/litellm.crt`.
- `start.sh` accepte `LITELLM_DOMAIN` ou détecte l’adresse LAN par défaut,
  génère le certificat s’il manque, puis démarre LiteLLM et le service de
  téléchargement.
- Le script de certificat réutilise les fichiers existants sans vérifier
  leur SAN. Documenter qu’après un changement d’adresse il faut supprimer
  `tls/litellm.crt` et `tls/litellm.key`, puis redémarrer.
- Activer TLS directement dans LiteLLM sur le port `4000` avec les chemins de
  certificat et de clé. Ne pas désactiver la validation TLS dans Pi.
- Le serveur `serve_cert.py` utilise une liste blanche exacte :
  `/litellm.crt` et `/install_litllm_pi.sh`. Tout autre chemin renvoie `404`.
  Monter uniquement le certificat public et le script, en lecture seule.
- L’installation client place le certificat sous
  `~/.pi/agent/litellm.crt` et configure `NODE_EXTRA_CA_CERTS`. Ne pas
  recommander `NODE_TLS_REJECT_UNAUTHORIZED=0`.
- Le port `4001` utilise HTTP sans authentification. Avertir que le
  téléchargement initial du script et du certificat n’est sûr que sur un
  réseau local de confiance ; le contrôle SAN ne prouve pas l’identité du
  serveur quand le certificat est reçu en clair.

## API, console et secrets

- Exiger `LITELLM_MASTER_KEY` pour l’API et la console LiteLLM.
- PostgreSQL doit être `healthy` avant le démarrage de LiteLLM. Lire le secret
  DB depuis `LITELLM_DB_PASSWORD` et le conserver cohérent avec le volume.
- Les valeurs d’exemple `LITELLM_MASTER_KEY=admin` et le flag
  `LITELLM_DANGEROUSLY_PERMIT_WEAK_OR_UNSET_MASTER_KEY=true` sont faibles et
  réservés à un LAN contrôlé. Documenter le risque ; ne jamais exposer le
  service sur Internet.
- Le client reçoit uniquement la clé API LiteLLM. L’installateur la demande
  (valeur par défaut de démonstration : `admin`) puis l’enregistre dans
  `~/.pi/agent/settings.json` avec les permissions `600`.
- Ne jamais versionner `.env`, `litellm-auth/`, `tls/litellm.key` ou tout jeton.
  `.gitignore` doit exclure `.env`, `litellm-auth/` et `tls/`.

## Installation Pi

`install_litllm_pi.sh` doit exiger exactement un argument : adresse IP ou nom
DNS du serveur. Ne jamais coder une adresse IP par défaut dans le script.
Le script doit vérifier ses dépendances (`curl`, `openssl`, `node`, `pi`),
télécharger le certificat via le port `4001`, contrôler son SAN, installer
`npm:pi-provider-litellm`, puis fusionner les paramètres dans
`~/.pi/agent/settings.json` sans écraser les autres réglages.

Exemple d’installation client :

```sh
IP=adresse-ip-ou-dns-du-serveur
curl -fsSL "http://$IP:4001/install_litllm_pi.sh" | bash -s -- "$IP"
```

Configurer `litellm.providers.litellm` avec l’URL `https://<serveur>:4000`, la
clé API fournie par l’utilisateur et `allowInsecureHttp: false`. Après
l’installation, un nouveau terminal doit suffire pour lancer `pi` et choisir
un modèle avec `/model`. Aucun `/login` Pi supplémentaire n’est requis pour
cette configuration par paramètres.

## Fichiers du projet

Maintenir les fichiers suivants à la racine du dépôt :

- `docker-compose.yml` : LiteLLM, PostgreSQL, service de téléchargement,
  ports, variables et volumes ;
- `litellm-config.yaml` : paramètres LiteLLM et catalogue initial ;
- `start_litellm.py` : récupération du catalogue et lancement du proxy ;
- `get_authentification.sh` : login OAuth initial côté serveur ;
- `start.sh` et `stop.sh` : démarrage et arrêt sans supprimer les volumes ;
- `generate-self-signed-cert.sh` : création du certificat TLS ;
- `serve_cert.py` : distribution HTTP par liste blanche ;
- `install_litllm_pi.sh` : installation d’un client Pi ;
- `.env.example` et `.gitignore` ;
- `README.md` : guide utilisateur en français ;
- `ARCHITECTURE.md` : documentation technique en français ;
- `PROMPT2.md` : présente spécification de reconstruction.

Ne pas supprimer ou recréer les jetons OAuth, les certificats, `.env` ou le
volume PostgreSQL sans autorisation explicite. `docker compose down` doit
conserver le volume ; ne pas utiliser `docker compose down -v` par défaut.

## Vérifications de livraison

Avant de terminer :

1. Valider `docker compose config`, la syntaxe des scripts Bash et Python, et
   le YAML généré.
2. Vérifier que le catalogue est récupéré et que LiteLLM démarre en HTTPS
   sur `4000`, avec PostgreSQL `healthy`.
3. Vérifier l’accès authentifié à `/v1/models` et une vraie requête
   Responses, sans afficher les jetons OAuth dans la sortie.
4. Vérifier que `4001` sert exactement les deux chemins autorisés, que les
   autres renvoient `404` et que la clé privée n’est pas montée dans le
   conteneur de téléchargement.
5. Tester l’installateur dans un environnement Pi isolé : paramètres
   préexistants préservés, argument requis, certificat configuré et aucun IP
   codé en dur dans le script.
6. Vérifier avec Pi que `/model` présente le catalogue, qu’une requête
   aboutit et que les outils s’exécutent sur la machine cliente.
7. Mettre à jour `README.md` et `ARCHITECTURE.md` si le comportement change.
8. Rapporter les tests réellement exécutés et les limites restantes.
