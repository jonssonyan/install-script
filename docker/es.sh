#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 官方文档：https://www.elastic.co/guide/en/elasticsearch/reference/7.17/docker.html#docker

init_var() {
  ECHO_TYPE="echo -e"

  # ES
  ES_DATA="/jsdata/es/"
  es_ip="js-es"
  es_http_port=9200
  es_transport_port=9300
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
  # ES
  mkdir -p ${ES_DATA}
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_es() {
  if [[ -z $(docker ps -q -f "name=^${es_ip}$") ]]; then
    echo_content green "---> 安装Elasticsearch"

    read -r -p "请输入ES的HTTP端口(默认:9200): " es_http_port
    [[ -z "${es_http_port}" ]] && es_http_port=9200
    read -r -p "请输入ES的传输端口(默认:9300): " es_transport_port
    [[ -z "${es_transport_port}" ]] && es_transport_port=9300

    docker pull elasticsearch:7.17.10 &&
      docker run -d --name ${es_ip} --restart always \
        -e "discovery.type=single-node" \
        -e "http.host=0.0.0.0" \
        -e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
        -e TZ=Asia/Shanghai \
        -p ${es_http_port}:9200 \
        -p ${es_transport_port}:9300 \
        -v ${ES_DATA}config/:/usr/share/elasticsearch/config/ \
        -v ${ES_DATA}logs/:/usr/share/elasticsearch/logs/ \
        -v ${ES_DATA}data/:/usr/share/elasticsearch/data/ \
        -v ${ES_DATA}plugins/:/usr/share/elasticsearch/plugins/ \
        elasticsearch:7.17.10

    if [[ -n $(docker ps -q -f "name=^${es_ip}$") ]]; then
      echo_content skyBlue "---> Elasticsearch安装完成"
    else
      echo_content red "---> Elasticsearch安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Elasticsearch"
  fi
}

cd "$HOME" || exit 0
init_var
clear
install_docker
install_es
