FROM nginx:1.18-alpine

LABEL maintainer="jonsosnyan <https://jonssonyan.com>"

RUN apk update \
    && apk add --no-cache bash curl openssl \
    && rm -rf /var/cache/apk/*

RUN curl https://get.acme.sh | sh -s email=my@example.com \
    && ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh

RUN mkdir -p /etc/nginx/ssl /var/www/acme-challenge

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]