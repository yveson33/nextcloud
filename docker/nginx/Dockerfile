FROM nginx:1.28.0-alpine-slim


# set main params
ARG BUILD_ARGUMENT_ENV=dev
ENV ENV=$BUILD_ARGUMENT_ENV

RUN apk update && apk upgrade 
RUN apk -q add curl vim libcap  bash

RUN apk add  \
     --virtual build-essentials \
     curl \
     ca-certificates \
     openssl \
     openssl-dev

# create folder for certificates
RUN mkdir -p /etc/nginx/certs

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/server.key -out /etc/nginx/certs/server.crt -subj "/C=FR/ST=ile de france/L=Paris/O=Ybotele/OU=Development/CN=nextcloud.local"

#COPY conf/default.conf /etc/nginx/conf.d/.

WORKDIR /var/www/html