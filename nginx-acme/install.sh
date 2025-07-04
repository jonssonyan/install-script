#!/usr/bin/env bash
# Nginx ACME Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  NGINX_ACME_DATA="/nginxacmedata"
  NGINX_ACME_SSL="${NGINX_ACME_DATA}/ssl"
  NGINX_ACME_CONFD="${NGINX_ACME_DATA}/conf.d"

  nginx_acme_ip="jy-nginx-acme"
  domain=""
  proxy_pass=""
}

echo_content() {
  local color_code
  case $1 in
  "red") color_code="\033[31m" ;;
  "green") color_code="\033[32m" ;;
  "yellow") color_code="\033[33m" ;;
  "blue") color_code="\033[34m" ;;
  "purple") color_code="\033[35m" ;;
  "skyBlue") color_code="\033[36m" ;;
  "white") color_code="\033[37m" ;;
  *) color_code="\033[0m" ;;
  esac
  ${ECHO_TYPE} "${color_code}$2\033[0m"
}

create_dirs() {
  mkdir -p ${NGINX_ACME_DATA}
  mkdir -p ${NGINX_ACME_SSL}
  mkdir -p ${NGINX_ACME_CONFD}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_nginx_acme() {
  if docker ps -q -f "name=^${nginx_acme_ip}$" &>/dev/null; then
    echo_content skyBlue "Nginx ACME is already installed"
    return
  fi

  echo_content green "---> Installing Nginx ACME"

  docker run -d --name ${nginx_acme_ip} --restart always \
    --network=host \
    -v ${NGINX_ACME_SSL}:/etc/nginx/ssl/ \
    -v ${NGINX_ACME_CONFD}:/etc/nginx/conf.d/ \
    nginx-acme:latest

  if [[ -n $(docker ps -q -f "name=^${nginx_acme_ip}$") ]]; then
    echo_content skyBlue "---> Nginx ACME installation complete"
  else
    echo_content red "---> Nginx ACME installation failed"
    exit 1
  fi
}

add_domain() {
  while read -r -p "Please input your Domain(Required): " domain; do
    if [[ -z "${domain}" ]]; then
      echo_content red "Domain required"
    else
      break
    fi
  done

  while read -r -p "Please input your Proxy pass(Required): " proxy_pass; do
    if [[ -z "${proxy_pass}" ]]; then
      echo_content red "Proxy pass required"
    else
      break
    fi
  done

  cat >"${NGINX_ACME_CONFD}/${domain}.conf" <<EOF
server {
    listen 80;
    server_name $domain;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/acme-challenge;
        default_type "text/plain";
        try_files \$uri =404;
    }

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain;

    ssl_certificate     /etc/nginx/ssl/$domain.crt;
    ssl_certificate_key /etc/nginx/ssl/$domain.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass $proxy_pass;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

  docker exec ${nginx_acme_ip} nginx -s reload
  docker exec ${nginx_acme_ip} acme.sh --issue --nginx -d ${domain}
  docker exec ${nginx_acme_ip} acme.sh --install-cert -d "${domain}" \
    --key-file /etc/nginx/ssl/${domain}.key \
    --fullchain-file /etc/nginx/ssl/${domain}.crt \
    --reloadcmd "nginx -s reload"
  echo_content skyBlue "---> Domain ${domain} added successfully"
}

main() {
  cd "$HOME" || exit 1

  init_var

  create_dirs

  install_docker

  install_nginx_acme

  add_domain
}

main "$@"
