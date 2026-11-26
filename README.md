# LiteLLM Codex Gateway

Ce dépôt fournit un proxy LiteLLM local. Le login ChatGPT/Codex est géré
sur le serveur ; plusieurs clients Pi utilisent les modèles du compte. Les
outils Pi (par exemple le terminal) restent exécutés sur chaque client.

Pi utilise le package officiel `pi-provider-litellm`. Le serveur actualise la
liste des modèles au démarrage ; il n’est pas nécessaire de les ajouter un
par un dans la configuration de Pi.

## Fonctionnement et adresses

Exemple avec l’adresse LAN du serveur `192.168.0.92` :

| Fonction | Adresse ou port |
| --- | --- |
| API HTTPS LiteLLM | `https://192.168.0.92:4000` |
| Certificat TLS public | `http://192.168.0.92:4001/litellm.crt` |
| Installateur Pi | `http://192.168.0.92:4001/install_litllm_pi.sh` |
| Console LiteLLM | `https://192.168.0.92:4000/ui` |

Le port `4000` fournit l’API LiteLLM en HTTPS. Le port `4001` est un serveur
HTTP minimal qui ne distribue que le certificat public et le script
d’installation, par une liste blanche de chemins. Il ne monte ni ne distribue
la clé privée TLS.

Les commandes ci-dessous utilisent `192.168.0.92` comme exemple. Si le serveur
utilise une autre adresse, remplace-la par son adresse LAN. Seuls les ports
`4000` et `4001` doivent être accessibles depuis les clients Pi ; aucun port
inférieur à `1000` n’est utilisé.

## Installer le serveur LiteLLM

Effectue ces étapes sur l’ordinateur qui hébergera LiteLLM. Il doit avoir
Docker Compose, OpenSSL et la commande `ip` installés.

### 1. Récupérer le projet et configurer les secrets

```sh
git clone https://github.com/zuzu59/z-proxy-gpt-codex.git
cd z-proxy-gpt-codex
cp .env.example .env
```

Ouvre `.env` et change au minimum `LITELLM_MASTER_KEY=admin` pour une clé
personnelle forte. Le mot de passe PostgreSQL d’exemple doit aussi être
remplacé lors d’une nouvelle installation.

> Si le volume PostgreSQL existe déjà, ne change pas uniquement
> `LITELLM_DB_PASSWORD` dans `.env`. Il doit correspondre au mot de passe déjà
> configuré dans la base.

`.env`, les jetons OAuth et les certificats privés sont locaux et ne doivent
jamais être envoyés sur GitHub.

### 2. Connecter le compte ChatGPT/Codex

L’authentification se fait une fois sur le serveur. Lance :

```sh
./get_authentification.sh
```

Suis les instructions pour ouvrir la page de connexion et saisir le code
d’appareil. Connecte le compte ChatGPT/Codex qui possède les modèles à
partager. Les jetons sont conservés dans `litellm-auth/` sur le serveur.

### 3. Démarrer les services

```sh
./start.sh
```

Au démarrage, le script détecte l’adresse LAN et crée le certificat
auto-signé si nécessaire. Il lance ensuite LiteLLM, PostgreSQL et le serveur
de téléchargement. LiteLLM relit le catalogue Codex du compte et met à jour
sa liste de modèles.

Si l’adresse détectée est incorrecte, indique l’adresse LAN manuellement :

```sh
LITELLM_DOMAIN=192.168.0.92 ./start.sh
```

Le terminal affiche ensuite les adresses des services.
`LITELLM_MASTER_KEY` permet d’accéder à l’API et à la console
d’administration. N’expose pas le service à Internet.

### Changer l’adresse IP du serveur

Le certificat contient l’adresse du serveur. Si elle change, supprime les
anciens certificats puis redémarre avec la nouvelle adresse :

```sh
rm -f tls/litellm.crt tls/litellm.key
LITELLM_DOMAIN=192.168.0.50 ./start.sh
```

