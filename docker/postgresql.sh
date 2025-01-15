#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  POSTGRESQL_DATA="/jydata/postgresql/"
  postgresql_ip="jy-postgresql"
  postgresql_port=9876
  postgresql_user="postgres"
  postgresql_pas=""
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
  mkdir -p ${POSTGRESQL_DATA}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_postgresql() {
  if [[ -z $(docker ps -q -f "name=^${postgresql_ip}$") ]]; then
    read -r -p "请输入数据库的端口(默认:9876): " postgresql_port
    [[ -z "${postgresql_port}" ]] && postgresql_port=9876
    read -r -p "请输入数据库的用户名(默认:postgres): " postgresql_user
    [[ -z "${postgresql_user}" ]] && postgresql_user="postgres"
    while read -r -p "请输入数据库的密码(必填): " postgresql_pas; do
      if [[ -z "${postgresql_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker pull postgres:13 &&
      docker run -d --name ${postgresql_ip} --restart always \
        --network=host \
        -e POSTGRES_USER="${postgresql_user}" \
        -e POSTGRES_PASSWORD="${postgresql_pas}" \
        -e TZ="Asia/Shanghai" \
        -v ${POSTGRESQL_DATA}data:/var/lib/postgresql/data \
        postgres:13 \
        -c "port=${postgresql_port}"

    if [[ -n $(docker ps -q -f "name=^${postgresql_ip}$") ]]; then
      echo_content skyBlue "---> PostgreSQL 安装完成"
      echo_content yellow "---> PostgreSQL postgres 的数据库密码(请妥善保存): ${postgresql_pas}"
    else
      echo_content red "---> PostgreSQL 安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了 PostgreSQL"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_postgresql
