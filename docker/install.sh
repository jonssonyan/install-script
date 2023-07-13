#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  docker_version="20.10.23"
  docker_mirror='"https://hub-mirror.c.163.com","https://ccr.ccs.tencentyun.com","https://mirror.baidubce.com","https://dockerproxy.com"'
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

  can_connect www.google.com && can_google=1
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

setup_docker() {
  mkdir -p /etc/docker
  if [[ ${can_google} == 0 ]]; then
    cat >/etc/docker/daemon.json <<EOF
{
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"100m"
  },
  "registry-mirrors":[${docker_mirror}]
}
EOF
  else
    cat >/etc/docker/daemon.json <<EOF
{
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"100m"
  }
}
EOF
  fi
  systemctl daemon-reload
}

install_docker() {
  if [[ ! $(command -v docker) ]]; then
    echo_content green "---> 安装Docker"

    while read -r -p "请输入Docker版本(1/20.10.23 2/latest 默认:1/20.10.23): " dockerVersionNum; do
      if [[ -z "${dockerVersionNum}" || ${dockerVersionNum} == 1 ]]; then
        docker_version="20.10.23"
        break
      else
        if [[ ${dockerVersionNum} != 2 ]]; then
          echo_content red "不可以输入除1和2之外的其他字符"
        else
          docker_version=""
          break
        fi
      fi
    done

    if [[ "${release}" == "centos" ]]; then
      ${package_manager} remove docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine
      ${package_manager} install -y yum-utils
      if [[ ${can_google} == 0 ]]; then
        ${package_manager}-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      else
        ${package_manager}-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi
      ${package_manager} makecache || ${package_manager} makecache fast
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
      ${package_manager} remove docker docker-engine docker.io containerd runc
      ${package_manager} update -y
      ${package_manager} install -y \
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
      ${package_manager} update -y
    fi

    if [[ "${docker_version}" == "latest" ]]; then
      ${package_manager} install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
      if [[ ${package_manager} == "yum" || ${package_manager} == "dnf" ]]; then
        ${package_manager} install -y docker-ce-"${docker_version}" docker-ce-cli-"${docker_version}" containerd.io docker-compose-plugin
      elif [[ ${package_manager} == "apt" || ${package_manager} == "apt-get" ]]; then
        ${package_manager} install -y docker-ce=5:"${docker_version}"~3-0~${release}-"$(lsb_release -c --short)" docker-ce-cli=5:"${docker_version}"~3-0~${release}-"$(lsb_release -c --short)" containerd.io docker-compose-plugin
      fi
    fi

    setup_docker

    systemctl enable docker && systemctl restart docker

    if [[ $(command -v docker) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
}

cd "$HOME" || exit 0
init_var
check_sys
install_depend
install_prepare
clear
install_docker
