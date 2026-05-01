#!/usr/bin/env python3

"""
Gestionnaire de conteneurs Docker pour Nextcloud
Script de gestion des conteneurs Docker pour Nextcloud et Portainer.
Permet de démarrer, arrêter, redémarrer et surveiller les services
cloud personnels de manière automatisée.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Tuple


class DockerServiceManager:
    """Gestionnaire de services Docker pour Nextcloud, Portainer et Immich."""
    
    def __init__(self, base_path: str = None):
        """Initialise le gestionnaire avec les chemins des services."""
        self.current_path = Path(base_path) if base_path else Path.cwd()
        
        # Variables des services avec leurs chemins (ordre important pour les dépendances)
        self.services: Dict[str, Path] = {
            "nextcloud": self.current_path / "docker/nextcloud",
            "portainer": self.current_path / "docker/portainer",
            "immich": self.current_path / "docker/immich"
        }
        
        # Variables des actions disponibles
        self.actions: Dict[str, str] = {
            "stop": "Arrêter",
            "restart": "Redémarrer",
            "start": "Démarrer",
            "status": "Afficher le statut"
        }
    
    def show_status(self) -> None:
        """Affiche le statut des conteneurs Docker."""
        print("=== Statut des conteneurs Docker ===")
        try:
            result = subprocess.run(
                ["docker", "ps"],
                check=True,
                capture_output=False
            )
        except subprocess.CalledProcessError as e:
            print(f"❌ Erreur lors de l'affichage du statut: {e}")
            sys.exit(1)
    
    def manage_service(self, service_name: str, service_path: Path, action: str) -> bool:
        """
        Gère un service Docker (start, stop, restart).
        
        Args:
            service_name: Nom du service
            service_path: Chemin vers le répertoire du service
            action: Action à effectuer (start, stop, restart)
        
        Returns:
            True si l'action a réussi, False sinon
        """
        action_text = self.actions.get(action, action)
        print(f"→ {action_text} le service: {service_name}")
        
        if not service_path.exists() or not service_path.is_dir():
            print(f"  ❌ Répertoire non trouvé: {service_path}")
            return False
        
        docker_compose_file = service_path / "docker-compose.yml"
        if not docker_compose_file.exists():
            print(f"  ❌ Fichier docker-compose.yml non trouvé: {docker_compose_file}")
            return False
        
        try:
            if action in ["start", "restart"]:
                # Build et up
                print(f"  🔨 Construction des images...")
                build_result = subprocess.run(
                    ["docker", "compose", "-f", str(docker_compose_file), "build"],
                    cwd=str(service_path),
                    check=False
                )
                
                if build_result.returncode != 0:
                    print(f"  ⚠️  Avertissement: La construction a échoué, continuation...")
                
                print(f"  🚀 Démarrage des conteneurs...")
                up_result = subprocess.run(
                    ["docker", "compose", "-f", str(docker_compose_file), "up", "-d"],
                    cwd=str(service_path),
                    check=True
                )
                
            elif action == "stop":
                # Down
                print(f"  🛑 Arrêt des conteneurs...")
                subprocess.run(
                    ["docker", "compose", "-f", str(docker_compose_file), "down"],
                    cwd=str(service_path),
                    check=True
                )
            
            print(f"  ✅ {service_name}: {action_text} réussi")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"  ❌ {service_name}: {action_text} échoué")
            print(f"     Erreur: {e}")
            return False
        except Exception as e:
            print(f"  ❌ {service_name}: Erreur inattendue: {e}")
            return False
    
    def manage_network(self, action: str) -> None:
        """
        Gère le réseau Docker personnalisé.
        
        Args:
            action: Action à effectuer (start, stop)
        """
        network_name = "personnal_nextcloud"
        
        if action == "start":
            print(f"🌐 Création du réseau Docker: {network_name}")
            result = subprocess.run(
                ["docker", "network", "create", network_name],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print(f"  ✅ Réseau créé")
            else:
                if "already exists" in result.stderr.lower():
                    print(f"  ℹ️  Le réseau existe déjà")
                else:
                    print(f"  ⚠️  Erreur lors de la création du réseau: {result.stderr}")
        
        elif action == "stop":
            print(f"🗑️  Suppression du réseau Docker: {network_name}")
            result = subprocess.run(
                ["docker", "network", "rm", network_name],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print(f"  ✅ Réseau supprimé")
            else:
                if "does not exist" in result.stderr.lower() or "not found" in result.stderr.lower():
                    print(f"  ℹ️  Le réseau n'existe pas")
                else:
                    print(f"  ⚠️  Erreur lors de la suppression du réseau: {result.stderr}")
    
    def manage_all_services(self, action: str) -> bool:
        """
        Gère tous les services Docker.
        
        Args:
            action: Action à effectuer (start, stop, restart)
        
        Returns:
            True si toutes les actions ont réussi, False sinon
        """
        action_text = self.actions.get(action, action)
        
        print("=== Gestion des services cloud ===")
        print(f"Action: {action_text}")
        print()
        
        # Gestion du réseau pour start/stop
        if action == "start":
            self.manage_network("start")
        elif action == "stop":
            self.manage_network("stop")
        
        print()
        
        # Gestion de chaque service
        success = True
        services_list = ["nextcloud", "portainer", "immich"]
        
        for service_name in services_list:
            service_path = self.services.get(service_name)
            if service_path:
                if not self.manage_service(service_name, service_path, action):
                    success = False
                print()
            else:
                print(f"❌ Service non trouvé: {service_name}")
                success = False
                print()
        
        # Affichage du statut final
        self.show_status()
        print()
        
        if success:
            print(f"🎉 Tous les services ont été {action_text.lower()} avec succès!")
            return True
        else:
            print("⚠️  Certains services ont rencontré des problèmes")
            return False


def main():
    """Fonction principale du script."""
    parser = argparse.ArgumentParser(
        description="Gestionnaire de conteneurs Docker pour Nextcloud",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Actions disponibles:
  start    - Démarrer tous les services
  stop     - Arrêter tous les services
  restart  - Redémarrer tous les services
  status   - Afficher le statut des conteneurs

Services gérés:
  • nextcloud: ./nextcloud
  • portainer: ./common/portainer
  • immich: ./immich
        """
    )
    
    parser.add_argument(
        "action",
        choices=["start", "stop", "restart", "status"],
        help="Action à effectuer"
    )
    
    parser.add_argument(
        "--path",
        type=str,
        default=None,
        help="Chemin de base pour les services (défaut: répertoire courant)"
    )
    
    args = parser.parse_args()
    
    # Initialisation du gestionnaire
    manager = DockerServiceManager(base_path=args.path)
    
    # Exécution de l'action
    action_icons = {
        "restart": "🔄",
        "start": "🚀",
        "stop": "🛑",
        "status": "📊"
    }
    
    icon = action_icons.get(args.action, "▶️")
    print(f"{icon} {manager.actions.get(args.action, args.action).title()} des conteneurs cloud")
    print()
    
    if args.action == "status":
        manager.show_status()
        sys.exit(0)
    else:
        success = manager.manage_all_services(args.action)
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()