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

  # Docker
  DOCKER_CONFIG_PATH='/root/.docker/'
  docker_config='/root/.docker/config.json'

  JS_DATA="/jsdata/"

  # MySQL
  MySQL_DATA="/jsdata/mysql/"
  mysql_ip="js-mysql"
  mysql_port=9507
  mysql_user="root"
  mysql_pas=""

  # Redis
  REDIS_DATA="/jsdata/redis/"
  redis_ip="js-redis"
  redis_port=6378
  redis_pass=""

  #Minio
  MINIO_DATA="/jsdata/minio/"
  MINIO_DATA_DATA="/jsdata/minio/data/"
  MINIO_CONFIG="/jsdata/minio/config/"
  minio_ip="js-minio"
  minio_server_port=9000
  minio_console_port=8000
  minio_root_user="admin"
  minio_root_password="12345678"

  # Nacos
  NACOS_DATA="/jsdata/nacos/"
  nacos_ip="js-nacos"
  nacos_port=8848

  # ShadowsocksR
  SSR_DATA="/jsdata/ssr/"
  ssr_ip="js-ssr"
  ssr_port=80
  ssr_password="123456"
  ssr_config="/jsdata/ssr/config.json"
  ssr_method=""
  ssr_protocols=""
  ssr_obfs=""
  methods=(
    none
    aes-256-cfb
    aes-192-cfb
    aes-128-cfb
    aes-256-cfb8
    aes-192-cfb8
    aes-128-cfb8
    aes-256-ctr
    aes-192-ctr
    aes-128-ctr
    chacha20-ietf
    chacha20
    salsa20
    xchacha20
    xsalsa20
    rc4-md5
  )
  # https://github.com/shadowsocksr-rm/shadowsocks-rss/blob/master/ssr.md
  protocols=(
    origin
    verify_deflate
    auth_sha1_v4
    auth_sha1_v4_compatible
    auth_aes128_md5
    auth_aes128_sha1
    auth_chain_a
    auth_chain_b
    auth_chain_c
    auth_chain_d
    auth_chain_e
    auth_chain_f
  )
  obfs=(
    plain
    http_simple
    http_simple_compatible
    http_post
    http_post_compatible
    tls1.2_ticket_auth
    tls1.2_ticket_auth_compatible
    tls1.2_ticket_fastauth
    tls1.2_ticket_fastauth_compatible
  )

  # nexus3
  NEXUS3_DATA="/jsdata/nexus3/"
  nexus3_ip="js-nexus3"
  nexus3_port=8081

  # gitlab
  GITLAB_DATA="/jsdata/gitlab/"
  GITLAB_CONFIG="/jsdata/gitlab/config/"
  GITLAB_LOG="/jsdata/gitlab/logs/"
  GITLAB_OPT="/jsdata/gitlab/opt/"
  gitlab_ip="js-gitlab"
  gitlab_http_port=8080
  gitlab_https_port=8443
  gitlab_ssh_port=8022
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

  # Minio
  mkdir -p ${MINIO_DATA}

  # Nacos
  mkdir -p ${NACOS_DATA}

  # ShadowsocksR
  mkdir -p ${SSR_DATA}

  # Nexus3
  mkdir -p ${NEXUS3_DATA}

  # GitLab
  mkdir -p ${GITLAB_DATA}
  mkdir -p ${GITLAB_CONFIG}
  mkdir -p ${GITLAB_LOG}
  mkdir -p ${GITLAB_OPT}
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

  if [[ -z $(docker network ls | grep "js-network") ]]; then
    docker network create js-network
  fi
}

