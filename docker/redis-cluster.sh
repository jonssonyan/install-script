#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  # Redis
  REDIS_CLUSTER_DATA="/jydata/redis-cluster/"
  redis_cluster_ip="jy-redis-cluster"
  redis_cluster_port=6378
  redis_cluster_pass=""
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
  mkdir -p ${REDIS_CLUSTER_DATA}
  mkdir -p ${REDIS_CLUSTER_DATA}data/
}

install_docker() {
  bash <(curl -fsSL https://github.jonssonyan.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_redis_cluster() {
  if [[ -z $(docker ps -q -f "name=^${redis_cluster_ip}$") ]]; then
    echo_content green "---> 安装Redis集群"
  else
    echo_content skyBlue "---> 你已经安装了Redis集群"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_redis_cluster
