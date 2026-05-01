FROM nextcloud:fpm-alpine

RUN apk add --no-cache wget

RUN wget https://getcomposer.org/composer-stable.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer

CMD ["php-fpm"]