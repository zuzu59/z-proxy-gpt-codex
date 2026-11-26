# Architecture technique

## Objectif

Le dépôt déploie un point d’accès LiteLLM partagé pour un compte
ChatGPT/Codex. L’authentification amont est centralisée sur le serveur.
Plusieurs clients Pi
peuvent utiliser ce compte via l’API LiteLLM, tandis que leurs outils locaux
(terminal, lecture et écriture de fichiers, etc.) restent exécutés sur chaque
client.

L’intégration Pi repose sur le package officiel `pi-provider-litellm`.
Le dépôt ne contient plus d’extension Pi personnalisée.

## Vue d’ensemble

```text
Client Pi
  ├─ package pi-provider-litellm
  ├─ clé API LiteLLM dans les paramètres Pi
  ├─ certificat public dans ~/.pi/agent/litellm.crt
  └─ outils Pi exécutés localement
          │ HTTPS :4000
          ▼
     LiteLLM (Docker)
       ├─ authentification API par master key
       ├─ catalogue généré au démarrage
       └─ requêtes ChatGPT/Codex
                │ HTTPS amont
                ▼
        ChatGPT/Codex

Client d’installation ── HTTP :4001 ──► cert-download
                                         ├─ certificat public
                                         └─ installateur Pi

LiteLLM ── PostgreSQL :5432 (réseau Compose interne)
```

Les trois services Compose sont décrits dans `docker-compose.yml` :

- `litellm` : API, console et modèles Codex, publiés en HTTPS sur `4000`.
- `cert-download` : téléchargement du certificat et du script Pi via HTTP sur
  `4001`.
- `litellm-db` : base LiteLLM, accessible uniquement dans le réseau Compose.

LiteLLM attend que le healthcheck PostgreSQL soit valide. Le service de
certificat est indépendant ; `start.sh` génère les fichiers TLS avant de
recréer les deux services publiés.

## Composants et responsabilités

### Authentification ChatGPT/Codex

`get_authentification.sh` lance un conteneur ponctuel de l’image LiteLLM et
appelle son authentificateur ChatGPT. Le navigateur reçoit le parcours de
connexion par code d’appareil. Les jetons obtenus sont écrits sur l’hôte
sous `litellm-auth/`.

Le service LiteLLM monte ce dossier dans le conteneur à
`/root/.config/litellm/chatgpt`. Les clients Pi ne reçoivent jamais ces jetons
amont ; ils utilisent uniquement la clé d’accès LiteLLM.

### Génération du catalogue et démarrage LiteLLM

Compose exécute `start_litellm.py` à la place de l’entrée standard de
l’image. Le script :

1. lit `litellm-config.yaml` ;
2. charge les jetons via l’authentificateur LiteLLM ;
3. obtient l’identifiant du compte et construit les en-têtes Codex ;
4. appelle l’API `https://chatgpt.com/backend-api/codex/models` avec
   `CODEX_CLIENT_VERSION` ;
5. transforme les modèles reçus en entrées LiteLLM ;
6. réécrit `model_list` dans le YAML monté, puis remplace le processus Python
   par `litellm --config ...`.

Chaque entrée générée utilise le slug Codex comme nom public et
`chatgpt/<slug>` comme modèle amont. Le mode LiteLLM est `responses`. La
fenêtre de contexte vient de `context_window` ; si elle est absente, le script
utilise `272000`. La limite de sortie est fixée à `32768` tokens.

`litellm-config.yaml` contient un catalogue initial, mais `start_litellm.py`
remplace `model_list` à chaque démarrage réussi. Les autres paramètres YAML,
dont `litellm_settings.drop_params`, sont conservés.
Le catalogue n’est pas interrogé à chaque requête. Une erreur OAuth ou
réseau, un statut HTTP invalide ou une réponse mal formée empêche LiteLLM
de démarrer. La politique
`restart: unless-stopped` de Compose peut alors redémarrer le conteneur.

### API LiteLLM et PostgreSQL

Le processus LiteLLM écoute sur `0.0.0.0:4000` avec TLS activé par les options
`--ssl_keyfile_path` et `--ssl_certfile_path`. L’API et la console partagent
cette origine HTTPS.

L’API exige `LITELLM_MASTER_KEY`. Les clients envoient cette clé comme clé
API LiteLLM. Le service configure également
`LITELLM_DANGEROUSLY_PERMIT_WEAK_OR_UNSET_MASTER_KEY=true`. Cette option,
combinée à la valeur de démonstration `admin`, est risquée si le service est
accessible depuis d’autres réseaux.

PostgreSQL 16 stocke l’état de gestion LiteLLM dans le volume nommé
`litellm_db`. La base n’est pas publiée sur un port hôte ; LiteLLM la joint
par le nom de service `litellm-db`. Son mot de passe provient de
`LITELLM_DB_PASSWORD`.

### HTTPS et certificat auto-signé

`generate-self-signed-cert.sh` crée une clé RSA 2048 et un certificat
auto-signé valable 3650 jours. Le certificat porte un SAN de type IP ou DNS,
selon `LITELLM_DOMAIN`. Les fichiers sont créés sous `tls/` :

- `tls/litellm.key` : clé privée, permissions `600` ;
- `tls/litellm.crt` : certificat public, permissions `644`.

`start.sh` utilise `LITELLM_DOMAIN` si cette variable est fournie ; sinon, il
lit l’adresse source de la route IPv4 vers `1.1.1.1`. Le certificat est
réutilisé si les deux fichiers existent. Le script ne vérifie pas que le SAN
du certificat existant correspond à la nouvelle adresse. Après changement
d’adresse, il faut donc supprimer les deux fichiers puis relancer le
démarrage.

