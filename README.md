# Personal Nextcloud Stack

Un stack Docker complet pour héberger votre propre cloud personnel avec Nextcloud, Portainer et Immich.

## 🏗️ Architecture

Ce projet orchestre trois services principaux via Docker Compose :

- **Nextcloud** : Plateforme de stockage et collaboration cloud
- **Portainer** : Interface de gestion Docker
- **Immich** : Solution de gestion de photos et vidéos

## 📁 Structure du projet

```
nextcloud/
├── personnal_nextcloud          # Script de gestion principal
├── nextcloud/                   # Service Nextcloud
│   ├── docker-compose.yml      # Configuration Nextcloud
│   ├── nginx/                   # Configuration Nginx
│   └── fpm-alpine/             # Image PHP personnalisée
├── common/portainer/           # Service Portainer
│   └── docker-compose.yml
├── immich/                     # Service Immich
│   └── docker-compose.yml
└── data/                       # Données persistantes (gitignorées)
```

## 🚀 Installation et utilisation

### Prérequis

- Docker et Docker Compose installés
- Ports 80, 443, 8081, 9443, 2283 disponibles

### Démarrage rapide

```bash
# Cloner le projet
git clone <votre-repo>
cd nextcloud

# Démarrer tous les services
./personnal_nextcloud start

# Vérifier le statut
./personnal_nextcloud status
```

### Script de gestion

Le script `personnal_nextcloud` permet de gérer l'ensemble des services :

```bash
# Démarrer tous les services
./personnal_nextcloud start

# Arrêter tous les services
./personnal_nextcloud stop

# Redémarrer tous les services
./personnal_nextcloud restart

# Afficher le statut des conteneurs
./personnal_nextcloud status
```

## 🌐 Accès aux services

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **Nextcloud** | `http://localhost` | 80/443 | Interface principale |
| **PhpMyAdmin** | `http://localhost:8081` | 8081 | Gestion base de données |
| **Portainer** | `https://localhost:9443` | 9443 | Interface Docker |
| **Immich** | `http://localhost:2283` | 2283 | Gestion photos/vidéos |

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

Le projet utilise un réseau Docker partagé `personnal_nextcloud` pour permettre la communication entre les services.

## 🔧 Services détaillés

### Nextcloud
- **Base de données** : MariaDB
- **Cache** : Redis
- **Serveur web** : Nginx
- **Application** : PHP-FPM Alpine personnalisé
- **Interface admin** : PhpMyAdmin

### Portainer
- Interface web pour la gestion des conteneurs Docker
- Accès sécurisé via HTTPS

### Immich
- Gestion de photos et vidéos
- Reconnaissance faciale et IA
- Partage et synchronisation

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
./personnal_nextcloud restart
```

## 🐛 Dépannage

### Problèmes courants

1. **Port déjà utilisé** : Vérifiez qu'aucun autre service n'utilise les ports 80, 443, 8081, 9443, 2283
2. **Permissions** : Assurez-vous que Docker a les permissions nécessaires
3. **Réseau** : Le réseau `personnal_nextcloud` doit être créé automatiquement

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

- Le script `personnal_nextcloud` gère automatiquement la création/suppression du réseau Docker
- Les données sont persistantes grâce aux volumes Docker
- Configuration optimisée pour un usage personnel/semi-professionnel

## 🤝 Contribution

Les améliorations et corrections sont les bienvenues via les issues et pull requests.

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.
