# LiteLLM Codex Gateway

LiteLLM lit le catalogue Codex au démarrage, génère `model_list` dans `litellm-config.yaml` et expose les modèles en HTTPS sur le port **4000**. Le certificat est auto-signé. Pi utilise le package officiel `pi-provider-litellm`.

## Démarrer le serveur

Depuis le dépôt, sur le serveur LiteLLM :

```sh
cp .env.example .env
./get_authentification.sh
./start.sh
```

`start.sh` détecte l’adresse LAN et crée le certificat auto-signé au premier démarrage. Exemple actuel :

- API LiteLLM : `https://192.168.0.92:4000`
- Téléchargement du certificat : `http://192.168.0.92:4001/litellm.crt`

Si l’adresse de ton serveur est différente, remplace `192.168.0.92` par son adresse dans les commandes ci-dessous. Le serveur sur 4001 distribue uniquement le certificat public, jamais la clé privée. Aucun port inférieur à 1000 n’est utilisé.

Le login ChatGPT Codex se fait une seule fois côté serveur. Au redémarrage, le catalogue du compte est relu et `litellm-config.yaml` est régénéré. Si l’adresse IP change, supprime `tls/litellm.crt` et `tls/litellm.key`, puis relance `./start.sh` pour générer un certificat correspondant à la nouvelle adresse. Ces fichiers sont ignorés par Git ; ne partage jamais la clé privée.

## Configurer chaque client Pi

Installe le package (ou garde-le dans la liste `packages` de `~/.pi/agent/settings.json`) :

```sh
pi install npm:pi-provider-litellm
```

Puis télécharge le certificat et lance Pi en lui indiquant de lui faire confiance :

```sh
mkdir -p ~/.pi/agent
wget http://192.168.0.92:4001/litellm.crt -O ~/.pi/agent/litellm.crt
NODE_EXTRA_CA_CERTS="$HOME/.pi/agent/litellm.crt" pi
```

Dans Pi, lance `/login litellm`, saisis l’URL `https://192.168.0.92:4000` et la clé API (`admin`), puis `/model` pour choisir un modèle.

Pour configurer directement l’URL dans `~/.pi/agent/settings.json`, fusionne cette section à la racine du fichier, en conservant tes autres paramètres :

```json
{
  "litellm": {
    "providers": {
      "litellm": {
        "baseUrl": "https://192.168.0.92:4000"
      }
    }
  }
}
```

N’ajoute pas `allowInsecureHttp` avec HTTPS. Pour que chaque nouveau terminal Pi charge automatiquement le certificat, ajoute ceci au profil shell utilisé (`~/.bashrc` ou `~/.zshrc`) :

```sh
export NODE_EXTRA_CA_CERTS="$HOME/.pi/agent/litellm.crt"
```

Le téléchargement HTTP du certificat n’authentifie pas le serveur ; cette méthode est prévue pour le réseau local de confiance. Il faut conserver `NODE_EXTRA_CA_CERTS` : sans cela, Node rejette le certificat auto-signé. Évite `NODE_TLS_REJECT_UNAUTHORIZED=0`, qui désactive la validation TLS pour toutes les connexions HTTPS de Pi.

## Vérifier et arrêter

Depuis un client qui a téléchargé le certificat :

```sh
curl --cacert ~/.pi/agent/litellm.crt https://192.168.0.92:4000/health/liveliness
curl --cacert ~/.pi/agent/litellm.crt -H 'Authorization: Bearer admin' https://192.168.0.92:4000/v1/models
```

La clé de démonstration `admin` est faible : change-la dans `.env` et n’expose pas ces ports à Internet.

Pour arrêter les conteneurs sans supprimer les données :

```sh
./stop.sh
```
