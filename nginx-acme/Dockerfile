FROM nginx:1.18-alpine

LABEL maintainer="jonsosnyan <https://jonssonyan.com>"

RUN apk add --no-cache bash curl openssl

RUN curl https://get.acme.sh | sh -s email=my@example.com

RUN mkdir -p /etc/nginx/ssl /var/www/acme-challenge

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80