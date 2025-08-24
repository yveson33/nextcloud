#!/bin/bash

action=$1
current_path=$(pwd)

case "$action" in
    "start" )
        echo "start all cloud container"
        docker network create nextcloud
        cd $current_path/docker &&  docker compose -f docker-compose.yml build && docker compose -f docker-compose.yml up -d
        cd $current_path/common/portainer &&  docker compose -f docker-compose.yml build && docker compose -f docker-compose.yml up -d
        docker ps
        ;;
    "stop" )
        echo "Stop all cloud container"
        cd $current_path/docker && docker compose -f docker-compose.yml down
        cd $current_path/common/portainer && docker compose -f docker-compose.yml down
        docker ps
        ;;
    * )
        echo "Usage : /etc/init.d/cloud_containers.sh start|stop"
        ;;
esac