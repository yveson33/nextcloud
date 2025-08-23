#!/usr/bin/env bash

docker network create nginx-proxy

docker-compose up -d --build