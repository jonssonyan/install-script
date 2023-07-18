#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  SW_DATA="/jsdata/skywalking/"
  sw_oap_ip="js-skywalking-oap"
  sw_oap_http=12800
  sw_oap_grpc=11800

  es_url="http://127.0.0.1:9200"
  es_username="elastic"
  es_password="elastic"

  mysql_jdbc_url="jdbc:mysql://127.0.0.1:9507/skywalking"
  mysql_user="root"
  mysql_pass="123456"
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
  mkdir -p ${SW_DATA}
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
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

      docker run --name ${sw_oap_ip} --restart always \
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

      docker run --name ${sw_oap_ip} --restart always \
        --network=host \
        -e TZ=Asia/Shanghai \
        -e SW_CORE_REST_PORT=${sw_oap_http} \
        -e SW_CORE_GRPC_PORT=${sw_oap_grpc} \
        -e SW_STORAGE=mysql \
        -e SW_JDBC_URL="${mysql_jdbc_url}" \
        -e SW_DATA_SOURCE_USER="${mysql_user}" \
        -e SW_DATA_SOURCE_PASSWORD="${mysql_pass}" \
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
