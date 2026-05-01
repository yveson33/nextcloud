.PHONY: help install check ping deploy deploy-nextcloud deploy-portainer deploy-immich restart stop status update clean

# Variables
ANSIBLE_PLAYBOOK = ansible-playbook
ANSIBLE_CFG = ansible.cfg
INVENTORY = inventory/hosts.yml

help: ## Affiche l'aide
	@echo "Commandes disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Installer les dépendances Ansible
	ansible-galaxy collection install -r requirements.yml

check: ## Vérifier la syntaxe des playbooks
	ansible-playbook --syntax-check playbooks/site.yml
	ansible-playbook --syntax-check playbooks/nextcloud.yml
	ansible-playbook --syntax-check playbooks/portainer.yml
	ansible-playbook --syntax-check playbooks/immich.yml

ping: ## Tester la connexion aux hosts
	ansible all -m ping

deploy: ## Déployer tous les services
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/site.yml

deploy-nextcloud: ## Déployer uniquement Nextcloud
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/nextcloud.yml

deploy-portainer: ## Déployer uniquement Portainer
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/portainer.yml

deploy-immich: ## Déployer uniquement Immich
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/immich.yml

restart: ## Redémarrer tous les services
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/site.yml --tags restart

stop: ## Arrêter tous les services
	@echo "Arrêt des services..."
	@cd ../nextcloud && docker compose down || true
	@cd ../common/portainer && docker compose down || true
	@cd ../immich && docker compose down || true

status: ## Afficher le statut des conteneurs
	ansible all -m command -a "docker ps"

update: ## Mettre à jour les images Docker
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/site.yml --tags update

clean: ## Nettoyer les fichiers temporaires
	find . -name "*.retry" -delete
	find . -name "*.log" -delete
	rm -rf /tmp/ansible_facts

lint: ## Linter les fichiers YAML
	ansible-lint playbooks/*.yml
	ansible-lint roles/*/tasks/*.yml

dry-run: ## Exécution à sec (sans modifications)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/site.yml --check --diff
