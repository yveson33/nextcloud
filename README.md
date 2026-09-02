# Personal Cloud Stack

Un stack Docker pour héberger votre propre cloud personnel avec Immich et Portainer. Nextcloud est **déprécié** et n'est plus démarré par défaut (voir [Nextcloud (déprécié)](#nextcloud-déprécié)).

## 🏗️ Architecture

Ce projet orchestre par défaut deux services via Docker Compose :

- **Immich** : Solution de gestion de photos et vidéos (service principal)
- **Portainer** : Interface de gestion Docker

- ~~**Nextcloud** : Plateforme de stockage et collaboration cloud~~ (déprécié, gestion manuelle uniquement)

## 📁 Structure du projet

```
#nextcloud/
├── personal_cloud # Script de gestion principal (bash)
├── cloud_services.py # Script de gestion principal (Python)
├── docker/ # Services Docker
│ ├── nextcloud/ # Service Nextcloud
│ ├── portainer/ # Service Portainer
│ └── immich/ # Service Immich
├── ansible/ # Automatisation Ansible
├── www/ # Fichiers Nextcloud
├── data/ # Données persistantes (gitignorées)
└── README.md # Ce fichier Données persistantes (gitignorées)
```

## 🚀 Installation et utilisation

### Prérequis

- Docker et Docker Compose installés
- Ports 9443, 2283 disponibles par défaut (+ 80, 443, 8081 si Nextcloud est démarré manuellement)

### Démarrage rapide

```bash
# Cloner le projet
git clone <votre-repo>
cd nextcloud

# Démarrer les services par défaut (Immich + Portainer)
./personal_cloud start

# Vérifier le statut
./personal_cloud status
```

### Script de gestion

Le script `personal_cloud` permet de gérer l'ensemble des services :

```bash
# Démarrer les services par défaut (Immich + Portainer)
./personal_cloud start

# Arrêter les services par défaut
./personal_cloud stop

# Redémarrer les services par défaut
./personal_cloud restart

# Afficher le statut des conteneurs
./personal_cloud status

# Gérer manuellement Nextcloud (déprécié)
./personal_cloud nextcloud start
./personal_cloud nextcloud stop
```

Le script Python `cloud_services.py` propose les mêmes actions (`start`, `stop`, `restart`, `status`, `nextcloud <start|stop|restart>`).

## 🌐 Accès aux services

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **Immich** | `http://localhost:2283` | 2283 | Interface principale (photos/vidéos) |
| **Portainer** | `https://localhost:9443` | 9443 | Interface Docker |
| **Nextcloud** (déprécié) | `http://localhost` | 80/443 | Démarrage manuel uniquement |
| **PhpMyAdmin** (déprécié) | `http://localhost:8081` | 8081 | Lié à Nextcloud, démarrage manuel uniquement |

## ⚙️ Configuration

### Variables d'environnement

Créez un fichier `.env` à la racine du projet :

```env
# Nextcloud
PROJECT_NAME=nextcloud
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_PASSWORD=your_db_password
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud

# Immich
IMMICH_VERSION=release
POSTGRES_DB_PASSWORD=your_postgres_password
POSTGRES_DB_USER=postgres
POSTGRES_DB_NAME=immich
```

### Réseau Docker

Le projet utilise un réseau Docker partagé `personal_cloud` pour permettre la communication entre les services.

## 🔧 Services détaillés

### Immich (service par défaut)
- Gestion de photos et vidéos
- Reconnaissance faciale et IA
- Partage et synchronisation

### Portainer
- Interface web pour la gestion des conteneurs Docker
- Accès sécurisé via HTTPS

### Nextcloud (déprécié)
- **Base de données** : MariaDB
- **Cache** : Redis
- **Serveur web** : Nginx
- **Application** : PHP-FPM Alpine personnalisé
- **Interface admin** : PhpMyAdmin

Nextcloud n'est plus démarré automatiquement. Le code, les données (`data/nextcloud/`, `data/mysql/`) et le docker-compose restent dans le repo pour permettre un redémarrage manuel :

```bash
./personal_cloud nextcloud start
```

## 📊 Surveillance et logs

```bash
# Voir les logs d'un service
docker logs nextcloud_APP

# Surveiller les conteneurs
docker ps

# Voir l'utilisation des ressources
docker stats
```

## 🔒 Sécurité

- Les services internes (DB, Redis) ne sont pas exposés directement
- Utilisation de réseaux Docker isolés
- Configuration HTTPS pour Portainer
- Gestion des volumes persistants

## 🛠️ Maintenance

### Sauvegarde
Les données sont stockées dans le dossier `data/` :
- `data/nextcloud/` : Fichiers Nextcloud
- `data/mysql/` : Base de données
- `data/immich/` : Photos et métadonnées

### Mise à jour
```bash
# Redémarrer avec les dernières images
./personal_cloud restart
```

## 🐛 Dépannage

### Problèmes courants

1. **Port déjà utilisé** : Vérifiez qu'aucun autre service n'utilise les ports 80, 443, 8081, 9443, 2283
2. **Permissions** : Assurez-vous que Docker a les permissions nécessaires
3. **Réseau** : Le réseau `personal_cloud` doit être créé automatiquement

### Logs utiles
```bash
# Logs Nextcloud
docker logs nextcloud_APP

# Logs Nginx
docker logs nextcloud_NGINX

# Logs Immich
docker logs nextcloud_immich_server
```

## 📝 Notes

- Le script `personal_cloud` gère automatiquement la création/suppression du réseau Docker
- Les données sont persistantes grâce aux volumes Docker
- Configuration optimisée pour un usage personnel/semi-professionnel

## 🤝 Contribution

Les améliorations et corrections sont les bienvenues via les issues et pull requests.

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.
