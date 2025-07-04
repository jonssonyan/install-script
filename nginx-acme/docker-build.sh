#!/usr/bin/env bash
# Nginx ACME Docker push Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  image_name="jonssonyan/nginx-acme"
  version=0.1.0
  arch_arr="linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64,linux/ppc64le,linux/s390x"
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

docker_push() {
  echo_content skyBlue "Start build CPU: ${arch_arr}"

  if [[ "${version}" != "latest" ]]; then
    docker buildx build -t ${image_name}:${version} --platform ${arch_arr} --push .
    if [[ "$?" == "0" ]]; then
      echo_content skyBlue "Version: ${version} CPU: ${arch_arr} build success"
    else
      echo_content red "Version: ${version} CPU: ${arch_arr} build failed"
    fi
  fi

  docker buildx build -t ${image_name}:latest --platform ${arch_arr} --push .
  if [[ "$?" == "0" ]]; then
    echo_content skyBlue "Version: latest CPU: ${arch_arr} build success"
  else
    echo_content red "Version: latest CPU: ${arch_arr} build failed"
  fi

  echo_content skyBlue "CPU: ${arch_arr} build finished"
}

main() {
  cd "$HOME" || exit 1

  init_var

  docker_push
}

main "$@"
