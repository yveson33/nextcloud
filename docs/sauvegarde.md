# Stratégie de sauvegarde

État au 2026-09-02 : **aucune sauvegarde des photos n'existe**. Les 71 Go
d'originaux vivent sur un unique SSD, sans copie externe ni RAID. Ce document
propose la marche à suivre.

## Ce qu'il faut protéger

| Chemin | Taille | Remplaçable ? |
|---|---|---|
| `docker/immich/www/immich/external/` | 67 Go | **non** — originaux migrés de Nextcloud |
| `docker/immich/www/immich/machine_server/library/` | 3,8 Go | **non** — photos du mobile |
| base postgres (via `pg_dump`) | 523 Mo | non, mais reconstructible au prix des albums et visages |
| **total** | **71,3 Go** | |

À **exclure** — régénérable par Immich, et représente 6 Go de trafic inutile :

```
machine_server/thumbs/          5,2 Go
machine_server/encoded-video/
machine_learning/               786 Mo
data/redis/
```

## Le principe : 3-2-1

Trois copies, sur deux supports différents, dont une hors du domicile.

| | Aujourd'hui | Objectif |
|---|---|---|
| Copies | 1 | 3 |
| Supports | 1 | 2 |
| Hors site | 0 | 1 |

L'état actuel ne survit à aucun des trois scénarios réalistes : panne du SSD,
vol, incendie.

## Choix retenu : disque externe

**Outil : [restic](https://restic.net/).** Chiffrement, déduplication,
sauvegardes incrémentielles avec historique, et `restic check` pour détecter une
corruption silencieuse.

L'historique est le point décisif ici. Un simple `rsync` propage les
suppressions : effacer une photo par erreur l'efface aussi de la copie à la
synchronisation suivante. Restic garde des instantanés datés, ce qui permet de
remonter dans le temps — exactement ce qui aurait sauvé les 75 vidéos détruites
le 2026-09-02.

Le chiffrement compte même pour un disque qui reste à la maison : s'il est volé,
71 Go de photos personnelles sont illisibles sans la phrase de passe.

**Matériel.** Aucun disque externe n'est actuellement connecté. Prévoir au moins
500 Go — 71 Go aujourd'hui, mais la bibliothèque grossit à chaque photo du
téléphone. 1 To laisse de la marge pour des années.

Formater en **ext4** : natif Linux, robuste, et le dépôt restic n'a pas à être
lisible depuis un autre système puisque restic est nécessaire de toute façon.

**Rétention proposée** : 7 quotidiennes, 4 hebdomadaires, 12 mensuelles.

**Déclenchement.** Le disque n'étant pas branché en permanence, deux approches :

- une règle *udev* qui lance la sauvegarde au branchement — rien à penser ;
- un timer systemd qui vérifie si le disque est monté et passe son tour sinon.

La première est préférable : elle ne dépend pas de la mémoire.

### La limite à connaître

Un disque rangé près du NAS couvre la panne du SSD, mais **ni l'incendie ni le
vol** — les deux appareils partent ensemble.

Deux remèdes, tous deux gratuits :

- le ranger ailleurs qu'à côté de la machine, et le rapporter pour les
  sauvegardes ;
- en avoir deux et les alterner, l'un restant toujours hors du domicile.

C'est ce qui transforme une copie locale en véritable protection.

## Ce qui compte plus que la stratégie

**Une sauvegarde non testée n'est pas une sauvegarde.** Prévoir une restauration
d'essai — quelques photos et la base dans un répertoire temporaire — à la mise
en place, puis une fois par an.

**Attention à la libération d'espace dans l'application Immich.** Elle supprime
les photos du téléphone une fois sauvegardées sur le serveur. Aujourd'hui, le
téléphone est de fait la seule copie de secours des photos récentes ; activer
cette fonction avant d'avoir une vraie sauvegarde reviendrait à supprimer la
dernière redondance existante.

## Ordre d'exécution

1. Brancher le disque externe
2. Le formater en ext4 et le monter
3. Installer restic, initialiser le dépôt, **noter la phrase de passe ailleurs
   que sur cette machine** — sans elle, la sauvegarde est définitivement
   illisible
4. Première sauvegarde complète des 71 Go
5. Déclenchement automatique au branchement (règle udev)
6. Restauration d'essai
7. Décider où ranger le disque, ou en prendre un second à alterner
