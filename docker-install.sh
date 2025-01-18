#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  version=""
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

service_exists() {
  systemctl list-units --type=service --all | grep -Fq "$1.service"
}

# 检查系统
check_sys() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "You must be root to run this script"
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
    echo_content red "This system is not currently supported"
    exit 1
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
    version=$(rpm -q --queryformat '%{VERSION}' centos-release)
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
    version=$(cat /etc/debian_version)
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
    version=$(lsb_release -sr)
  fi

  major_version=$(echo "${version}" | cut -d. -f1)

  case $release in
  centos)
    if [[ $major_version -ge 6 ]]; then
      echo_content green "Supported CentOS version detected: $version"
    else
      echo_content red "Unsupported CentOS version: $version. Only supports CentOS 6+."
      exit 1
    fi
    ;;
  ubuntu)
    if [[ $major_version -ge 16 ]]; then
      echo_content green "Supported Ubuntu version detected: $version"
    else
      echo_content red "Unsupported Ubuntu version: $version. Only supports Ubuntu 16+."
      exit 1
    fi
    ;;
  debian)
    if [[ $major_version -ge 8 ]]; then
      echo_content green "Supported Debian version detected: $version"
    else
      echo_content red "Unsupported Debian version: $version. Only supports Debian 8+."
      exit 1
    fi
    ;;
  *)
    echo_content red "Only supports CentOS 6+/Ubuntu 16+/Debian 8+"
    exit 1
    ;;
  esac

  if [[ $(arch) =~ ("x86_64"|"amd64") ]]; then
    get_arch="amd64"
  elif [[ $(arch) =~ ("aarch64"|"arm64") ]]; then
    get_arch="arm64"
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "Only supports x86_64/amd64 arm64/aarch64"
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
    lrzsz
}

# 环境准备
install_prepare() {
  # 同步时间
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0

  if service_exists "rsyslog"; then
    systemctl restart rsyslog
  fi

  case "${release}" in
  centos)
    if service_exists "crond"; then
      systemctl restart crond
    fi
    ;;
  debian | ubuntu)
    if service_exists "cron"; then
      systemctl restart cron
    fi
    ;;
  esac
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_buildx() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/buildx.sh)
}

uninstall_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/uninstall.sh)
}

install_mysql() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/mysql.sh)
}

install_postgreql() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/postgresql.sh)
}

install_redis() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/redis.sh)
}

install_es() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/es.sh)
}

install_kibana() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/kibana.sh)
}

install_minio() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/minio.sh)
}

install_nacos() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/nacos.sh)
}

install_ssr() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/ssr.sh)
}

install_nexus3() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/nexus3.sh)
}

install_gitlab() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/gitlab.sh)
}

install_skywalking_oap() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/skywalking-oap.sh)
}

install_skywalking_ui() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/skywalking-ui.sh)
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
  echo_content skyBlue "Recommended OS: CentOS 8+/Ubuntu 20+/Debian 11+"
  echo_content skyBlue "Description: Install Docker based Services"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-script"
  echo_content red "\n=============================================================="
  echo_content yellow "1. Install Docker"
  echo_content yellow "2. Install Docker buildx"
  echo_content yellow "3. Uninstall Docker"
  echo_content green "=============================================================="
  echo_content yellow "4. Install MySQL 5.7.38"
  echo_content yellow "5. Install PostgreSQL 13"
  echo_content yellow "6. Install Redis 6.2.13"
  echo_content yellow "7. Install Elasticsearch 7.17.10"
  echo_content yellow "8. Install Kibana 7.17.10"
  echo_content yellow "9. Install Minio"
  echo_content yellow "10. Install Nacos v2.1.2"
  echo_content yellow "11. Install ShadowsocksR"
  echo_content yellow "12. Install Nexus3"
  echo_content yellow "13. Install GitLab"
  echo_content yellow "14. Install SkyWalking OAP"
  echo_content yellow "15. Install SkyWalking UI"
  read -r -p "Please choose:" input_option
  case ${input_option} in
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
    install_postgreql
    ;;
  6)
    install_docker
    install_redis
    ;;
  7)
    install_docker
    install_es
    ;;
  8)
    install_docker
    install_kibana
    ;;
  9)
    install_docker
    install_minio
    ;;
  10)
    install_docker
    install_nacos
    ;;
  11)
    install_docker
    install_ssr
    ;;
  12)
    install_docker
    install_nexus3
    ;;
  13)
    install_docker
    install_gitlab
    ;;
  14)
    install_docker
    install_skywalking_oap
    ;;
  15)
    install_docker
    install_skywalking_ui
    ;;
  *)
    echo_content red "No such option"
    ;;
  esac
}

main
