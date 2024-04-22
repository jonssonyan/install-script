#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.0.0
# Description: One click install Docker based Services
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""

  JY_DATA="/jydata/"

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
  # 项目目录
  mkdir -p ${JY_DATA}
}

# 检查系统
check_sys() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "必须是 root 才能运行此脚本"
    exit 1
  fi

  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v dnf) ]]; then
    package_manager='dnf'
  elif [[ $(command -v apt-get) ]]; then
    package_manager='apt-get'
  elif [[ $(command -v apt) ]]; then
    package_manager='apt'
  fi

  if [[ -z "${package_manager}" ]]; then
    echo_content red "暂不支持该系统"
    exit 1
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
  fi

  if [[ -z "${release}" ]]; then
    echo_content red "仅支持CentOS 7+/Ubuntu 18+/Debian 10+系统"
    exit 1
  fi

  if [[ $(arch) =~ ("x86_64"|"amd64"|"arm64"|"aarch64") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "仅支持x86_64/amd64和arm64/aarch64处理器架构"
    exit 1
  fi
}

# 安装依赖
install_depend() {
  if [[ "${package_manager}" == 'apt-get' || "${package_manager}" == 'apt' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    systemd \
    lrzsz \
    jq
}

# 环境准备
install_prepare() {
  echo_content green "---> 环境准备"

  # 同步时间
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0
  systemctl restart rsyslog
  systemctl restart crond

  echo_content skyBlue "---> 环境准备完成"
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

# 安装buildx交叉编译
install_buildx() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/buildx.sh)
}

# 卸载Docker
uninstall_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/uninstall.sh)
}

install_mysql() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/mysql.sh)
}

# 安装Redis
install_redis() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/redis.sh)
}

install_es() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/es.sh)
}

install_kibana() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/kibana.sh)
}

install_minio() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/minio.sh)
}

install_nacos() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/nacos.sh)
}

install_ssr() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/ssr.sh)
}

# 安装Nexus3
install_nexus3() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/nexus3.sh)
}

# 安装GitLab
install_gitlab() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/gitlab.sh)
}

install_skywalking_oap() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/skywalking-oap.sh)
}

install_skywalking_ui() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/skywalking-ui.sh)
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  install_depend
  install_prepare
  clear
  echo_content red "\n=============================================================="
  echo_content skyBlue "System Required: CentOS 7+/Ubuntu 18+/Debian 10+"
  echo_content skyBlue "Version: v1.0.0"
  echo_content skyBlue "Description: One click install Docker based Services"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-script"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 安装Docker"
  echo_content yellow "2. 安装buildx交叉编译"
  echo_content yellow "3. 卸载Docker"
  echo_content green "=============================================================="
  echo_content yellow "4. 安装MySQL 5.7.38"
  echo_content yellow "5. 安装Redis 6.2.13"
  echo_content yellow "6. 安装Elasticsearch 7.17.10"
  echo_content yellow "7. 安装Kibana 7.17.10"
  echo_content yellow "8. 安装Minio"
  echo_content yellow "9. 安装Nacos v2.1.2"
  echo_content yellow "10. 安装ShadowsocksR"
  echo_content yellow "11. 安装Nexus3"
  echo_content yellow "12. 安装GitLab"
  echo_content yellow "13. 安装SkyWalking OAP"
  echo_content yellow "14. 安装SkyWalking UI"
  read -r -p "请选择:" selectInstall_type
  case ${selectInstall_type} in
  1)
    install_docker
    ;;
  2)
    install_buildx
    ;;
  3)
    uninstall_docker
    ;;
  4)
    install_docker
    install_mysql
    ;;
  5)
    install_docker
    install_redis
    ;;
  6)
    install_docker
    install_es
    ;;
  7)
    install_docker
    install_kibana
    ;;
  8)
    install_docker
    install_minio
    ;;
  9)
    install_docker
    install_nacos
    ;;
  10)
    install_docker
    install_ssr
    ;;
  11)
    install_docker
    install_nexus3
    ;;
  12)
    install_docker
    install_gitlab
    ;;
  13)
    install_docker
    install_skywalking_oap
    ;;
  14)
    install_docker
    install_skywalking_ui
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main
