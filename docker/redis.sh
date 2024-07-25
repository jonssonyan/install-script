#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  # Redis
  REDIS_DATA="/jydata/redis/"
  redis_ip="jy-redis"
  redis_port=6378
  redis_pass=""
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
  mkdir -p ${REDIS_DATA}
  mkdir -p ${REDIS_DATA}data/
}

install_docker() {
  bash <(curl -fsSL https://github.jonssonyan.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_redis() {
  if [[ -z $(docker ps -q -f "name=^${redis_ip}$") ]]; then
    echo_content green "---> 安装 Redis"

    read -r -p "请输入 Redis 的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入 Redis 的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker pull redis:6.2.13 &&
      docker run -d --name ${redis_ip} --restart always \
        --network=host \
        -e TZ=Asia/Shanghai \
        -v ${REDIS_DATA}data/:/data/ \
        redis:6.2.13 \
        redis-server --requirepass "${redis_pass}" --port "${redis_port}"

    if [[ -n $(docker ps -q -f "name=^${redis_ip}$") ]]; then
      echo_content skyBlue "---> Redis 安装完成"
      echo_content yellow "---> Redis 的数据库密码(请妥善保存): ${redis_pass}"
    else
      echo_content red "---> Redis 安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了 Redis"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_redis
