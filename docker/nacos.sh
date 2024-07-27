#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  NACOS_DATA="/jydata/nacos/"
  nacos_ip="jy-nacos"
  nacos_port=8848
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
    if [[ -n $(docker ps -q -f "name=^${nacos_ip}$") ]]; then
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

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_nacos
