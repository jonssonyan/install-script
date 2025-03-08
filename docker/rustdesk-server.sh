#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

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
