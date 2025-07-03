#!/usr/bin/env bash
# Nexus3 Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  NEXUS3_DATA="/jydata/nexus3/"
  nexus3_ip="jy-nexus3"
  nexus3_port=8081
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
  mkdir -p ${NEXUS3_DATA}
}

install_nexus3() {
  if [[ -z $(docker ps -q -f "name=^${nexus3_ip}$") ]]; then
    echo_content green "---> 安装Nexus3"

    read -r -p "请输入Nexus3的端口(默认:8081): " nexus3_port
    [[ -z "${nexus3_port}" ]] && nexus3_port=8081

    docker pull sonatype/nexus3:3.49.0 &&
      docker run -d --name ${nexus3_ip} --restart always \
        - p ${nexus3_port}:8081 \
        -v ${NEXUS3_DATA}:/nexus-data \
        -e TZ=Asia/Shanghai \
        sonatype/nexus3:3.49.0

    if [[ -n $(docker ps -q -f "name=^${nexus3_ip}$") ]]; then
      password=$(docker exec ${nexus3_ip} cat /nexus-data/admin.password)
      echo_content skyBlue "---> Nexus3安装完成"
      echo_content yellow "---> Nexus3 admin的密码(请妥善保存): ${password}"
    else
      echo_content red "---> Nexus3安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Nexus3"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_nexus3
