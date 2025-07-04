FROM nginx:1.18-alpine

LABEL maintainer="jonsosnyan <https://jonssonyan.com>"

ENV EMAIL=my@example.com

RUN apk update \
    && apk add --no-cache bash curl socat openssl \
    && rm -rf /var/cache/apk/*

RUN curl https://get.acme.sh | sh -s email=${EMAIL} \
    && ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh

RUN mkdir -p /etc/nginx/ssl /var/www/acme-challenge/.well-known/acme-challenge

COPY nginx.conf /etc/nginx/nginx.conf