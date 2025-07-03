#!/usr/bin/env bash
# SkyWalking Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  can_google=0

  SW_DATA="/jydata/skywalking/"
  SW_DATA_OAP_LIBS="${SW_DATA}oap-libs/"
  sw_oap_ip="jy-skywalking-oap"
  sw_oap_http=12800
  sw_oap_grpc=11800

  es_url="http://127.0.0.1:9200"
  es_username="elastic"
  es_password="elastic"

  mysql_jdbc_url="jdbc:mysql://127.0.0.1:9507/skywalking"
  mysql_user="root"
  mysql_pass="123456"

  mysql_connector_java_url_aliyun="https://mirrors.aliyun.com/mysql/Connector-J/mysql-connector-java-8.0.28.tar.gz"
  mysql_connector_java_url="https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar"
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

can_connect() {
  if ping -c2 -i0.3 -W1 "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

mkdir_tools() {
  mkdir -p ${SW_DATA}
  mkdir -p ${SW_DATA_OAP_LIBS}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_skywalking() {
  if [[ -z $(docker ps -q -f "name=^${sw_oap_ip}$") ]]; then
    echo_content green "---> 安装SkyWalking OAP"

    echo_content green "---> 设置SkyWalking OAP存储方式"
    echo_content yellow "1. Elasticsearch7"
    echo_content yellow "2. MySQL"
    read -r -p "请选择(默认:1): " sw_storage
    [[ -z "${sw_storage}" ]] && sw_storage=1

    if [[ "${sw_storage}" == "1" ]]; then
      read -r -p "请输入Elasticsearch的URL(默认:http://127.0.0.1:9200): " es_url
      [[ -z "${es_url}" ]] && es_url="http://127.0.0.1:9200"
      read -r -p "请输入Elasticsearch的用户名(默认:elastic): " es_username
      [[ -z "${es_username}" ]] && es_username="elastic"
      read -r -p "请输入Elasticsearch的密码(默认:elastic): " es_password
      [[ -z "${es_password}" ]] && es_password="elastic"

      docker pull apache/skywalking-oap-server:9.5.0 &&
        docker run -d --name ${sw_oap_ip} --restart always \
          --network=host \
          -e TZ=Asia/Shanghai \
          -e SW_CORE_REST_PORT=${sw_oap_http} \
          -e SW_CORE_GRPC_PORT=${sw_oap_grpc} \
          -e SW_STORAGE=elasticsearch \
          -e SW_STORAGE_ES_CLUSTER_NODES="${es_url}" \
          -e SW_ES_USER="${es_username}" \
          -e SW_ES_PASSWORD="${es_password}" \
          apache/skywalking-oap-server:9.5.0
    elif [[ "${sw_storage}" == "2" ]]; then
      read -r -p "请输入MySQL的JDBC URL(默认:jdbc:mysql://127.0.0.1:9507/skywalking): " mysql_jdbc_url
      [[ -z "${mysql_jdbc_url}" ]] && mysql_jdbc_url="jdbc:mysql://127.0.0.1:9507/skywalking"
      read -r -p "请输入数据库的用户名(默认:root): " mysql_user
      [[ -z "${mysql_user}" ]] && mysql_user="root"
      while read -r -p "请输入数据库的密码(必填): " mysql_pass; do
        if [[ -z "${mysql_pass}" ]]; then
          echo_content red "密码不能为空"
        else
          break
        fi
      done

      # 下载MySQL驱动
      can_connect www.google.com && can_google=1

      if [[ ${can_google} == 0 ]]; then
        wget -c ${mysql_connector_java_url_aliyun} -O ${SW_DATA_OAP_LIBS}mysql-connector-java-8.0.28.tar.gz &&
          tar -zxvf ${SW_DATA_OAP_LIBS}mysql-connector-java-8.0.28.tar.gz -C ${SW_DATA_OAP_LIBS} &&
          cp ${SW_DATA_OAP_LIBS}mysql-connector-java-8.0.28/mysql-connector-java-8.0.28.jar ${SW_DATA_OAP_LIBS}
      else
        wget -c ${mysql_connector_java_url} -O ${SW_DATA_OAP_LIBS}mysql-connector-java-8.0.28.jar
      fi
      docker pull apache/skywalking-oap-server:9.5.0 &&
        docker run -d --name ${sw_oap_ip} --restart always \
          --network=host \
          -e TZ=Asia/Shanghai \
          -e SW_CORE_REST_PORT=${sw_oap_http} \
          -e SW_CORE_GRPC_PORT=${sw_oap_grpc} \
          -e SW_STORAGE=mysql \
          -e SW_JDBC_URL="${mysql_jdbc_url}" \
          -e SW_DATA_SOURCE_USER="${mysql_user}" \
          -e SW_DATA_SOURCE_PASSWORD="${mysql_pass}" \
          -v ${SW_DATA_OAP_LIBS}mysql-connector-java-8.0.28.jar:/skywalking/oap-libs/mysql-connector-java-8.0.28.jar \
          apache/skywalking-oap-server:9.5.0
    fi

    if [[ -n $(docker ps -q -f "name=^${sw_oap_ip}$" -f "status=running") ]]; then
      echo_content skyBlue "---> SkyWalking OAP安装完成"
    else
      echo_content red "---> SkyWalking OAP安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了SkyWalking OAP"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_skywalking
