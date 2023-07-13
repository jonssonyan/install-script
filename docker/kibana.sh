#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 官方文档：https://www.elastic.co/guide/en/kibana/7.17/settings.html

init_var() {
  ECHO_TYPE="echo -e"

  KIBANA_DATA="/jsdata/kibana/"
  KIBANA_DATA_CONFIG="${KIBANA_DATA}config/"
  kibana_ip="js-kibana"
  kibana_server_port=5601
  kibana_server_name="js-kibana"
  es_ip_port="http://127.0.0.1:9200"
  es_username="elastic"
  es_password="elastic"
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
  mkdir -p ${KIBANA_DATA}
  mkdir -p ${KIBANA_DATA}config/
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_kibana() {
  if [[ -z $(docker ps -q -f "name=^${kibana_ip}$") ]]; then
    echo_content green "---> 安装Kibana"

    read -r -p "请输入Kibana的端口(默认:5601): " kibana_server_port
    [[ -z "${kibana_server_port}" ]] && kibana_server_port=5601
    read -r -p "请输入Kibana的主机名(默认:js-kibana): " kibana_server_name
    [[ -z "${kibana_server_name}" ]] && kibana_server_name="js-kibana"

    read -r -p "请输入Elasticsearch的URL(默认:http://127.0.0.1:9200): " es_ip_port
    [[ -z "${es_ip_port}" ]] && es_ip_port="http://127.0.0.1:9200"
    read -r -p "请输入Elasticsearch的用户名(默认:elastic): " es_username
    [[ -z "${es_username}" ]] && es_username="elastic"
    read -r -p "请输入Elasticsearch的密码(默认:elastic): " es_password
    [[ -z "${es_password}" ]] && es_password="elastic"

    cat >${KIBANA_DATA}config/kibana.yml <<EOF
server.name: "${kibana_server_name}"
server.host: "0.0.0.0"
server.port: ${kibana_server_port}
elasticsearch.hosts: ["${es_ip_port}"]
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

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_kibana
