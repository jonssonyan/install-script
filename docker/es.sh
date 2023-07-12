#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 官方文档：https://www.elastic.co/guide/en/elasticsearch/reference/7.17/docker.html#docker
# 设置密码：进入容器执行 `elasticsearch-setup-passwords interactive`

init_var() {
  ECHO_TYPE="echo -e"

  ES_DATA="/jsdata/es/"
  ES_DATA_CONFIG="${ES_DATA}config/"
  ES_DATA_LOGS="${ES_DATA}logs/"
  ES_DATA_DATA="${ES_DATA}data/"
  ES_DATA_PLUGINS="${ES_DATA}plugins/"
  es_ip="js-es"
  es_http_port=9200
  es_transport_port=9300
  es_node_name='node-1'
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
  mkdir -p ${ES_DATA}
  mkdir -p ${ES_DATA_CONFIG} ${ES_DATA_LOGS} ${ES_DATA_DATA} ${ES_DATA_PLUGINS}
  chmod -R g+rwx ${ES_DATA}
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
mkdir_tools
clear
install_docker
install_es
