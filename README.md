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
- Certificat public : `http://192.168.0.92:4001/litellm.crt`
- Script d’installation Pi : `http://192.168.0.92:4001/install_litllm_pi.sh`

Si l’adresse de ton serveur est différente, remplace `192.168.0.92` par son adresse dans les commandes ci-dessous. Le port 4001 ne sert que ces deux fichiers autorisés, jamais la clé privée. Aucun port inférieur à 1000 n’est utilisé.

Le login ChatGPT Codex se fait une seule fois côté serveur. Au redémarrage, le catalogue du compte est relu et `litellm-config.yaml` est régénéré. Si l’adresse IP change, supprime `tls/litellm.crt` et `tls/litellm.key`, puis relance `./start.sh` pour générer un certificat correspondant à la nouvelle adresse. Ces fichiers sont ignorés par Git ; ne partage jamais la clé privée.

## Installer le client Pi en une commande

Sur l’ordinateur où Pi est installé, exécute cette commande. Elle télécharge et lance le script directement depuis le petit serveur du proxy sur le port 4001 :

```sh
curl -fsSL http://192.168.0.92:4001/install_litllm_pi.sh | bash -s -- 192.168.0.92
```

Le script télécharge le certificat depuis le serveur LAN, installe le package officiel `pi-provider-litellm`, ajoute les paramètres du fournisseur à `~/.pi/agent/settings.json` sans supprimer les autres réglages, puis configure `NODE_EXTRA_CA_CERTS` dans le profil Bash ou Zsh. Il demande la clé API (la valeur par défaut est `admin`) et protège `settings.json` avec des permissions privées. Ferme et rouvre ensuite le terminal : tu pourras lancer simplement `pi`.

Si l’adresse du serveur est différente, remplace `192.168.0.92` dans la commande. Si la clé API n’est pas `admin`, saisis la bonne valeur lorsque le script la demande. Le script nécessite `curl`, `openssl`, `node`, Pi et un shell Bash ou Zsh.

Le téléchargement et l’exécution du script via HTTP n’authentifient pas le serveur ; cette méthode est prévue pour le réseau local de confiance. Ne l’utilise pas sur un réseau public. Il faut conserver `NODE_EXTRA_CA_CERTS` : sans cela, Node rejette le certificat auto-signé. Évite `NODE_TLS_REJECT_UNAUTHORIZED=0`, qui désactive la validation TLS pour toutes les connexions HTTPS de Pi.

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
