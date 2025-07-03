#!/usr/bin/env bash
# RustDesk Server Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

# https://rustdesk.com/docs/zh-cn/self-host/rustdesk-server-oss/install/#docker示范

init_var() {
  ECHO_TYPE="echo -e"

  # RustDesk Server
  RUSTDESK_SERVER="/jydata/rustdesk-server/"
  # hbbr RustDesk 中继服务器
  rustdesk_server_hbbr="jy-rustdesk-server-hbbr"
  # hbbs RustDesk ID注册服务器
  rustdesk_server_hbbs="jy-rustdesk-server-hbbs"
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

mkdir_tools() {
  mkdir -p ${RUSTDESK_SERVER}
  mkdir -p ${RUSTDESK_SERVER}data/
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_rustdesk_bbr() {
  if [[ -z $(docker ps -q -f "name=^${rustdesk_server_hbbr}$") ]]; then
    echo_content green "---> 安装 RustDesk Server hbbr"

    docker run -d --name ${rustdesk_server_hbbr} --restart always \
      --network=host \
      -e TZ=Asia/Shanghai \
      -v ${RUSTDESK_SERVER}data/:/root/ \
      rustdesk/rustdesk-server hbbr

  else
    echo_content skyBlue "---> 你已经安装了 RustDesk Server hbbr"
  fi

  if [[ -z $(docker ps -q -f "name=^${rustdesk_server_hbbr}$") ]]; then
    install_rustdesk_hbbs
  fi

}

install_rustdesk_hbbs() {
  if [[ -z $(docker ps -q -f "name=^${rustdesk_server_hbbs}$") ]]; then
    echo_content green "---> 安装 RustDesk Server hbbs"

    docker run -d --name ${rustdesk_server_hbbs} --restart always \
      --network=host \
      -e TZ=Asia/Shanghai \
      -v ${RUSTDESK_SERVER}data/:/root/ \
      rustdesk/rustdesk-server hbbs

  else
    echo_content skyBlue "---> 你已经安装了 RustDesk Server hbbs"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_rustdesk_bbr
