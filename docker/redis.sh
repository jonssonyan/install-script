#!/usr/bin/env bash
# Redis Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  # Redis
  REDIS_DATA="/dockerdata/redis/"
  redis_ip="jy-redis"
  redis_port=6378
  redis_pass=""
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
  mkdir -p ${REDIS_DATA}
  mkdir -p ${REDIS_DATA}data/
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_redis() {
  if [[ -z $(docker ps -q -f "name=^${redis_ip}$") ]]; then
    echo_content skyBlue "---> 安装 Redis"

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
        -v ${REDIS_DATA}etc/:/usr/local/etc/redis/ \
        redis:6.2.13 \
        redis-server --requirepass "${redis_pass}" --port "${redis_port}"

    if [[ -n $(docker ps -q -f "name=^${redis_ip}$" -f "status=running") ]]; then
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

main() {
  cd "$HOME" || exit 1

  init_var

  create_dirs

  install_docker

  install_redis
}

main "$@"