install_mysql() {
  if [[ -z $(docker ps -q -f "name=^${mysql_ip}$") ]]; then
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
        docker run -d --name ${mysql_ip} --restart always \
          --network=js-network \
          -p ${mysql_port}:3306 \
          -v ${MySQL_DATA}:/var/lib/mysql \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          mysql:5.7.38 \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    else
      docker pull mysql:5.7.38 &&
        docker run -d --name ${mysql_ip} --restart always \
          --network=js-network \
          -p ${mysql_port}:3306 \
          -v ${MySQL_DATA}:/var/lib/mysql \
          -e MYSQL_ROOT_PASSWORD="${mysql_pas}" \
          -e MYSQL_USER="${mysql_user}" \
          -e MYSQL_PASSWORD="${mysql_pas}" \
          -e TZ=Asia/Shanghai \
          mysql:5.7.38 \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    fi

    if [[ -n $(docker ps -q -f "name=^${mysql_ip}$") ]]; then
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
  if [[ -z $(docker ps -q -f "name=^${redis_ip}$") ]]; then
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
      docker run -d --name ${redis_ip} --restart always \
        --network=js-network \
        -p ${redis_port}:6379 \
        -v ${REDIS_DATA}:/data redis:6.2.7 \
        redis-server --requirepass "${redis_pass}"

    if [[ -n $(docker ps -q -f "name=^${redis_ip}$") ]]; then
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

install_minio() {
  if [[ -z $(docker ps -q -f "name=^${minio_ip}$") ]]; then
    echo_content green "---> 安装Minio"

    read -r -p "请输入Minio的服务端口(默认:9000): " minio_server_port
    [[ -z "${minio_server_port}" ]] && minio_server_port=9000
    read -r -p "请输入Minio的控制台端口(默认:8000): " minio_console_port
    [[ -z "${minio_console_port}" ]] && minio_console_port=8000
    read -r -p "请输入Minio的控制台用户名(默认:admin): " minio_root_user
    [[ -z "${minio_root_user}" ]] && minio_root_user="admin"
    while read -r -p "请输入Minio的控制台密码(默认:12345678): " minio_root_password; do
      if [[ -z "${minio_root_password}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker pull minio/minio &&
      docker run -d --name ${minio_ip} --restart=always \
        --network=js-network \
        -p ${minio_server_port}:9000 -p ${minio_console_port}:8000 \
        -e "MINIO_ROOT_USER=${minio_root_user}" \
        -e "MINIO_ROOT_PASSWORD=${minio_root_password}" \
        -v ${MINIO_DATA_DATA}:/data \
        -v ${MINIO_CONFIG}:/root/.minio \
        minio/minio \
        server --address ':9000' \
        --console-address ':8000' /data
    if [[ -n $(docker ps -q -f "name=^${minio_ip}$") ]]; then
      echo_content skyBlue "---> Minio安装完成"
      echo_content yellow "---> Minio的用户号名(请妥善保存): ${minio_root_user}"
      echo_content yellow "---> Minio的密码(请妥善保存): ${minio_root_password}"
    else
      echo_content red "---> Minio安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Minio"
  fi
}

install_nacos() {
  if [[ -z $(docker ps -q -f "name=^${nacos_ip}$") ]]; then
    echo_content green "---> 安装Nacos"

    docker pull nacos/nacos-server:v2.2.0 &&
      docker run -d --name ${nacos_ip} --restart=always \
        --network=js-network \
        -p ${nacos_port}:8848 \
        -e MODE=standalone nacos/nacos-server:v2.2.0
    if [[ -n $(docker ps -q -f "name=^${nacos_ip}$") ]]; then
      echo_content skyBlue "---> Nacos安装完成"
      echo_content yellow "---> Nacos的用户号名(请妥善保存): nacos"
      echo_content yellow "---> Nacos的密码(请妥善保存): nacos"
    else
      echo_content red "---> Nacos安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Nacos"
  fi
}

install_ssr() {
  if [[ -z $(docker ps -q -f "name=^${ssr_ip}$") ]]; then
    echo_content green "---> 安装ShadowsocksR"

    read -r -p "请输入ShadowsocksR的密码(默认:123456): " ssr_password
    [[ -z "${ssr_password}" ]] && ssr_password="123456"

    while true; do
      for ((i = 1; i <= ${#methods[@]}; i++)); do
        hint="${methods[$i - 1]}"
        echo "${i}) $(echo_content yellow "${hint}")"
      done
      read -r -p "请选择ShadowsocksR的加密类型(默认:${methods[0]}): " r_methods
      [[ -z "${r_methods}" ]] && r_methods=1
      expr ${r_methods} + 1 &>/dev/null
      if [[ "$?" != "0" ]]; then
        echo_content red "请输入数字"
        continue
      fi
      if [[ "${r_methods}" -lt 1 || "${r_methods}" -gt ${#methods[@]} ]]; then
        echo_content red "输入的数字范围在 1 到 ${#methods[@]}"
        continue
      fi
      ssr_method=${methods[r_methods - 1]}
      break
    done

    while true; do
      for ((i = 1; i <= ${#protocols[@]}; i++)); do
        hint="${protocols[$i - 1]}"
        echo "${i}) $(echo_content yellow "${hint}")"
      done
      read -r -p "请选择ShadowsocksR的协议(默认:${protocols[0]}): " r_protocols
      [[ -z "${r_protocols}" ]] && r_protocols=1
      expr ${r_protocols} + 1 &>/dev/null
      if [[ "$?" != "0" ]]; then
        echo_content red "请输入数字"
        continue
      fi
      if [[ "${r_protocols}" -lt 1 || "${r_protocols}" -gt ${#protocols[@]} ]]; then
        echo_content red "输入的数字范围在 1 到 ${#protocols[@]}"
        continue
      fi
      ssr_protocols=${protocols[r_protocols - 1]}
      break
    done

    while true; do
      for ((i = 1; i <= ${#obfs[@]}; i++)); do
        hint="${obfs[$i - 1]}"
        echo "${i}) $(echo_content yellow "${hint}")"
      done
      read -r -p "请选择ShadowsocksR的混淆方式(默认:${obfs[0]}): " r_obfs
      [[ -z "${r_obfs}" ]] && r_obfs=1
      expr ${r_obfs} + 1 &>/dev/null
      if [[ "$?" != "0" ]]; then
        echo_content red "请输入数字"
        continue
      fi
      if [[ "${r_obfs}" -lt 1 || "${r_obfs}" -gt ${#obfs[@]} ]]; then
        echo_content red "输入的数字范围在 1 到 ${#obfs[@]}"
        continue
      fi
      ssr_obfs=${obfs[r_obfs - 1]}
      break
    done

    cat >${ssr_config} <<EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${ssr_port},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${ssr_password}",
    "timeout":120,
    "method":"${ssr_method}",
    "protocol":"${ssr_protocols}",
    "protocol_param":"",
    "obfs":"${ssr_obfs}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":true,
    "workers":1
}
EOF

    docker pull teddysun/shadowsocks-r &&
      docker run -d --name ${ssr_ip} --restart=always \
        --network=js-network \
        -p ${ssr_port}:${ssr_port} -p ${ssr_port}:${ssr_port}/udp \
        -v ${ssr_config}:/etc/shadowsocks-r/config.json \
        teddysun/shadowsocks-r

    if [[ -n $(docker ps -q -f "name=^${ssr_ip}$") ]]; then
      echo_content skyBlue "---> ShadowsocksR安装完成"
      echo_content yellow "---> ShadowsocksR的端口: ${ssr_port}"
      echo_content yellow "---> ShadowsocksR的密码(请妥善保存): ${ssr_password}"
      echo_content yellow "---> ShadowsocksR的加密类型: ${ssr_method}"
      echo_content yellow "---> ShadowsocksR的协议: ${ssr_protocols}"
      echo_content yellow "---> ShadowsocksR的混淆方式: ${ssr_obfs}"
    else
      echo_content red "---> ShadowsocksR安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了ShadowsocksR"
  fi
}

# 安装Nexus3
install_nexus3() {
  if [[ -z $(docker ps -q -f "name=^${nexus3_ip}$") ]]; then
    echo_content green "---> 安装Nexus3"

    read -r -p "请输入Nexus3的端口(默认:8081): " nexus3_port
    [[ -z "${nexus3_port}" ]] && nexus3_port=8081
    docker pull sonatype/nexus3:3.49.0 &&
      docker run -d --name ${nexus3_ip} --restart always \
        --network=js-network \
        -p ${nexus3_port}:8081 \
        -v ${NEXUS3_DATA}:/nexus-data \
        sonatype/nexus3:3.49.0

    if [[ -n $(docker ps -q -f "name=^${nexus3_ip}$") ]]; then
      echo_content skyBlue "---> Nexus3安装完成"
    else
      echo_content red "---> Nexus3安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Nexus3"
  fi
}

# 安装GitLab
install_gitlab() {
  if [[ -z $(docker ps -q -f "name=^${gitlab_ip}$") ]]; then
    echo_content green "---> 安装GitLab"

    read -r -p "请输入GitLab的HTTP端口(默认:8080): " gitlab_http_port
    [[ -z "${gitlab_http_port}" ]] && gitlab_http_port=8080
    read -r -p "请输入GitLab的HTTPS端口(默认:8443): " gitlab_https_port
    [[ -z "${gitlab_https_port}" ]] && gitlab_https_port=8443
    read -r -p "请输入GitLab的SSH端口(默认:8022): " gitlab_ssh_port
    [[ -z "${gitlab_ssh_port}" ]] && gitlab_ssh_port=8022

    docker pull gitlab/gitlab-ce:15.9.3-ce.0 &&
      docker run -d --name ${gitlab_ip} --restart always \
        --network=js-network \
        -p ${gitlab_http_port}:80 \
        -p ${gitlab_https_port}:443 \
        -p ${gitlab_ssh_port}:22 \
        -v ${GITLAB_CONFIG}:/etc/gitlab \
        -v ${GITLAB_LOG}:/var/log/gitlab \
        -v ${GITLAB_OPT}:/var/opt/gitlab \
        -e TZ=Asia/Shanghai \
        gitlab/gitlab-ce:15.9.3-ce.0
    # todo
    cat >>/etc/gitlab/gitlab.rb <<EOF
external_url 'http://localhost:${gitlab_http_port}'
nginx['listen_port'] = ${gitlab_http_port}
gitlab_rails['gitlab_shell_ssh_port'] = ${gitlab_ssh_port}
EOF

    if [[ -n $(docker ps -q -f "name=^${gitlab_ip}$") ]]; then
      echo_content skyBlue "---> GitLab安装完成"
    else
      echo_content red "---> GitLab安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了GitLab"
  fi
}

# 安装buildx交叉编译
install_buildx() {
  docker buildx inspect --bootstrap | grep -q "mybuilder"
  if [[ "$?" != "0" ]]; then
    echo_content green "---> 安装buildx交叉编译"

    if [[ -d "${DOCKER_CONFIG_PATH}" && -f "${docker_config}" ]]; then
      if ! grep -q "experimental" "${docker_config}"; then
        jq '.experimental="enabled"' "${docker_config}" >tmp.json && mv tmp.json "${docker_config}"
      fi
    else
      mkdir -p "${DOCKER_CONFIG_PATH}"
      cat >"${docker_config}" <<EOF
{
  "experimental": "enabled"
}
EOF
    fi

    docker buildx create --use --name mybuilder &&
      docker buildx use mybuilder &&
      docker run --privileged --rm tonistiigi/binfmt --install all

    if docker buildx inspect --bootstrap | grep -q "mybuilder"; then
      echo_content skyBlue "---> buildx交叉编译安装完成"
    else
      echo_content red "---> buildx交叉编译安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了buildx交叉编译"
  fi
}

# 卸载Docker
uninstall_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/uninstall.sh)
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
  echo_content yellow "2. 安装MySQL 5.7.38"
  echo_content yellow "3. 安装Redis 6.2.7"
  echo_content yellow "4. 安装Minio"
  echo_content yellow "5. 安装Nacos v2.2.0"
  echo_content yellow "6. 安装ShadowsocksR"
  echo_content yellow "7. 安装Nexus3"
  echo_content yellow "8. 安装GitLab"
  echo_content yellow "9. 安装buildx交叉编译"
  echo_content green "=============================================================="
  echo_content yellow "10. 卸载Docker"
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
  4)
    install_docker
    install_minio
    ;;
  5)
    install_docker
    install_nacos
    ;;
  6)
    install_docker
    install_ssr
    ;;
  7)
    install_docker
    install_nexus3
    ;;
  8)
    install_docker
    install_gitlab
    ;;
  9)
    install_docker
    install_buildx
    ;;
  10)
    uninstall_docker
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main
