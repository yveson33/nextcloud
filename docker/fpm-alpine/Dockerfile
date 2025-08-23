FROM nextcloud:fpm-alpine

RUN apk add --no-cache supervisor \
  && mkdir /var/log/supervisord /var/run/supervisord

RUN apk add --no-cache wget

RUN wget https://getcomposer.org/composer-stable.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer

COPY supervisord.conf /

ENV NEXTCLOUD_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]