# Architecture du cloud personnel

État au 2026-09-02. Ce document décrit l'infrastructure telle qu'elle tourne
aujourd'hui, et surtout **pourquoi** elle est faite ainsi — plusieurs choix sont
des contournements de pannes réelles qu'il serait coûteux de redécouvrir.

## Vue d'ensemble

Nextcloud est **déprécié et arrêté**. Immich l'a remplacé pour les photos.

| Service | Image | Exposition |
|---|---|---|
| `NEXTCLOUD_IMMICH_immich_nginx` | build local | `443` (HTTPS), `80` (redirection) |
| `NEXTCLOUD_IMMICH_IMMICH_SERVER` | `immich-server:release` | `2283` (HTTP, à fermer) |
| `NEXTCLOUD_IMMICH_immich_postgres` | `postgres:14-vectorchord` | interne |
| `NEXTCLOUD_IMMICH_immich_redis` | `redis:latest` | interne |
| `NEXTCLOUD_IMMICH_immich_machine_learning` | `immich-machine-learning:release` | interne |
| `NEXTCLOUD_SYNCTHING` | `syncthing/syncthing:latest` | `22000`, `21027`, `8384` (local) |
| `NEXTCLOUD_PORTAINER` | `portainer-ce:latest` | `9443` |

Tous sur le réseau Docker **`personal_cloud`**. L'ancien réseau
`personnal_nextcloud` a été supprimé : les conteneurs y étaient encore attachés
alors que le dépôt avait déjà été renommé, ce qui empêchait tout `docker compose
up` de la stack Immich.

## Démarrage

Unité systemd **`personal_cloud.service`** (anciennement
`nextcloud_personnal.service`, renommée pour correspondre au dépôt). Elle appelle
`cloud_services.py`, qui crée le réseau puis démarre `immich`, `portainer` et
`syncthing`. Nextcloud en est **volontairement exclu**.

```bash
./personal_cloud start|stop|restart|status
python3 cloud_services.py start          # ce que systemd exécute
./personal_cloud nextcloud start         # Nextcloud, manuellement
```

Les conteneurs Nextcloud arrêtés référencent le réseau supprimé : un
`docker compose start` échouerait, il faut un `up -d` qui les recrée.

## Stockage des photos

```
/home/yves/media/photos/
├── yves/       37 Go, 7027 médias
└── heloise/    30 Go, 3124 médias
```

Monté **en lecture seule** sur `/mnt/media` dans `immich-server`, via
`EXTERNAL_MEDIA_PATH`. Immich les indexe en **bibliothèque externe** : il lit les
fichiers sur place, sans jamais les copier ni pouvoir les modifier.

Deux bibliothèques déclarées, une par utilisateur — `/mnt/media/yves` et
`/mnt/media/heloise`. Immich ne permet pas de transférer une bibliothèque d'un
propriétaire à l'autre après création.

### Pourquoi pas l'import par l'API

**L'API d'upload d'Immich est cassée sur cette installation.** Le fichier est
écrit sur le disque par la couche multipart, puis la requête est rejetée sans
aucune trace dans les logs du serveur ni de postgres. Le client réessaie, et
chaque tentative laisse une copie orpheline.

Mesuré : 15 fichiers de test ont produit **91 fichiers orphelins** et 0 asset. À
l'échelle des 67 Go de photos, cela a écrit **111 Go de fichiers non référencés**
et rempli le disque à 99 %.

L'indexation sur place contourne entièrement cet appel. Le montage en lecture
seule garantit qu'aucun dysfonctionnement d'Immich ne peut atteindre les
originaux.

> La cause racine n'est pas identifiée. Le diagnostic nécessite la sortie texte
> du client, seule à contenir le code HTTP du rejet.

## Synchronisation mobile

La sauvegarde intégrée de l'application Immich **ne fonctionne pas** :

- elle utilise l'API d'upload défaillante ;
- l'application refuse les certificats auto-signés, sans dérogation possible.

Syncthing la remplace. Le téléphone dépose ses photos dans
`/home/yves/media/photos/yves/`, soit **le dossier même qu'Immich indexe** — un
seul emplacement, pas de stockage dédoublé. Rien ne passe par l'API d'upload, et
le transport de Syncthing est chiffré indépendamment de TLS.

Côté téléphone : partager `DCIM/Camera` en **« Envoi uniquement »**, pour que le
téléphone pousse sans recevoir les 37 Go de la bibliothèque.

L'interface d'administration est sur `http://127.0.0.1:8384`, liée à la boucle
locale car elle n'a pas de mot de passe au premier démarrage.

**Prérequis** : le scan périodique des bibliothèques externes doit être activé
dans l'administration Immich, sinon les photos déposées restent invisibles.

### Détail d'implémentation

L'image officielle `syncthing/syncthing` **ne connaît pas `PUID`/`PGID`** — ce
sont des variables des images LinuxServer. L'utilisateur se fixe par la directive
`user:` du compose. La configuration est sur un volume nommé et non un bind
mount, parce que Docker crée le répertoire hôte en root alors que le processus
tourne en uid 1000 et ne peut alors pas écrire son certificat.

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

Le port `2283` reste exposé en clair. À fermer une fois le HTTPS validé.

### Limite de l'auto-signé

L'application mobile Immich refuse ces certificats. Pour un usage mobile réel :
Let's Encrypt par challenge DNS (demande un domaine, fonctionne sans exposer le
serveur), ou un VPN type Tailscale qui rend TLS superflu.

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

### Perte de données

Le vidage de la corbeille a détruit **75 fichiers, 11,07 Go**, qui n'existaient
nulle part ailleurs. Voir [videos-perdues-corbeille-2026-09-02.md](videos-perdues-corbeille-2026-09-02.md).

Sur 6635 noms en corbeille, 6551 existaient à l'identique dans `files/`
(vérifié par empreinte MD5) : leur suppression était sans perte. Les 84 autres
provenaient du dossier `Camera`, supprimé volontairement le 2026-08-31, dont la
copie vers `Photos/` était incomplète.

## Chantiers ouverts

- **Cause racine de l'API d'upload** — nécessite la sortie texte du client.
- **Fermer le port 2283** une fois le HTTPS validé.
- **Certificat reconnu** (Let's Encrypt DNS ou Tailscale) pour l'usage mobile.
- **Renommer** `NEXTCLOUD_REDIS_PASSWORD` en `IMMICH_REDIS_PASSWORD`.
- **Supprimer l'arborescence Nextcloud** : `www/nextcloud` (873 Mo de code PHP),
  `www/data/nextcloud` (vidé), `docker/syncthing/data` (vide, appartient à root).
- **Aligner tous les conteneurs** sur `personal_cloud` au prochain redémarrage
  complet.
- **Reconnaissance faciale et recherche intelligente** : ne se lancent pas
  d'elles-mêmes sur une bibliothèque importée, à déclencher dans
  Administration → Tâches.
