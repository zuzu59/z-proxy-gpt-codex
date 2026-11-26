# Utiliser le proxy LiteLLM avec OpenCode

Ce guide connecte OpenCode au proxy LiteLLM du réseau local au moyen du
package `opencode-plugin-litellm`. Le plugin découvre les modèles du proxy ;
il n’est pas nécessaire d’en maintenir une liste dans `opencode.json`.

L’authentification ChatGPT/Codex reste sur le serveur LiteLLM. OpenCode
exécute ses outils sur le poste client.

Consulte le [guide du proxy][proxy] pour déployer le serveur et
[l’architecture][architecture] pour comprendre ses limites et ses flux. Le
[guide Pi][pi] décrit l’autre client pris en charge.

## Prérequis

- OpenCode installé sur le poste client et connecté au réseau du serveur.
- Les ports `4000` (API HTTPS) et `4001` (certificat) sont accessibles.
- OpenSSL est requis pour vérifier le nom présent dans le certificat.
- Node/Bun ou le magasin système de certificats peut faire confiance au
  certificat auto-signé du proxy.

L’exemple utilise l’adresse serveur `192.168.0.92` et la clé `admin`.
Remplace-les par les valeurs définies pour ton déploiement.

## 1. Télécharger et faire confiance au certificat

L’API LiteLLM utilise un certificat auto-signé. Télécharge son certificat
public dans le répertoire de configuration OpenCode :

```sh
IP=192.168.0.92
mkdir -p "$HOME/.config/opencode"
curl -fsSL "http://$IP:4001/litellm.crt" \
  -o "$HOME/.config/opencode/litellm.crt"
openssl x509 -in "$HOME/.config/opencode/litellm.crt" \
  -noout -checkip "$IP"
```

Si tu utilises un nom DNS plutôt qu’une IP, remplace `-checkip` par
`-checkhost` dans la commande OpenSSL.

Le téléchargement initial se fait en HTTP. N’exécute ces commandes que sur
un réseau local de confiance : le transfert ne permet pas d’authentifier le
certificat contre un attaquant présent sur le réseau.

Le plugin interroge LiteLLM avec `fetch()`. La manière de faire confiance au
certificat dépend du runtime et du système. Sur Debian ou Ubuntu, tu peux
l’ajouter au magasin système :

```sh
sudo install -m 0644 "$HOME/.config/opencode/litellm.crt" \
  /usr/local/share/ca-certificates/litellm.crt
sudo update-ca-certificates
```

Sur macOS, importe-le dans le trousseau système avec l’outil `security` :

```sh
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  "$HOME/.config/opencode/litellm.crt"
```

Sur d’autres systèmes, utilise leur gestionnaire de certificats de confiance.

Bun documente `SSL_CERT_FILE` pour ajouter un fichier PEM aux autorités
reconnues ; Node.js utilise `NODE_EXTRA_CA_CERTS`. Si tu préfères les variables
d’environnement, configure celle qui correspond à ton runtime :

```sh
# Pour un runtime Bun :
export SSL_CERT_FILE="$HOME/.config/opencode/litellm.crt"
# Pour un runtime Node.js, utilise plutôt :
export NODE_EXTRA_CA_CERTS="$HOME/.config/opencode/litellm.crt"
```

Ces variables dépendent du runtime et du build OpenCode ; elles ne sont pas
une option du plugin lui-même. Si tu en utilises une, lance OpenCode depuis le
même environnement et vérifie que l’API fonctionne sans désactiver la
validation TLS. OpenCode Desktop peut ne pas hériter des variables d’un
terminal. Ne définis pas `NODE_TLS_REJECT_UNAUTHORIZED=0`.

## 2. Installer le plugin communautaire LiteLLM pour OpenCode

Le paquet npm communautaire s’appelle `opencode-plugin-litellm` (et non
`opencode-litellm`). Cette procédure épingle la version étudiée `1.11.0` :

```sh
opencode plugin add opencode-plugin-litellm@1.11.0
```

La commande ajoute le plugin à la configuration utilisateur OpenCode. Le
fichier global se trouve normalement ici :

```text
~/.config/opencode/opencode.json
```

## 3. Configurer l’URL et la clé LiteLLM

