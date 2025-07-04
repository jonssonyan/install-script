#!/usr/bin/env bash
# Nacos Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  NACOS_DATA="/dockerdata/nacos/"
  nacos_ip="jy-nacos"
  nacos_port=8848
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
  mkdir -p ${NACOS_DATA}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_nacos() {
  if [[ -z $(docker ps -q -f "name=^${nacos_ip}$") ]]; then
    echo_content green "---> 安装Nacos"

    read -r -p "请输入Nacos的端口(默认:8848): " nacos_port
    [[ -z "${nacos_port}" ]] && nacos_port=8848

    docker pull nacos/nacos-server:v2.1.2 &&
      docker run -d --name ${nacos_ip} --restart=always \
        --network=host \
        -e MODE=standalone \
        -e NACOS_SERVER_PORT=${nacos_port} \
        -e TZ=Asia/Shanghai \
        nacos/nacos-server:v2.1.2
    if [[ -n $(docker ps -q -f "name=^${nacos_ip}$" -f "status=running") ]]; then
      echo_content skyBlue "---> Nacos安装完成"
      echo_content yellow "---> Nacos的登录地址: http://ip:${nacos_port}/nacos/#/login"
      echo_content yellow "---> Nacos的用户号名(请妥善保存): nacos"
      echo_content yellow "---> Nacos的密码(请妥善保存): nacos"
    else
      echo_content red "---> Nacos安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Nacos"
  fi
}

main() {
  cd "$HOME" || exit 1

  init_var

  create_dirs

  install_docker

  install_nacos
}

main "$@"
