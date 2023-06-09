#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  MySQL_DATA="/jsdata/mysql/"
  mysql_ip="js-mysql"
  mysql_port=9507
  mysql_user="root"
  mysql_pas=""
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
  mkdir -p ${MySQL_DATA}
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_mysql() {
  if [[ -z $(docker ps -q -f "name=^${mysql_ip}$") ]]; then
    echo_content green "---> 安装MySQL"

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
      docker pull mysql:5.7.38 &&
        docker run -d --name ${mysql_ip} --restart always \
          --network=host \
          -v ${MySQL_DATA}:/var/lib/mysql \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          mysql:5.7.38 \
          --port ${mysql_port} \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    else
      docker pull mysql:5.7.38 &&
        docker run -d --name ${mysql_ip} --restart always \
          --network=host \
          -v ${MySQL_DATA}:/var/lib/mysql \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e MYSQL_USER="${mysql_user}" \
          -e MYSQL_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          mysql:5.7.38 \
          --port ${mysql_port} \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    fi

    if [[ -n $(docker ps -q -f "name=^${mysql_ip}$") ]]; then
      echo_content skyBlue "---> MySQL安装完成"
      echo_content yellow "---> MySQL root的数据库密码(请妥善保存): ${mysql_pas}"
      if [[ "${mysql_user}" != "root" ]]; then
        echo_content yellow "---> MySQL ${mysql_user}的数据库密码(请妥善保存): ${mysql_pas}"
      fi
    else
      echo_content red "---> MySQL安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了MySQL"
  fi
}

cd "$HOME" || exit 0
init_var
clear
install_docker
install_mysql
