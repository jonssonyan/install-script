#!/usr/bin/env bash
# Nginx ACME Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  NGINX_ACME_DATA="/dockerdata/nginxacme"
  NGINX_ACME_SSL="${NGINX_ACME_DATA}/ssl"
  NGINX_ACME_CONFD="${NGINX_ACME_DATA}/conf.d"
  NGINX_ACME_LOG="${NGINX_ACME_DATA}/log"

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
  mkdir -p ${NGINX_ACME_LOG}
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
    -v ${NGINX_ACME_LOG}:/var/log/ \
    nginx-acme

  if docker ps -q -f "name=^${nginx_acme_ip}$" &>/dev/null; then
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

    location /.well-known/acme-challenge/ {
        root /var/www/acme-challenge;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

  docker exec ${nginx_acme_ip} nginx -s reload

  echo_content green "---> Requesting SSL certificate for ${domain}"

  docker exec ${nginx_acme_ip} acme.sh --issue -d ${domain} -w /var/www/acme-challenge --server letsencrypt

  echo_content skyBlue "---> Certificate issued successfully"

  # 安装证书
  docker exec ${nginx_acme_ip} acme.sh --install-cert -d "${domain}" \
    --key-file /etc/nginx/ssl/${domain}.key \
    --fullchain-file /etc/nginx/ssl/${domain}.crt \
    --reloadcmd "nginx -s reload"

  cat >"${NGINX_ACME_CONFD}/${domain}.conf" <<EOF
server {
    listen 80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root /var/www/acme-challenge;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate     /etc/nginx/ssl/$domain.crt;
    ssl_certificate_key /etc/nginx/ssl/$domain.key;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    location / {
        proxy_pass $proxy_pass;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
    }
}
EOF

  docker exec ${nginx_acme_ip} nginx -s reload

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
