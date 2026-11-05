#!/usr/bin/env bash
# Docker buildx Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  buildx_ip="jy-buildx"
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

install_docker() {
  command -v docker &>/dev/null || bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_buildx() {
  if docker buildx inspect "${buildx_ip}" &>/dev/null; then
    docker buildx use "${buildx_ip}"
    echo_content skyBlue "---> buildx is already installed"
    return
  fi

  echo_content skyBlue "---> Installing buildx"

  docker buildx create --use --name ${buildx_ip} &&
    docker run --privileged --rm tonistiigi/binfmt --install all

  if docker buildx inspect --bootstrap | grep -q "${buildx_ip}"; then
    echo_content skyBlue "---> buildx installation complete"
  else
    echo_content red "---> buildx installation failed"
    exit 1
  fi
}

main() {
  cd "$HOME" || exit 1

  init_var

  install_docker

  install_buildx
}

main "$@"