Le certificat sera recréé pour cette adresse. Ne partage jamais
`tls/litellm.key`.

## Installer Pi sur un ordinateur client

Pi doit déjà être installé sur chaque ordinateur client. Depuis un terminal
sur cet ordinateur, lance :

```sh
IP=192.168.0.92
curl -fsSL "http://$IP:4001/install_litllm_pi.sh" | bash -s -- "$IP"
```

Remplace uniquement la valeur de `IP` si le serveur a une autre adresse.
Cette commande télécharge et exécute l’installateur distribué par le
serveur LiteLLM.

L’installateur :

1. télécharge le certificat public et vérifie qu’il correspond à
   l’adresse fournie ;
2. installe le package officiel `pi-provider-litellm` ;
3. ajoute les paramètres LiteLLM à `~/.pi/agent/settings.json` sans effacer
   les autres réglages Pi ;
4. demande la clé API du serveur. Appuie sur Entrée pour garder `admin`, ou
   saisis la valeur définie dans `.env` ;
5. protège `settings.json` pour qu’il ne soit lisible que par ton compte ;
6. configure `NODE_EXTRA_CA_CERTS` dans le profil Bash ou Zsh afin que Node.js
   accepte le certificat auto-signé du serveur.

Ferme et rouvre ensuite le terminal pour charger la variable d’environnement,
puis lance Pi normalement :

```sh
pi
```

Dans Pi, utilise `/model` pour parcourir les modèles disponibles et en choisir
un. Tu n’as pas besoin de relancer `/login` : l’installateur a configuré
l’adresse du proxy et la clé API dans les paramètres Pi.

### Limite de sécurité du téléchargement

Le téléchargement et l’exécution de l’installateur utilisent HTTP. Cette
méthode suppose que le réseau local est de confiance ; ne l’utilise pas sur
un Wi-Fi public ou un réseau que tu ne contrôles pas. Un autre appareil
malveillant présent sur le même réseau pourrait modifier le script ou le
certificat transmis.

Le certificat auto-signé permet à Node.js de vérifier la connexion HTTPS au
proxy une fois le certificat installé. Il ne protège pas contre un attaquant
capable d’intercepter le téléchargement initial. N’utilise pas
`NODE_TLS_REJECT_UNAUTHORIZED=0` : cela désactive la validation TLS pour toutes
les connexions HTTPS lancées par Pi.

## Vérifier le service

Depuis le client Pi, vérifie que l’API HTTPS répond et que la liste des
modèles est accessible :

```sh
IP=192.168.0.92
CERT="$HOME/.pi/agent/litellm.crt"
API_KEY=admin
curl --cacert "$CERT" "https://$IP:4000/health/liveliness"
curl --cacert "$CERT" \
  -H "Authorization: Bearer $API_KEY" \
  "https://$IP:4000/v1/models"
```

Si tu as remplacé `admin`, mets ta clé API dans `API_KEY`.

Pour consulter les journaux LiteLLM en cas de problème, exécute cette
commande sur le serveur :

```sh
docker compose logs -f litellm
```

Si aucun modèle n’apparaît, vérifie le login ChatGPT/Codex du serveur, puis
relance `./start.sh` pour actualiser le catalogue.

## Arrêter le service

Sur le serveur, arrête les conteneurs sans supprimer les jetons OAuth ni les
données PostgreSQL :

```sh
./stop.sh
```

Les données sont conservées. N’utilise pas `docker compose down -v` sauf si
tu veux explicitement supprimer le volume PostgreSQL.

## Fichiers locaux et secrets

- `.env` contient les clés et mots de passe propres au serveur.
- `litellm-auth/` contient les jetons OAuth ChatGPT/Codex.
- `tls/litellm.key` est la clé privée du certificat HTTPS.
- `tls/litellm.crt` est le certificat public distribué aux clients.

Ces fichiers restent locaux et sont exclus de Git. Ne publie jamais `.env`,
les jetons OAuth ou `tls/litellm.key`.
