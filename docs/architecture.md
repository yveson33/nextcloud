# Architecture du cloud personnel

État au 2026-09-02. Ce document décrit l'infrastructure telle qu'elle tourne
aujourd'hui, et surtout **pourquoi** elle est faite ainsi — plusieurs choix sont
des contournements de pannes réelles qu'il serait coûteux de redécouvrir.

Immich tourne en **v3.1.0**. La version est épinglée dans `docker/immich/.env`
et ne doit **jamais** revenir au tag `release` : voir [Mise à jour](#mise-à-jour).

## Vue d'ensemble

Nextcloud est **déprécié et arrêté**. Immich l'a remplacé pour les photos.

| Service | Image | Exposition |
|---|---|---|
| `NEXTCLOUD_IMMICH_immich_nginx` | build local | `443` (HTTPS), `80` (redirection) |
| `NEXTCLOUD_IMMICH_IMMICH_SERVER` | `immich-server:v3` | `2283` (HTTP, requis par l'app mobile) |
| `NEXTCLOUD_IMMICH_immich_postgres` | `postgres:14-vectorchord` | interne |
| `NEXTCLOUD_IMMICH_immich_redis` | `redis:latest` | interne |
| `NEXTCLOUD_IMMICH_immich_machine_learning` | `immich-machine-learning:v3` | interne |
| `NEXTCLOUD_PORTAINER` | `portainer-ce:latest` | `9443` |

Tous sur le réseau Docker **`personal_cloud`**. L'ancien réseau
`personnal_nextcloud` a été supprimé : les conteneurs y étaient encore attachés
alors que le dépôt avait déjà été renommé, ce qui empêchait tout `docker compose
up` de la stack Immich.

## Démarrage

Unité systemd **`personal_cloud.service`** (anciennement
`nextcloud_personnal.service`, renommée pour correspondre au dépôt). Elle appelle
`cloud_services.py`, qui crée le réseau puis démarre `immich` et `portainer`.
Nextcloud en est **volontairement exclu**.

```bash
./personal_cloud start|stop|restart|status
python3 cloud_services.py start          # ce que systemd exécute
./personal_cloud nextcloud start         # Nextcloud, manuellement
```

Les conteneurs Nextcloud arrêtés référencent le réseau supprimé : un
`docker compose start` échouerait, il faut un `up -d` qui les recrée.

### Chemins des volumes : ne jamais utiliser `$PWD`

Le compose d'Immich utilisait `$PWD/data/postgres` pour ses montages. Or
`cloud_services.py` — et donc le service systemd — appelle
`docker compose -f <chemin absolu>` **depuis la racine du dépôt** : `$PWD` valait
la racine et non `docker/immich`. Chaque démarrage par ce chemin montait donc
postgres sur `/home/yves/sites/nextcloud/data/postgres`, un répertoire vide où
postgres initialisait une base neuve — Immich démarrait sain, avec zéro photo.

Les montages utilisent désormais des chemins **relatifs** (`./data/postgres`),
que Compose résout par rapport au répertoire du fichier compose et non au
répertoire courant du processus appelant. Le résultat est identique quel que
soit l'endroit d'où la commande est lancée.

> Le symptôme était trompeur : conteneurs sains, API en 200, et une base
> parfaitement fonctionnelle mais vide. Les vraies données n'avaient jamais été
> touchées, seulement ignorées. Le contrôle qui l'a révélé :
> `docker inspect <conteneur> --format '{{range .Mounts}}{{.Source}}{{end}}'`.

## Stockage des photos

Tout vit sous **`docker/immich/`**, qui est donc le seul chemin à sauvegarder :

```
docker/immich/
├── data/postgres/                    594 Mo   base de données
└── www/immich/
    ├── external/                      67 Go   historique migré de Nextcloud
    │   ├── yves/                      37 Go   7027 médias
    │   └── heloise/                   30 Go   3124 médias
    ├── machine_server/               8,0 Go
    │   ├── library/                          photos envoyées par l'app mobile
    │   ├── thumbs/                           vignettes (régénérables)
    │   └── encoded-video/                    transcodages (régénérables)
    └── machine_learning/             786 Mo   modèles CLIP (régénérables)
```

`external/` est monté **en lecture seule** sur `/mnt/media` dans
`immich-server`, via `EXTERNAL_MEDIA_PATH`. Immich l'indexe en **bibliothèque
externe** : il lit les fichiers sur place, sans jamais les copier ni pouvoir les
modifier.

Deux bibliothèques déclarées, une par utilisateur — `/mnt/media/yves` et
`/mnt/media/heloise`. Immich ne permet pas de transférer une bibliothèque d'un
propriétaire à l'autre après création.

> **Le chemin conteneur `/mnt/media` ne doit jamais changer.** Les 10 151
> `originalPath` enregistrés en base en dépendent. C'est ce qui a permis de
> déplacer les 67 Go depuis `/home/yves/media/photos` sans toucher à la base :
> seul le côté hôte du montage a été modifié.

### Sauvegarde

Sauvegarder `docker/immich/` couvre tout. Pour une sauvegarde minimale, deux
sous-ensembles suffisent — le reste se régénère :

| À sauvegarder | Pourquoi |
|---|---|
| `www/immich/external/` | originaux irremplaçables |
| `www/immich/machine_server/library/` | photos du mobile, irremplaçables |
| `data/postgres/` (par `pg_dump`) | albums, visages, métadonnées |

Les vignettes, transcodages et modèles ML représentent ~13 Go régénérables.

### Pourquoi la bibliothèque externe plutôt qu'un import

Historiquement, parce que l'API d'upload rejetait toutes les requêtes. Cette
panne est **résolue** — voir [Incident de l'API d'upload](#incident-de-lapi-dupload)
— mais la bibliothèque externe reste le bon choix :

- **aucune duplication** : 67 Go de photos ont coûté 4,8 Go de vignettes, contre
  67 Go supplémentaires qu'aurait exigés un import ;
- **originaux hors d'atteinte** : le montage en lecture seule garantit qu'aucun
  dysfonctionnement d'Immich ne peut les altérer.

## Synchronisation mobile

L'application Immich sauvegarde les photos du téléphone via son API, sur
`http://192.168.1.199:2283`. Les photos ainsi envoyées vivent dans le stockage
propre d'Immich (`docker/immich/www/immich/machine_server/library/`), et non dans
la bibliothèque externe qui reste en lecture seule.

Les photos occupent deux sous-arbres distincts — `external/` pour l'historique,
`machine_server/library/` pour les envois du mobile — mais **sous une seule
racine**, `docker/immich/`. C'est invisible dans l'application : même
chronologie, mêmes albums.

La différence est ailleurs : les nouvelles photos consomment leur taille réelle
sur le disque, alors que la bibliothèque externe ne coûte que ses vignettes.

> **Syncthing a été retiré.** Il avait été mis en place le 2026-09-02 pour
> contourner l'API d'upload, alors défaillante. La mise à jour en v3.1.0 ayant
> réparé cette API, la sauvegarde native de l'application suffit — et elle est
> plus riche : suivi des photos déjà sauvegardées, gestion des albums, libération
> de l'espace du téléphone. Syncthing n'a jamais été appairé à un appareil.

### Pièges rencontrés

L'application affiche comme « déjà sauvegardées » les photos locales qui ont une
correspondance sur le serveur. Comme tout l'historique a été importé en
bibliothèque externe, elle considère la quasi-totalité de la pellicule comme en
sécurité — ce qui donne l'illusion d'une sauvegarde active alors que rien n'a
encore été envoyé. Le seul contrôle fiable est côté serveur :

```sql
select count(*) filter (where "libraryId" is null) as uploades_app from asset;
```

La sauvegarde a deux interrupteurs distincts : **avant-plan** (application
ouverte) et **arrière-plan**, souvent désactivé par défaut. Sur Android, il faut
aussi retirer l'application de l'optimisation de batterie, sans quoi le système
tue le service.

## TLS

`docker/immich/nginx/` construit un nginx avec un **certificat auto-signé**
généré à la construction, valable 10 ans :

```
CN  = immich.local
SAN = DNS:immich.local, DNS:yves-nas-hp, DNS:localhost
      IP:192.168.1.199, IP:127.0.0.1
```

Les `subjectAltName` sont indispensables : les navigateurs récents rejettent un
certificat qui ne s'appuie que sur le CN. Le certificat de l'ancienne stack
Nextcloud n'en avait pas.

La configuration gère les trois pièges d'un proxy devant Immich :

| Directive | Sans elle |
|---|---|
| `client_max_body_size 50000M` | `413` sur les vidéos volumineuses |
| en-têtes `Upgrade` / `Connection` | plus de mise à jour temps réel (socket.io) |
| `proxy_buffering off` | streaming vidéo dégradé |

Le port `2283` reste exposé en clair sur le LAN : **l'application mobile s'en
sert**, faute d'accepter le certificat auto-signé. Ne pas le fermer sans avoir
d'abord mis en place un certificat reconnu.

### Limite de l'auto-signé

L'application mobile Immich refuse ces certificats. Ce n'est **pas** un blocage
absolu : l'application accepte une URL en clair, donc `http://192.168.1.199:2283`
fonctionne sur le réseau local. Le certificat ne limite que l'accès en HTTPS.

Pour du HTTPS de bout en bout jusqu'au mobile : Let's Encrypt par challenge DNS
(demande un domaine, fonctionne sans exposer le serveur), ou un VPN type
Tailscale qui rend TLS superflu.

## Mise à jour

**Ne jamais utiliser le tag `release`.** Il suit la dernière version publiée, et
Immich refuse de sauter une version majeure (`Invalid upgrade path`). Un simple
`docker compose pull` avec `IMMICH_VERSION=release` sur une installation en
retard tente donc une mise à jour interdite.

Le compose utilise `${IMMICH_VERSION:?...}` : une variable absente provoque une
erreur explicite au lieu de retomber silencieusement sur `release`.

Les mises à jour passent par `docker/immich/upgrade.sh`, palier par palier :

```bash
./docker/immich/upgrade.sh v3
```

Le script exige une sauvegarde récente et crédible dans `/home/yves/backups/`
(taille minimale, marqueur de fin présent), 15 Go libres, relève l'état avant,
applique, attend que le serveur soit sain, puis recompte assets, bibliothèques,
utilisateurs et vignettes.

Il juge les erreurs sur une **fenêtre récente après un temps de repos**, et non
sur tout l'historique du conteneur : la mise en file des travaux de détection de
visages démarre avant que le conteneur de machine learning ait chargé ses
modèles, ce qui produit une salve d'erreurs transitoires de quelques secondes.
Une première version du script comptait tout l'historique et échouait
systématiquement sur ce bruit.

> Les travaux ML échoués pendant cette salve **ne sont pas rejoués
> automatiquement** : les relancer dans Administration → Tâches.

### Historique

| Date | Version | Note |
|---|---|---|
| 2025-08-30 | `1.140.1` | image d'origine, restée un an sans mise à jour |
| 2026-09-02 | `v2.7.5` | palier obligatoire, schéma migré |
| 2026-09-02 | `v3.1.0` | abandon de pgvecto.rs, clés API en `bytea` |

Ruptures de schéma rencontrées : `asset_job_status.thumbnailAt` et `previewAt`
ont migré vers la table `asset_file` en v2 ; la colonne `api_key.key` est passée
de `varchar` base64 à `bytea` contenant les 32 octets bruts du SHA-256 en v3.

## Redis

Immich a **son propre Redis**. Il pointait auparavant sur `NEXTCLOUD_REDIS`, un
service de la stack Nextcloud : arrêter Nextcloud le privait de son backend de
files d'attente et le mettait en boucle de redémarrage.

Le mot de passe réutilise la variable `NEXTCLOUD_REDIS_PASSWORD` pour ne pas
toucher au fichier de secrets — **à renommer** en `IMMICH_REDIS_PASSWORD`.

## Incident du 2026-09-02

Le disque était à **99 %** (4,3 Go libres sur 234). Deux causes cumulées.

**Immich en boucle de redémarrage.** Catalogue postgres corrompu :
`missing chunk number 0 for toast value 24804 in pg_toast_2619`. Le worker
microservices plantait au démarrage, tuait l'API, et `restart: always` relançait.
La base contenait 0 asset et 0 utilisateur, et `pg_dump` était impossible — elle
a été recréée vierge. **Cette corruption est très probablement la conséquence
d'un précédent import ayant rempli le disque** : postgres qui ne peut plus écrire
corrompt son catalogue.

**110 Go de déchets accumulés.** Nettoyage effectué :

| Poste | Récupéré |
|---|---|
| Corbeille Nextcloud | 56 Go |
| Cache apt | 24 Go |
| Previews Nextcloud | 28 Go |
| Journaux systemd | ~3 Go |
| Base Immich corrompue, log nginx | ~390 Mo |

Résultat : de 99 % à 49 %.

### Incident de l'API d'upload

Pendant la migration, toute tentative d'import échouait. Le fichier était écrit
sur le disque par la couche multipart, puis la requête rejetée. Le client
réessayait, et chaque tentative laissait une copie orpheline : 15 fichiers de
test produisaient 91 orphelins et 0 asset. À l'échelle des 67 Go de photos, cela
a écrit **111 Go de fichiers non référencés** et rempli le disque à 99 %.

Rien n'apparaissait dans les logs, ni côté serveur ni côté postgres — une erreur
de validation `400` ne remonte pas au niveau `log`. La cause n'est devenue
visible qu'en lisant le `stderr` du client :

```
{"message":["deviceAssetId must be a string","deviceId must be a string"],
 "error":"Bad Request","statusCode":400}
```

**Incompatibilité de version**, pas une panne : le serveur `1.140.1` exigeait
`deviceAssetId` et `deviceId`, devenus optionnels dans les versions ultérieures,
que le client `3.1.0` n'envoyait donc plus. Résolu par la mise à jour en v3.1.0,
qui aligne les deux.

Leçon : un serveur laissé un an sans mise à jour finit par être incompatible avec
ses propres outils, dont le tag `latest` avance sans lui.

### Perte de données

Le vidage de la corbeille a détruit **75 fichiers, 11,07 Go**, qui n'existaient
nulle part ailleurs. Voir [videos-perdues-corbeille-2026-09-02.md](videos-perdues-corbeille-2026-09-02.md).

Sur 6635 noms en corbeille, 6551 existaient à l'identique dans `files/`
(vérifié par empreinte MD5) : leur suppression était sans perte. Les 84 autres
provenaient du dossier `Camera`, supprimé volontairement le 2026-08-31, dont la
copie vers `Photos/` était incomplète.

## Chantiers ouverts

**À faire**

- **Relancer la détection de visages** : les travaux mis en file pendant les
  mises à jour ont échoué sur la salve de démarrage ML et ne se rejouent pas
  seuls. Administration → Tâches.
- **Surveiller la croissance du disque** : les photos envoyées par l'application
  consomment leur taille réelle, contrairement à la bibliothèque externe.

**Si tu veux sauvegarder hors du réseau local**

Aujourd'hui la sauvegarde mobile ne fonctionne qu'à la maison, en HTTP sur le
LAN. Un VPN type Tailscale donnerait l'accès depuis n'importe où sans ouvrir de
port, et fournit un certificat Let's Encrypt valide sur un nom `*.ts.net` — ce
qui lèverait la limite de l'auto-signé et permettrait de fermer `443` et `2283`.
Contrepartie : une dépendance à un service tiers pour le plan de contrôle.

**Propreté**

- **Renommer** `NEXTCLOUD_REDIS_PASSWORD` en `IMMICH_REDIS_PASSWORD`.
- **Supprimer l'arborescence Nextcloud** : `www/nextcloud` (873 Mo de code PHP),
  `www/data/nextcloud` (vidé).
- **`docker image prune`** : les couches des images 1.140.1 et v2 restent en
  cache après les deux paliers.
- **Aligner tous les conteneurs** sur `personal_cloud` au prochain redémarrage
  complet.
- **Fermer le port 2283** si tu passes à un accès HTTPS de bout en bout — il est
  aujourd'hui nécessaire à l'application mobile.
