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
  if [[ ! $(docker -v 2>/dev/null) ]]; then
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

    systemctl daemon-reload && systemctl enable docker && systemctl restart docker

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  install_depend
  install_prepare
  install_docker
}

main
