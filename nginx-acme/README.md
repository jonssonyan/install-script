# Nginx with acme.sh

## Quick Start

```bash
bash <(curl -fsSL https://github.com/jonssonyan/install-script/blob/main/nginx-acme/install.sh)
```

## File directory

- Host
    - nginx config: /dockerdata/nginxacme/conf.d
    - nginx ssl: /dockerdata/nginxacme/ssl
    - nginx log: /dockerdata/nginxacme/log
- Container
    - acme: /root/.acme.sh
    - webroot: /var/www/acme-challenge
    - nginx config: /etc/nginx/conf.d
    - nginx ssl: /etc/nginx/ssl
    - nginx log: /var/log/nginx

## Reference

1. https://github.com/acmesh-official/acme.sh
