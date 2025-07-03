#!/usr/bin/env bash
# MySQL Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  MySQL_DATA="/jydata/mysql/"
  mysql_ip="jy-mysql"
  mysql_port=9507
  mysql_user="root"
  mysql_pas=""
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
  mkdir -p ${MySQL_DATA}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_mysql() {
  if [[ -z $(docker ps -q -f "name=^${mysql_ip}$") ]]; then
    echo_content green "---> 安装 MySQL"

    read -r -p "请输入数据库的端口(默认:9507): " mysql_port
    [[ -z "${mysql_port}" ]] && mysql_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mysql_user
    [[ -z "${mysql_user}" ]] && mysql_user="root"
    while read -r -p "请输入数据库的密码(必填): " mysql_pas; do
      if [[ -z "${mysql_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    if [[ "${mysql_user}" == "root" ]]; then
      docker pull mysql:5.7.42 &&
        docker run -d --name ${mysql_ip} --restart always \
          --network=host \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          -v ${MySQL_DATA}:/var/lib/mysql \
          mysql:5.7.42 \
          --port ${mysql_port} \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    else
      docker pull mysql:5.7.42 &&
        docker run -d --name ${mysql_ip} --restart always \
          --network=host \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e MYSQL_USER="${mysql_user}" \
          -e MYSQL_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          -v ${MySQL_DATA}:/var/lib/mysql \
          mysql:5.7.42 \
          --port ${mysql_port} \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    fi

    if [[ -n $(docker ps -q -f "name=^${mysql_ip}$") ]]; then
      echo_content skyBlue "---> MySQL 安装完成"
      echo_content yellow "---> MySQL root 的数据库密码(请妥善保存): ${mysql_pas}"
      if [[ "${mysql_user}" != "root" ]]; then
        echo_content yellow "---> MySQL ${mysql_user}的数据库密码(请妥善保存): ${mysql_pas}"
      fi
    else
      echo_content red "---> MySQL 安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了 MySQL"
  fi
}

main() {
  cd "$HOME" || exit 1

  init_var

  create_dirs

  install_docker

  install_mysql
}

main "$@"
