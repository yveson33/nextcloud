#!/bin/bash

action=$1
projet_path="/home/yves/nextcloud"

case "$action" in
    "start" )
        echo "start all cloud container"
        docker network create nextcloud
        cd $projet_path/docker &&  docker compose -f docker-compose.yml build && docker compose -f docker-compose.yml up -d
        cd $projet_path/common/portainer &&  docker compose -f docker-compose.yml build && docker compose -f docker-compose.yml up -d
        docker ps
        ;;
    "stop" )
        echo "Stop all cloud container"
        cd $projet_path/docker && docker compose -f docker-compose.yml down
        cd $projet_path/common/portainer && docker compose -f docker-compose.yml down
        docker ps
        ;;
    * )
        echo "No action"
        ;;
esac