#!/usr/bin/env bash
# Elasticsearch Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

# 官方文档：https://www.elastic.co/guide/en/elasticsearch/reference/7.17/docker.html#docker
# 设置密码：进入容器执行 `elasticsearch-setup-passwords interactive`

init_var() {
  ECHO_TYPE="echo -e"

  ES_DATA="/dockerdata/es/"
  ES_DATA_CONFIG="${ES_DATA}config/"
  ES_DATA_LOGS="${ES_DATA}logs/"
  ES_DATA_DATA="${ES_DATA}data/"
  ES_DATA_PLUGINS="${ES_DATA}plugins/"
  es_ip="jy-es"
  es_http_port=9200
  es_transport_port=9300
  es_node_name='node-1'
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
  mkdir -p ${ES_DATA}
  mkdir -p ${ES_DATA_CONFIG} ${ES_DATA_LOGS} ${ES_DATA_DATA} ${ES_DATA_PLUGINS}
  chmod -R g+rwx ${ES_DATA}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_es() {
  if [[ -z $(docker ps -q -f "name=^${es_ip}$") ]]; then
    echo_content skyBlue "---> 安装 Elasticsearch"

    read -r -p "请输入ES的HTTP端口(默认:9200): " es_http_port
    [[ -z "${es_http_port}" ]] && es_http_port=9200
    read -r -p "请输入ES的传输端口(默认:9300): " es_transport_port
    [[ -z "${es_transport_port}" ]] && es_transport_port=9300
    read -r -p "请输入ES的节点名称(默认:node-1): " es_node_name
    [[ -z "${es_node_name}" ]] && es_node_name='node-1'

    cat >${ES_DATA}config/elasticsearch.yml <<EOF
node.name: ${es_node_name}
http.host: 0.0.0.0
http.port: ${es_http_port}
transport.port: ${es_transport_port}
http.cors.enabled: true
http.cors.allow-origin: "*"
http.cors.allow-headers: Authorization
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
EOF

    docker pull elasticsearch:7.17.10 &&
      docker run -d --name ${es_ip} --restart always \
        --network=host \
        -e "discovery.type=single-node" \
        -e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
        -e TZ=Asia/Shanghai \
        -v ${ES_DATA_CONFIG}elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \
        -v ${ES_DATA_LOGS}:/usr/share/elasticsearch/logs/ \
        -v ${ES_DATA_DATA}:/usr/share/elasticsearch/data/ \
        -v ${ES_DATA_PLUGINS}:/usr/share/elasticsearch/plugins/ \
        elasticsearch:7.17.10

    if [[ -n $(docker ps -q -f "name=^${es_ip}$" -f "status=running") ]]; then
      echo_content skyBlue "---> Elasticsearch安装完成"
      echo_content yellow "---> 设置密码请进入容器执行: elasticsearch-setup-passwords interactive"
    else
      echo_content red "---> Elasticsearch安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Elasticsearch"
  fi
}

main() {
  cd "$HOME" || exit 1

  init_var

  create_dirs

  install_docker

  install_es
}

main "$@"