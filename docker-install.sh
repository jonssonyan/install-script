#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.0.0
# Description: One click install docker
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  docker_version="19.03.15"
  DOCKER_MIRROR='"https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn","https://registry.docker-cn.com"'

  JS_DATA="/jsdata/"

  # MySQL
  MySQL_DATA="/jsdata/mysql/"
  mariadb_ip="js-mariadb"
  mysql_port=9507
  mysql_user="root"
  mysql_pas=""

  #Redis
  REDIS_DATA="/jsdata/redis/"
  redis_host="js-redis"
  redis_port=6378
  redis_pass=""
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
  mkdir -p ${JS_DATA}

  # MySQL
  mkdir -p ${MySQL_DATA}

  # Redis
  mkdir -p ${REDIS_DATA}
}

can_connect() {
  if ping -c2 -i0.3 -W1 "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# 检查系统
check_sys() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "必须是 root 才能运行此脚本"
    exit 1
  fi

  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v apt-get) ]]; then
    package_manager='apt-get'
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
  if [[ "${package_manager}" == 'apt-get' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    systemd \
    lrzsz
}

install_prepare() {
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0
  systemctl restart rsyslog
  systemctl restart crond
}

setup_docker() {
  can_connect www.google.com && can_google=1

  mkdir -p /etc/docker
  if [[ ${can_google} == 0 ]]; then
    cat >/etc/docker/daemon.json <<EOF
{
    "registry-mirrors":[${DOCKER_MIRROR}]
}
EOF
  fi
}

install_docker() {
  if [[ ! $(command -v docker) ]]; then
    echo_content green "---> 安装Docker"

    read -r -p "请输入Docker版本(默认:19.03.15): " docker_version
    [[ -z "${docker_version}" ]] && docker_version="19.03.15"

    can_connect www.google.com && can_google=1

    if [[ ${release} == 'centos' ]]; then
      yum remove docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine
      yum install -y yum-utils
      if [[ ${can_google} == 0 ]]; then
        yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      else
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi
      yum makecache fast
      yum install -y docker-ce-${docker_version} docker-ce-cli-${docker_version} containerd.io docker-compose-plugin
    elif [[ ${release} == 'debian' || ${release} == 'ubuntu' ]]; then
      apt-get remove docker docker-engine docker.io containerd runc
      apt-get update
      apt-get install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
      mkdir -p /etc/apt/keyrings
      if [[ ${can_google} == 0 ]]; then
        curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/${release}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] http://mirrors.aliyun.com/docker-ce/linux/${release} \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      else
        curl -fsSL https://download.docker.com/linux/${release}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${release} \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      fi
      apt-get update
      apt-get install -y docker-ce-${docker_version} docker-ce-cli-${docker_version} containerd.io docker-compose-plugin
    fi

    setup_docker

    systemctl daemon-reload && systemctl enable docker && systemctl restart docker && docker network create trojan-panel-network

    if [[ $(command -v docker) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 1
    fi
  else
    if [[ -z $(docker network ls | grep "js-network") ]]; then
      docker network create trojan-panel-network
    fi
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
}

install_mysql() {
  if [[ -z $(docker ps -q -f "name=^js-mysql$") ]]; then
    echo_content green "---> 安装MySQL"

    read -r -p "请输入数据库的端口(默认:9507): " mysql_port
    [[ -z "${mysql_port}" ]] && mysql_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mysql_user
    [[ -z "${mysql_user}" ]] && mysql_user="root"
    while read -r -p "请输入数据库的密码(必填): " mysql_pas; do
      if [[ -z "${mysql_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    if [[ "${mysql_user}" == "root" ]]; then
      docker pull mysql:5.7.38 &&
        docker run -d --name js-mysql --restart always \
          --network=js-network \
          -p ${mysql_port}:3306 \
          -v ${MySQL_DATA}:/var/lib/mysql \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          mysql:5.7.38
    else
      docker pull mysql:5.7.38 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=js-network \
          -p ${mysql_port}:3306 \
          -v ${MySQL_DATA}:/var/lib/mysql \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e MYSQL_USER="${mysql_user}" \
          -e MYSQL_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          mysql:5.7.38
    fi

    if [[ -n $(docker ps -q -f "name=^js-mariadb$") ]]; then
      echo_content skyBlue "---> MySQL安装完成"
      echo_content yellow "---> MySQL root的数据库密码(请妥善保存): ${mysql_pas}"
      if [[ "${mysql_user}" != "root" ]]; then
        echo_content yellow "---> MySQL ${mysql_user}的数据库密码(请妥善保存): ${mysql_pas}"
      fi
    else
      echo_content red "---> MySQL安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了MySQL"
  fi
}

# 安装Redis
install_redis() {
  if [[ -z $(docker ps -q -f "name=^js-redis$") ]]; then
    echo_content green "---> 安装Redis"

    read -r -p "请输入Redis的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker pull redis:6.2.7 &&
      docker run -d --name js-redis --restart always \
        --network=js-network \
        -p ${redis_port}:6379 \
        -v ${REDIS_DATA}:/data redis:6.2.7 \
        redis-server --requirepass "${redis_pass}"

    if [[ -n $(docker ps -q -f "name=^js-redis$") ]]; then
      echo_content skyBlue "---> Redis安装完成"
      echo_content yellow "---> Redis的数据库密码(请妥善保存): ${redis_pass}"
    else
      echo_content red "---> Redis安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Redis"
  fi
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
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 安装Docker"
  echo_content yellow "2. 安装MySQL 5.7.28"
  echo_content yellow "3. 安装Redis 6.2.7"
  read -r -p "请选择:" selectInstall_type
  case ${selectInstall_type} in
  1)
    install_docker
    ;;
  2)
    install_docker
    install_mysql
    ;;
  3)
    install_docker
    install_redis
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main
