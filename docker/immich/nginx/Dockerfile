FROM nginx:1.28.0-alpine-slim

RUN apk update && apk upgrade
RUN apk -q add openssl

RUN mkdir -p /etc/nginx/certs

# Certificat auto-signé valable 10 ans, avec SAN pour couvrir le nom d'hôte,
# l'IP du LAN et localhost (sans SAN, les navigateurs récents rejettent le CN seul).
RUN printf '%s\n' \
      '[req]' \
      'distinguished_name = dn' \
      'x509_extensions = ext' \
      'prompt = no' \
      '[dn]' \
      'C = FR' \
      'ST = Ile-de-France' \
      'O = Ybotele' \
      'CN = immich.local' \
      '[ext]' \
      'subjectAltName = DNS:immich.local, DNS:yves-nas-hp, DNS:localhost, IP:192.168.1.199, IP:127.0.0.1' \
      'basicConstraints = CA:FALSE' \
      'keyUsage = digitalSignature, keyEncipherment' \
      'extendedKeyUsage = serverAuth' \
    > /tmp/openssl.cnf \
 && openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/nginx/certs/server.key \
      -out /etc/nginx/certs/server.crt \
      -config /tmp/openssl.cnf \
 && rm /tmp/openssl.cnf