Dans `~/.config/opencode/opencode.json`, utilise une configuration V2 comme
celle-ci. Garde l’entrée `plugins` ajoutée par la commande précédente.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["opencode-plugin-litellm@1.11.0"],
  "providers": {
    "litellm": {
      "name": "LiteLLM (LAN)",
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": {
        "baseURL": "https://192.168.0.92:4000/v1",
        "apiKey": "{env:LITELLM_API_KEY}"
      }
    }
  }
}
```

N’inscris pas une vraie clé en clair dans un fichier de configuration partagé
ou versionné. Fournis-la à l’environnement du processus OpenCode :

```sh
export LITELLM_API_KEY=admin
opencode
```

Remplace `admin` par la valeur de `LITELLM_MASTER_KEY` dans le `.env` du
serveur. `LITELLM_API_KEY` est seulement le nom de la variable côté client ;
la clé est la clé d’accès à LiteLLM, pas le jeton OAuth amont.

L’URL doit pointer vers l’API LiteLLM en HTTPS et se terminer par `/v1`.
L’auto-détection du plugin ne convient pas à ce déploiement distant : elle
sonde des ports locaux. La configuration explicite de `baseURL` est donc
nécessaire.

## 4. Choisir un modèle

Dans l’interface TUI OpenCode, lance :

```text
/models
```

Le plugin récupère le catalogue depuis `/v1/models` et les métadonnées depuis
`/v1/model/info` lorsqu’elles sont disponibles. Les modèles apparaissent sous
le fournisseur `litellm`. Sélectionne un modèle puis démarre ou poursuis une
session normalement.

Tous les modèles exposés par ce proxy sont configurés en mode `responses`.
Le plugin utilise donc `/v1/responses` pour les requêtes. Avec OpenCode V2,
les modèles sont normalement sélectionnés sous `litellm/<modèle>`. Avec
l’intégration V1 historique, ils apparaissent sous
`litellm-responses/<modèle>`.

Le plugin conserve un cache local jusqu’à sept jours et peut rafraîchir le
catalogue en arrière-plan. De nouveaux modèles amont ne seront exposés par
LiteLLM qu’après le redémarrage du proxy, qui récupère à nouveau le catalogue
Codex.

## Compatibilité V1 historique

Le guide ci-dessus cible la configuration OpenCode V2 (`plugins` et
`providers`). Le package fournit aussi une intégration pour OpenCode 1.18.29+
avec les clés de configuration historiques `plugin` et `provider`. Pour cette
version, ajoute manuellement le package dans `plugin` si la commande
`opencode plugin add` n’est pas disponible, puis utilise cette forme :

```jsonc
{
  "plugin": ["opencode-plugin-litellm@1.11.0"],
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "https://192.168.0.92:4000/v1",
        "apiKey": "{env:LITELLM_API_KEY}"
      }
    }
  }
}
```

Ne mélange pas les champs V1 (`plugin`, `provider`, `options`) avec les champs
V2 (`plugins`, `providers`, `settings`).

## Vérifier le proxy

Avant de diagnostiquer OpenCode, vérifie que le certificat et la clé donnent
accès à la liste des modèles :

```sh
IP=192.168.0.92
CERT="$HOME/.config/opencode/litellm.crt"
API_KEY=admin # Remplace par la valeur de LITELLM_MASTER_KEY.
curl --cacert "$CERT" \
  -H "Authorization: Bearer $API_KEY" \
  "https://$IP:4000/v1/models"
```

Si cette commande échoue, vérifie l’adresse, la clé et que le proxy est actif.
Côté serveur, consulte :

```sh
docker compose logs -f litellm
```

## Sécurité et limites

- `LITELLM_API_KEY` permet d’utiliser le proxy ; ne la publie pas.
- Ne transfère jamais le jeton OAuth ChatGPT/Codex vers le client OpenCode.
- Le téléchargement du certificat par HTTP ne protège pas contre une
  interception sur le réseau local.
- N’utilise pas `NODE_TLS_REJECT_UNAUTHORIZED=0` : cette option désactive la
  validation TLS, au lieu de faire confiance au certificat attendu.
- Le plugin `opencode-plugin-litellm` est un composant tiers distinct de
  LiteLLM ; cette documentation décrit la version `1.11.0` et ses options
  observées, mais ne remplace pas sa documentation de versions ultérieures.

Pour vérifier les options propres à la version installée, consulte la
[fiche npm du plugin][plugin npm], son [code source][plugin source] et les
documentations officielles [OpenCode Plugins][OpenCode plugins] et
[OpenCode Config][OpenCode configuration].

[proxy]: README.md
[architecture]: ARCHITECTURE.md
[pi]: README_PI.md
[plugin npm]: https://www.npmjs.com/package/opencode-plugin-litellm
[plugin source]: https://github.com/yuseferi/opencode-litellm
[OpenCode plugins]: https://opencode.ai/docs/plugins/
[OpenCode configuration]: https://opencode.ai/docs/config/