Le client télécharge le certificat et utilise `NODE_EXTRA_CA_CERTS` pour que
Node.js et le package Pi vérifient le certificat HTTPS. Cela évite de
désactiver globalement la validation TLS, mais ne sécurise pas le
téléchargement initial du certificat.

### Distribution client

`serve_cert.py` est un serveur HTTP standard-library, exposé sur `4001`. Il
utilise une liste blanche stricte :

- `/litellm.crt` sert le certificat public ;
- `/install_litllm_pi.sh` sert le script d’installation ;
- les autres chemins renvoient `404`.

Le conteneur `cert-download` monte ces deux fichiers en lecture seule. Il ne
monte pas le répertoire `tls/` et n’a pas accès à `litellm.key`.

`install_litllm_pi.sh` exige une adresse IP ou un nom d’hôte comme argument.
Il vérifie la présence de `curl`, `openssl`, `node` et `pi`, télécharge le
certificat en HTTP puis contrôle son SAN avec OpenSSL. Il installe le package
`pi-provider-litellm`, fusionne les paramètres du fournisseur dans
`~/.pi/agent/settings.json` et configure `NODE_EXTRA_CA_CERTS` pour le shell.
La clé API est enregistrée dans ce fichier avec les autres réglages Pi, qui
sont conservés. Le fichier est protégé avec les permissions `600`.

## Flux de requête

1. Pi charge `pi-provider-litellm` et lit l’URL ainsi que la clé depuis
   `~/.pi/agent/settings.json`.
2. Pi établit une connexion HTTPS vers le port `4000` et appelle LiteLLM.
3. LiteLLM authentifie la clé API avec `LITELLM_MASTER_KEY`.
4. Le slug public sélectionné est résolu vers `chatgpt/<slug>` dans le
   catalogue construit au démarrage.
5. LiteLLM utilise les jetons OAuth conservés côté serveur pour appeler
   ChatGPT/Codex et renvoie la réponse au client Pi.
6. Les outils Pi demandés sont exécutés par le client, sur sa machine.

## Configuration et données persistantes

- `.env` : secrets du serveur ; fichier local exclu de Git.
- `litellm-auth/` : jetons OAuth, montés dans le conteneur LiteLLM.
- `tls/` : certificat et clé TLS, dossier hôte exclu de Git.
- `litellm-config.yaml` : catalogue LiteLLM, réécrit au démarrage.
- `litellm_db` : volume Docker persistant pour PostgreSQL.
- `~/.pi/agent/settings.json` : réglages du client Pi, mode `600`.
- `~/.pi/agent/litellm.crt` : certificat public installé sur le client.

`.gitignore` exclut `.env`, `litellm-auth/` et `tls/`. Cette exclusion évite
certains ajouts accidentels, mais ne chiffre pas les données locales et ne
remplace pas les permissions ou la sécurité du système hôte.

`stop.sh` exécute `docker compose down`. Les conteneurs sont arrêtés et
supprimés, mais le volume PostgreSQL et les répertoires hôtes persistent.
`docker compose down -v` supprimerait aussi le volume de base de données.

## Ports et frontières de confiance

- `4000` / HTTPS : API LiteLLM et console, protégées par la clé LiteLLM.
- `4001` / HTTP : certificat public et installateur, sans authentification.
- `5432` / TCP interne : PostgreSQL, avec identifiants de base.

Le port `4001` n’est pas authentifié et transporte le script ainsi que le
certificat en clair. Un appareil capable d’intercepter le trafic LAN pourrait
les remplacer. Le contrôle SAN effectué par l’installateur vérifie que le
certificat correspond au nom ou à l’adresse fournie ; il ne prouve pas que
le certificat téléchargé appartient au serveur légitime. L’installation
initiale est donc réservée à un réseau local de confiance.

Le port `4000` chiffre les requêtes après l’installation du certificat.
Chaque client qui connaît la clé partagée peut appeler l’API. La valeur
d’exemple `admin` est faible. Ne publie pas ces ports sur Internet sans
renforcer l’authentification, le contrôle d’accès et le TLS.

## Limites et hypothèses opérationnelles

- `/backend-api/codex/models` est une API ChatGPT/Codex interne, sans contrat
  public garanti ; son format ou ses en-têtes peuvent changer.
- `CODEX_CLIENT_VERSION` doit rester compatible avec le protocole amont.
- L’image Docker `ghcr.io/berriai/litellm:main-stable` est une étiquette
  mobile, pas une version immuable épinglée.
- Le catalogue est actualisé au démarrage ; les nouveaux modèles ne sont pas
  découverts en temps réel pendant que le conteneur fonctionne.
- Les clients, le serveur, les jetons OAuth et la base de données sont
  supposés protégés par le réseau local et les permissions des hôtes.
- Le serveur requiert une route IPv4 pour détecter son adresse par défaut,
  ou une valeur explicite de `LITELLM_DOMAIN`.

## Fichiers principaux

- `docker-compose.yml` : services, ports, volumes et variables de conteneur.
- `start.sh` : préparation TLS et démarrage des services exposés.
- `start_litellm.py` : récupération du catalogue et lancement LiteLLM.
- `litellm-config.yaml` : réglages LiteLLM conservés et catalogue initial.
- `get_authentification.sh` : connexion OAuth initiale côté serveur.
- `generate-self-signed-cert.sh` : création du certificat auto-signé.
- `serve_cert.py` : serveur HTTP à chemins autorisés sur le port `4001`.
- `install_litllm_pi.sh` : installation et configuration d’un client Pi.
- `stop.sh` : arrêt des conteneurs sans suppression du volume PostgreSQL.
