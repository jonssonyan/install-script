#!/usr/bin/env bash
# SkyWalking UI Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  SW_DATA="/jydata/skywalking/"

  sw_ui_ip="jy-skywalking-ui"
  sw_ui_port=8080
  sw_oap_url="http://127.0.0.1:12800"
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
  mkdir -p ${SW_DATA}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_skywalking_ui() {
  if [[ -z $(docker ps -q -f "name=^${sw_ui_ip}$") ]]; then
    echo_content green "---> 安装SkyWalking UI"

    read -r -p "请输入SkyWalking UI的端口(默认:8080): " sw_ui_port
    [[ -z "${sw_ui_port}" ]] && sw_ui_port=8080
    read -r -p "请输入SkyWalking OAP的URL(默认:http://127.0.0.1:12800): " sw_oap_url
    [[ -z "${sw_oap_url}" ]] && sw_oap_url="http://127.0.0.1:12800"

    docker pull apache/skywalking-ui:9.5.0 &&
      docker run -d --name ${sw_ui_ip} --restart always \
        --network=host \
        -e TZ=Asia/Shanghai \
        -e SW_SERVER_PORT=${sw_ui_port} \
        -e SW_OAP_ADDRESS="${sw_oap_url}" \
        apache/skywalking-ui:9.5.0

    if [[ -n $(docker ps -q -f "name=^${sw_ui_ip}$" -f "status=running") ]]; then
      echo_content skyBlue "---> SkyWalking UI安装完成"
    else
      echo_content red "---> SkyWalking UI安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了SkyWalking UI"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_skywalking_ui
