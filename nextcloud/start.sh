#!/usr/bin/env bash

docker network create personnal_nextcloud

docker compose up -d --build