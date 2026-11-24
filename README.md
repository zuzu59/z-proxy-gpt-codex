# LiteLLM Codex Gateway

LiteLLM lit le catalogue des modèles Codex au démarrage, génère la section `model_list` de `litellm-config.yaml`, puis expose tous ces modèles sur une seule API. Pi récupère cette liste via `/v1/models`. Chaque client Pi exécute ses outils localement.

## Démarrer le proxy

```sh
cp .env.example .env
./get_authentification.sh
./start.sh
```

Le login ChatGPT Codex se fait une seule fois côté serveur. À chaque démarrage de LiteLLM, le catalogue du compte est relu et `litellm-config.yaml` est régénéré. Pour actualiser le catalogue, relance `./start.sh`.

- API LiteLLM : `http://<IP_SERVEUR>:4000/v1`
- Console : `http://<IP_SERVEUR>:4000/ui`

Le volume `litellm-auth/` contient les jetons OAuth et est ignoré par Git. La base PostgreSQL reste dans le volume Docker `litellm_db`.

## Pi Agent : découvrir et choisir un modèle

Sur chaque client, installe l’extension une seule fois :

```sh
./install-pi-extension.sh
```

Si le dépôt n’est pas présent sur la machine cliente, copie `pi-extension/litellm-codex.ts` vers `~/.pi/agent/extensions/litellm-codex.ts`.

Dans Pi :

```text
/login litellm-codex
/model
```

À la première connexion, saisis l’URL de LiteLLM (`http://<IP_SERVEUR>:4000/v1`) et la clé API (`admin`). L’adresse n’est pas inscrite dans l’extension : elle est configurée une fois par client. `/model` affiche les modèles publiés par le proxy ; choisis celui à utiliser. Pour rafraîchir la liste après un changement du catalogue, relance d’abord `./start.sh` côté serveur, puis rouvre `/model`.

## Sécurité et vérification

Cette configuration de démonstration utilise la clé `admin` ; les ports doivent rester sur le réseau local et ne pas être exposés à Internet. Le catalogue ChatGPT interrogé est un endpoint interne non documenté, susceptible d’évoluer.

```sh
curl -fsS http://127.0.0.1:4000/health/liveliness
curl -fsS -H 'Authorization: Bearer admin' http://127.0.0.1:4000/v1/models
```

Arrêter les conteneurs sans supprimer les données :

```sh
./stop.sh
```
