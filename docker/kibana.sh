#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  # Kibana
  KIBANA_DATA="/jsdata/kibana/"
  kibana_ip="js-kibana"
  kibana_port=5601
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
  # Kibana
  mkdir -p ${KIBANA_DATA}
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_kibana() {
  if [[ -z $(docker ps -q -f "name=^${kibana_ip}$") ]]; then
    echo_content green "---> 安装Kibana"

    read -r -p "请输入Kibana的端口(默认:5601): " kibana_port
    [[ -z "${kibana_port}" ]] && kibana_port=5601

    docker pull kibana:7.6.2 &&
      docker run -d --name ${kibana_ip} --restart always \
        -e TZ=Asia/Shanghai \
        -p ${kibana_port}:5601 \
        -v ${KIBANA_DATA}config//kibana.yml:/data/kibana/config/kibana.yml \
        kibana:7.6.2

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
clear
install_docker
install_kibana
