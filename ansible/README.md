# Ansible - Infrastructure Nextcloud

Ce projet Ansible permet de déployer et gérer automatiquement votre infrastructure Docker avec Nextcloud, Portainer et Immich.

## 📁 Structure du projet

```
ansible/
├── ansible.cfg              # Configuration Ansible
├── inventory/               # Configuration des hosts
│   ├── hosts.yml           # Définition des hosts et groupes
│   └── group_vars/         # Variables par groupe
│       └── all.yml         # Variables globales
├── playbooks/              # Playbooks Ansible
│   ├── site.yml           # Playbook principal (tous les services)
│   ├── nextcloud.yml      # Playbook Nextcloud uniquement
│   ├── portainer.yml      # Playbook Portainer uniquement
│   └── immich.yml         # Playbook Immich uniquement
├── roles/                  # Rôles Ansible
│   ├── docker/            # Installation et configuration Docker
│   ├── nextcloud/         # Déploiement Nextcloud
│   ├── portainer/         # Déploiement Portainer
│   └── immich/            # Déploiement Immich
├── files/                  # Fichiers statiques à copier
├── templates/              # Templates Jinja2
└── README.md              # Ce fichier
```

## 🚀 Prérequis

### Sur la machine de contrôle (où vous exécutez Ansible)

```bash
# Installer Ansible
pip install ansible

# Ou via Homebrew (macOS)
brew install ansible

# Vérifier l'installation
ansible --version
```

### Sur les machines cibles

- Accès SSH configuré
- Utilisateur avec droits sudo (ou root)
- Python 3 installé

## ⚙️ Configuration

### 1. Configurer l'inventory

Éditez `inventory/hosts.yml` pour ajouter vos serveurs :

```yaml
all:
  children:
    docker_hosts:
      hosts:
        localhost:
          ansible_connection: local
        server1:
          ansible_host: 192.168.1.100
          ansible_user: deploy
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### 2. Configurer les variables

Éditez `inventory/group_vars/all.yml` pour personnaliser :

- Chemins de base
- Ports des services
- Variables d'environnement
- Configuration réseau

### 3. Sécuriser les secrets (recommandé)

Utilisez Ansible Vault pour protéger les mots de passe :

```bash
# Créer un fichier vault
ansible-vault create inventory/group_vars/vault.yml

# Éditer un fichier vault existant
ansible-vault edit inventory/group_vars/vault.yml
```

Dans `vault.yml`, ajoutez :

```yaml
env_vars:
  mysql_root_password: "votre_mot_de_passe_securise"
  mysql_password: "votre_mot_de_passe_securise"
```

Puis référencez-le dans `all.yml` :

```yaml
env_vars: "{{ vault_env_vars }}"
```

## 📋 Utilisation

### Déployer tous les services

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

### Déployer un service spécifique

```bash
# Nextcloud uniquement
ansible-playbook playbooks/nextcloud.yml

# Portainer uniquement
ansible-playbook playbooks/portainer.yml

# Immich uniquement
ansible-playbook playbooks/immich.yml
```

### Utiliser des tags

```bash
# Installer uniquement Docker
ansible-playbook playbooks/site.yml --tags docker

# Déployer uniquement Nextcloud
ansible-playbook playbooks/site.yml --tags nextcloud

# Exclure un service
ansible-playbook playbooks/site.yml --skip-tags immich
```

### Vérifier sans exécuter (dry-run)

```bash
ansible-playbook playbooks/site.yml --check --diff
```

### Limiter à un host spécifique

```bash
ansible-playbook playbooks/site.yml --limit localhost
```

## 🔍 Commandes utiles

### Tester la connexion

```bash
ansible all -m ping
```

### Vérifier les facts

```bash
ansible all -m setup
```

### Exécuter une commande ad-hoc

```bash
# Vérifier Docker
ansible all -m command -a "docker --version"

# Voir les conteneurs
ansible all -m command -a "docker ps"
```

## 📝 Exemples de playbooks personnalisés

### Redémarrer un service

Créez `playbooks/restart-nextcloud.yml` :

```yaml
---
- name: Redémarrer Nextcloud
  hosts: nextcloud_servers
  become: yes
  tasks:
    - name: Redémarrer les conteneurs
      command: docker compose -f {{ services.nextcloud.path }}/docker-compose.yml restart
      args:
        chdir: "{{ services.nextcloud.path }}"
```

### Mettre à jour les images

Créez `playbooks/update-images.yml` :

```yaml
---
- name: Mettre à jour les images Docker
  hosts: docker_hosts
  become: yes
  tasks:
    - name: Pull les dernières images
      command: docker compose -f {{ item }}/docker-compose.yml pull
      loop:
        - "{{ services.nextcloud.path }}"
        - "{{ services.portainer.path }}"
        - "{{ services.immich.path }}"
    
    - name: Redémarrer les services
      command: docker compose -f {{ item }}/docker-compose.yml up -d
      loop:
        - "{{ services.nextcloud.path }}"
        - "{{ services.portainer.path }}"
        - "{{ services.immich.path }}"
```

## 🔒 Sécurité

1. **Ne jamais commiter les secrets** : Utilisez Ansible Vault
2. **Restreindre l'accès SSH** : Utilisez des clés SSH
3. **Limiter les permissions** : Utilisez des utilisateurs avec droits minimaux
4. **Auditer régulièrement** : Vérifiez les logs et les accès

## 🐛 Dépannage

### Problème de connexion SSH

```bash
# Tester la connexion manuellement
ssh user@host

# Vérifier la configuration SSH dans ansible.cfg
```

### Problème de permissions

```bash
# Vérifier les droits sudo
ansible all -m command -a "sudo -l" --become

# Utiliser become_method si nécessaire
ansible-playbook playbooks/site.yml --become-method=su
```

### Problème avec Docker

```bash
# Vérifier que Docker est démarré
ansible all -m systemd -a "name=docker state=started" --become

# Vérifier les permissions Docker
ansible all -m command -a "docker ps"
```

## 📚 Ressources

- [Documentation Ansible](https://docs.ansible.com/)
- [Best Practices Ansible](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

## 🤝 Contribution

Les améliorations sont les bienvenues ! N'hésitez pas à :
- Ouvrir une issue pour signaler un bug
- Proposer une pull request pour une amélioration
- Améliorer la documentation

## 📄 Licence

Ce projet est sous licence MIT.
