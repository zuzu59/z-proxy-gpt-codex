# LiteLLM Codex Gateway

Ce projet déploie sur un réseau local un proxy LiteLLM qui partage un compte
ChatGPT/Codex entre plusieurs clients. L’authentification OAuth reste sur le
serveur ; les agents exécutent leurs outils sur leur propre ordinateur.

Le catalogue des modèles Codex est récupéré au démarrage du proxy et exposé
par l’API LiteLLM. Il n’est pas nécessaire de maintenir une liste de modèles
manuellement dans chaque client.

## Guides clients

- Installer et utiliser le proxy : ce document.
- Configurer Pi Agent : [guide Pi][guide-pi].
- Configurer OpenCode : [guide OpenCode][guide-opencode].

## Architecture et ports

Exemple d’adresse LAN du serveur : `192.168.0.92`.

| Service | Adresse | Usage |
| --- | --- | --- |
| API et console LiteLLM | `https://192.168.0.92:4000` | API, `/ui` |
| Téléchargement | `http://192.168.0.92:4001` | Certificat et installateur Pi |
| PostgreSQL | réseau Docker uniquement | État de gestion LiteLLM |

LiteLLM sert directement HTTPS sur le port `4000` avec un certificat
auto-signé. Le serveur HTTP du port `4001` ne sert que deux chemins autorisés :
`/litellm.crt` et `/install_litllm_pi.sh`. Il ne monte jamais la clé privée.
PostgreSQL n’est pas publié sur le réseau hôte ; ses données résident dans le
volume Docker `litellm_db`.

## Installer le proxy

Effectue ces étapes sur l’ordinateur qui hébergera le proxy. Il faut Docker
avec Compose, OpenSSL et la commande `ip`.

### 1. Récupérer le projet et préparer les secrets

```sh
git clone https://github.com/zuzu59/z-proxy-gpt-codex.git
cd z-proxy-gpt-codex
cp .env.example .env
```

Modifie `.env` avant le premier démarrage :

- remplace `LITELLM_MASTER_KEY=admin` par une clé forte et privée ;
- choisis un mot de passe PostgreSQL pour `LITELLM_DB_PASSWORD`.

Attention : Compose active aussi
`LITELLM_DANGEROUSLY_PERMIT_WEAK_OR_UNSET_MASTER_KEY=true` pour le mode de
démonstration. Si tu remplaces `admin` par une clé forte, désactive ce
paramètre dans `docker-compose.yml` (ou retire-le), puis vérifie que LiteLLM
démarre correctement. Ne conserve pas cette option sur un serveur exposé.

Si la base existe déjà, conserve le mot de passe PostgreSQL qui lui
correspond. Changer uniquement `.env` ne change pas le mot de passe d’un
volume déjà initialisé.

Ne versionne jamais `.env`, `litellm-auth/` ou `tls/litellm.key`.

### 2. Connecter le compte ChatGPT/Codex

Sur le serveur, lance le flux OAuth par code d’appareil :

```sh
./get_authentification.sh
```

Suis les instructions affichées et connecte le compte qui possède les modèles
à partager. Les jetons sont conservés localement dans `litellm-auth/` ; ils ne
sont pas transmis aux clients.

### 3. Démarrer LiteLLM

```sh
./start.sh
```

Le script détecte l’adresse LAN, crée le certificat s’il n’existe pas, puis
démarre LiteLLM, PostgreSQL et le serveur de téléchargement. Il affiche les
adresses des services.

Si l’adresse détectée est incorrecte, indique-la explicitement :

```sh
LITELLM_DOMAIN=192.168.0.92 ./start.sh
```

Au démarrage, `start_litellm.py` actualise le catalogue depuis l’API Codex et
régénère `model_list` dans `litellm-config.yaml`. Ne maintiens pas cette liste
à la main : elle est remplacée par le catalogue du compte.

### 4. Vérifier le déploiement

```sh
docker compose ps
docker compose logs -f litellm
```

Pour vérifier l’accès depuis un client, utilise les instructions de test
spécifiques à l’agent : [Pi][guide-pi] ou [OpenCode][guide-opencode]. Elles
montrent comment présenter le certificat public et la clé configurée dans
`LITELLM_MASTER_KEY`.

## Certificat et changement d’adresse

Le certificat auto-signé est généré pour l’adresse IP ou le nom indiqué par
`LITELLM_DOMAIN`. Les fichiers restent dans `tls/`. Si l’adresse change,
supprime le certificat et sa clé, puis redémarre avec la nouvelle adresse :

```sh
rm -f tls/litellm.crt tls/litellm.key
LITELLM_DOMAIN=192.168.0.50 ./start.sh
```

Ne partage jamais `tls/litellm.key`. Le certificat public peut être téléchargé
à `http://<serveur>:4001/litellm.crt`.

## Sécurité

- Ce déploiement est prévu pour un réseau local de confiance, pas pour être
  exposé directement à Internet.
- Docker publie par défaut les ports `4000` et `4001` sur toutes les
  interfaces réseau de l’hôte. Restreins-les avec le pare-feu ou limite leur
  publication à l’adresse LAN ; ne les laisse pas accessibles depuis Internet.
- Le port `4001` utilise HTTP sans authentification. Le téléchargement initial
  du certificat et du script n’est pas protégé contre un appareil malveillant
  présent sur le même réseau.
- La clé LiteLLM donne accès au proxy. Utilise une valeur forte et protège-la.
- L’API amont `/backend-api/codex/models` est interne et non garantie comme
  stable ; le format peut évoluer.
- N’utilise pas `NODE_TLS_REJECT_UNAUTHORIZED=0` pour contourner les erreurs
  de certificat des clients.

`./stop.sh` arrête les conteneurs sans supprimer le volume PostgreSQL. Ne
lance pas `docker compose down -v` sauf si tu souhaites effacer la base.

## Documentation connexe

- [Architecture technique][architecture] décrit les services, flux, limites
  et frontières de confiance.
- [Guide Pi][guide-pi] couvre l’installation et l’utilisation côté client.
- [Guide OpenCode][guide-opencode] couvre le plugin LiteLLM et la découverte
  des modèles.

[architecture]: ARCHITECTURE.md
[guide-pi]: README_PI.md
[guide-opencode]: README_OPENCODE.md
