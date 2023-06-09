#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  NEXUS3_DATA="/jsdata/nexus3/"
  nexus3_ip="js-nexus3"
  nexus3_port=8081
}

echo_content() {
  case $1 in
  "red")
    ${ECHO_TYPE} "\033[31m$2\033[0m"
    ;;
  "green")
    ${ECHO_TYPE} "\033[32m$2\033[0m"
    ;;
  "yellow")
    ${ECHO_TYPE} "\033[33m$2\033[0m"
    ;;
  "blue")
    ${ECHO_TYPE} "\033[34m$2\033[0m"
    ;;
  "purple")
    ${ECHO_TYPE} "\033[35m$2\033[0m"
    ;;
  "skyBlue")
    ${ECHO_TYPE} "\033[36m$2\033[0m"
    ;;
  "white")
    ${ECHO_TYPE} "\033[37m$2\033[0m"
    ;;
  esac
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
        -v ${NEXUS3_DATA}:/nexus-data \
        sonatype/nexus3:3.49.0

    if [[ -n $(docker ps -q -f "name=^${nexus3_ip}$") ]]; then
      echo_content skyBlue "---> Nexus3安装完成"
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
clear
install_docker
install_nexus3
