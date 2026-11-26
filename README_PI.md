# Utiliser le proxy LiteLLM avec Pi Agent

Ce guide configure Pi sur un ordinateur client pour utiliser le proxy
LiteLLM du réseau local. L’authentification ChatGPT/Codex reste centralisée
sur le serveur ; les outils de Pi continuent de s’exécuter sur le client.

Pour installer le serveur, consulte le [guide du proxy][proxy]. Pour le
fonctionnement interne, consulte [l’architecture][architecture]. Le guide
[OpenCode][opencode] décrit l’autre client supporté.

## Prérequis

- Pi Agent est installé sur l’ordinateur client.
- Le serveur LiteLLM est démarré et son adresse est connue.
- Les ports `4000` (API HTTPS) et `4001` (téléchargement HTTP) sont joignables
  depuis le réseau local.

L’exemple utilise `192.168.0.92`. Remplace cette adresse si nécessaire.

## Installation automatique

Dans un terminal sur l’ordinateur où Pi est installé, lance :

```sh
IP=192.168.0.92
curl -fsSL "http://$IP:4001/install_litllm_pi.sh" | bash -s -- "$IP"
```

L’installateur exige l’adresse du serveur comme argument ; aucune IP n’est
codée en dur dans le script. Il télécharge le certificat public, vérifie que
son SAN correspond à l’adresse fournie, puis :

1. installe le package officiel `pi-provider-litellm` ;
2. ajoute sa configuration à `~/.pi/agent/settings.json` sans supprimer les
   autres réglages Pi ;
3. demande la clé LiteLLM et l’enregistre dans les paramètres Pi ;
4. protège `settings.json` avec les permissions `600` ;
5. configure `NODE_EXTRA_CA_CERTS` pour que Node.js fasse confiance au
   certificat auto-signé.

Pour utiliser une clé différente de la valeur de démonstration `admin`, saisis
la valeur de `LITELLM_MASTER_KEY` quand l’installateur la demande. La clé
stockée côté client est la clé d’accès au proxy, pas le jeton OAuth ChatGPT.

Ferme puis rouvre le terminal après l’installation afin de charger la variable
d’environnement. Lance ensuite Pi :

```sh
pi
```

Dans l’interface Pi, exécute `/model` pour afficher et sélectionner les
modèles disponibles sur le compte du serveur. Aucun modèle ne doit être ajouté
à la main dans `models.json` et aucun `/login` Pi n’est requis.

## Vérifier la connexion

Le certificat public est installé sous `~/.pi/agent/litellm.crt`. Vérifie
l’API et son catalogue en remplaçant la clé d’exemple par celle du serveur :

```sh
IP=192.168.0.92
CERT="$HOME/.pi/agent/litellm.crt"
API_KEY=admin
curl --cacert "$CERT" "https://$IP:4000/health/liveliness"
curl --cacert "$CERT" \
  -H "Authorization: Bearer $API_KEY" \
  "https://$IP:4000/v1/models"
```

Une réponse de `/v1/models` contenant les modèles confirme que Pi peut les
récupérer. Le catalogue amont est actualisé au démarrage du proxy ; après un
changement de catalogue ou de compte, redémarre le proxy avec `./start.sh`.

## Sécurité du téléchargement

L’installateur et le certificat sont téléchargés en HTTP sur le port `4001`.
Effectue l’installation uniquement sur un réseau local de confiance : un
appareil capable d’intercepter ce téléchargement pourrait remplacer le script
ou le certificat. La vérification du SAN confirme l’adresse, mais ne permet
pas d’authentifier le certificat reçu en clair.

Ne contourne pas les erreurs TLS avec `NODE_TLS_REJECT_UNAUTHORIZED=0` ; cela
désactive la validation des certificats pour toutes les connexions Node.js.
Protège `~/.pi/agent/settings.json`, qui contient la clé LiteLLM.

## Dépannage

- **`pi` n’apparaît pas dans `/model` :** vérifie la clé, l’adresse du serveur
  et la réponse de `/v1/models` avec la commande `curl` ci-dessus.
- **Erreur de certificat :** vérifie que le certificat a été téléchargé pour
  la même IP ou le même nom que l’URL, puis ouvre un nouveau terminal pour
  charger `NODE_EXTRA_CA_CERTS`.
- **Nouveaux modèles absents :** le serveur reconstruit son catalogue au
  démarrage. Vérifie `docker compose logs -f litellm` côté serveur, puis
  relance `./start.sh`.
- **L’installateur ne démarre pas :** vérifie la présence de `curl`, `openssl`,
  `node` et `pi`, ainsi que l’accès au port `4001`.

[proxy]: README.md
[architecture]: ARCHITECTURE.md
[opencode]: README_OPENCODE.md
