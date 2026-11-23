# z-proxy-gpt-codex

Petit proxy GPT Codex pour utilisation sur son réseau local afin de simplifier la connexion de ses différentes machines.

## Utiliser le proxy depuis Pi Agent

Le fichier [`models.json`](models.json) de ce dépôt configure Pi pour accéder au proxy à l’adresse d’exemple `http://192.168.0.92:3000/v1` avec le modèle `gpt-6-luna`.

Sur la machine où Pi Agent s’exécute, installe cette configuration dans son répertoire global :

```sh
mkdir -p ~/.pi/agent
cp models.json ~/.pi/agent/models.json
```

Si `~/.pi/agent/models.json` existe déjà, ne l’écrase pas : fusionne plutôt l’entrée `codex-proxy` du fichier fourni dans l’objet `providers` existant et conserve les autres fournisseurs. Dans un conteneur Pi exécuté en tant que `root`, le chemin correspondant est `/root/.pi/agent/models.json`.

Redémarre Pi Agent, exécute `/model`, puis sélectionne **GPT-6 Luna via Codex Proxy**. La clé `local` est une valeur de compatibilité ; le proxy ne vérifie pas de clé API. Vérifie que l’IP d’exemple correspond bien à l’adresse locale de la machine hébergeant Docker et que le port `3000` est accessible depuis la machine Pi.

## Déploiement Docker Compose

Ce dépôt construit [mehdic/codex-proxy](https://github.com/mehdic/codex-proxy) depuis sa branche par défaut dans une image Node 20. L’API est publiée sur le port `3000` de l’hôte (et écoute sur `3466` dans le conteneur) ; les données Codex sont conservées dans le volume nommé `codex_auth`.

> **Sécurité :** le proxy écoute sur toutes les interfaces et ne fournit pas d’authentification API intégrée. Ne publiez pas le port sur un réseau non fiable ou sur Internet. Restreignez l’accès avec le pare-feu/réseau de l’hôte ou ajoutez une couche d’authentification.

### Démarrer

Le fichier `.env` local est fourni avec les valeurs par défaut. Pour le recréer après un clone :

```sh
cp .env.example .env
```

Puis, depuis la racine du dépôt :

```sh
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:3000/health
```

Le healthcheck utilise `GET /health`, route de liveness documentée par le projet amont. Il confirme que le serveur HTTP répond, mais ne valide pas l’authentification Codex. `GET /healthz/deep` effectue un vrai tour Codex et peut consommer du quota.

### Authentifier Codex

La CLI officielle est installée dans l’image et son état est monté dans `/root/.codex`. Lancez l’authentification interactive dans un terminal :

```sh
docker exec -it codex-proxy codex login --device-auth
```

Si cette option n’est pas reconnue par la version de la CLI installée, consultez `docker exec -it codex-proxy codex login --help` et utilisez la méthode interactive documentée par la CLI. Le volume Docker conserve la session lors des redémarrages et reconstructions.

Après connexion, vérifiez l’accès Codex (un tour est exécuté) :

```sh
curl -fsS http://127.0.0.1:3000/healthz/deep
```

### Utilisation client

- `BASE_URL=http://<IP_HOTE>:3000/v1`
- `API_KEY=local` (le proxy ne vérifie pas de clé API ; le client peut néanmoins exiger une valeur non vide)

Exemple de requête réelle :

```sh
curl -fsS http://127.0.0.1:3000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer local' \
  -d '{"model":"gpt-6-luna","messages":[{"role":"user","content":"Réponds uniquement OK."}]}'
```

Pour l’API Responses, utiliser `POST /v1/responses` ; les deux routes sont documentées par le projet amont.

### Configuration et maintenance

Les valeurs sont dans `.env` : hôte `0.0.0.0`, port publié sur l’hôte `3000` (port interne du conteneur `3466`), runtime `pool`, limite de pool `16`, modèle par défaut `gpt-6-luna`, sandbox `read-only`, politique d’approbation `never`. Le port publié peut être modifié via `CODEX_PROXY_PORT` ; le port d’écoute dans le conteneur reste `3466`.

```sh
docker compose logs -f codex-proxy
docker compose down
```

`docker compose down -v` supprime aussi le volume d’authentification et donc la session OAuth persistée.
