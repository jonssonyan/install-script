#!/usr/bin/env bash
# Docker buildx Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  buildx_ip="jy-buildx"
  DOCKER_CONFIG_PATH='/root/.docker/'
  docker_config='/root/.docker/config.json'
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
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_buildx() {
  if docker buildx inspect --bootstrap | grep -q "${buildx_ip}"; then
    echo_content skyBlue "---> buildx is already installed"
    return
  fi

  echo_content skyBlue "---> Installing buildx"

  mkdir -p "${DOCKER_CONFIG_PATH}"
  if [[ -f "${docker_config}" ]]; then
    if ! grep -q "experimental" "${docker_config}"; then
      jq '.experimental="enabled"' "${docker_config}" >"${docker_config}.tmp" && mv "${docker_config}.tmp" "${docker_config}"
    fi
  else
    cat >"${docker_config}" <<EOF
{
  "experimental": "enabled"
}
EOF
  fi

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
