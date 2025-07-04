#!/usr/bin/env bash
# Kibana Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

# 官方文档：https://www.elastic.co/guide/en/kibana/7.17/settings.html

init_var() {
  ECHO_TYPE="echo -e"

  KIBANA_DATA="/dockerdata/kibana/"
  KIBANA_DATA_CONFIG="${KIBANA_DATA}config/"
  kibana_ip="jy-kibana"
  kibana_server_port=5601
  kibana_server_name="jy-kibana"
  es_url="http://127.0.0.1:9200"
  es_username="elastic"
  es_password="elastic"
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
  mkdir -p ${KIBANA_DATA}
  mkdir -p ${KIBANA_DATA}config/
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_kibana() {
  if [[ -z $(docker ps -q -f "name=^${kibana_ip}$") ]]; then
    echo_content green "---> 安装Kibana"

    read -r -p "请输入Kibana的端口(默认:5601): " kibana_server_port
    [[ -z "${kibana_server_port}" ]] && kibana_server_port=5601
    read -r -p "请输入Kibana的主机名(默认:jy-kibana): " kibana_server_name
    [[ -z "${kibana_server_name}" ]] && kibana_server_name="jy-kibana"

    read -r -p "请输入Elasticsearch的URL(默认:http://127.0.0.1:9200): " es_url
    [[ -z "${es_url}" ]] && es_url="http://127.0.0.1:9200"
    read -r -p "请输入Elasticsearch的用户名(默认:elastic): " es_username
    [[ -z "${es_username}" ]] && es_username="elastic"
    read -r -p "请输入Elasticsearch的密码(默认:elastic): " es_password
    [[ -z "${es_password}" ]] && es_password="elastic"

    cat >${KIBANA_DATA}config/kibana.yml <<EOF
server.name: "${kibana_server_name}"
server.host: "0.0.0.0"
server.port: ${kibana_server_port}
elasticsearch.hosts: ["${es_url}"]
elasticsearch.username: "${es_username}"
elasticsearch.password: "${es_password}"
i18n.locale: "zh-CN"
EOF

    docker pull kibana:7.17.10 &&
      docker run -d --name ${kibana_ip} --restart always \
        --network=host \
        -e TZ=Asia/Shanghai \
        -v ${KIBANA_DATA_CONFIG}/kibana.yml:/usr/share/kibana/config/kibana.yml \
        kibana:7.17.10

    if [[ -n $(docker ps -q -f "name=^${kibana_ip}$") ]]; then
      echo_content skyBlue "---> Kibana安装完成"
    else
      echo_content red "---> Kibana安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Kibana"
  fi
}

main() {
  cd "$HOME" || exit 1

  init_var

  create_dirs

  install_docker

  install_kibana
}

main "$@"
