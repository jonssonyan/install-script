#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  MINIO_DATA="/jsdata/minio/"
  MINIO_DATA_DATA="${MINIO_DATA}data/"
  MINIO_DATA_CONFIG="${MINIO_DATA}config/"
  minio_ip="js-minio"
  minio_server_port=9000
  minio_console_port=9001
  minio_root_user="admin"
  minio_root_password="12345678"
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
  mkdir -p ${MINIO_DATA}
  mkdir -p ${MINIO_DATA_DATA}
  mkdir -p ${MINIO_DATA_CONFIG}
}

install_docker() {
  source <(curl -L https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_minio() {
  if [[ -z $(docker ps -q -f "name=^${minio_ip}$") ]]; then
    echo_content green "---> 安装Minio"

    read -r -p "请输入Minio的服务端口(默认:9000): " minio_server_port
    [[ -z "${minio_server_port}" ]] && minio_server_port=9000
    read -r -p "请输入Minio的控制台端口(默认:9001): " minio_console_port
    [[ -z "${minio_console_port}" ]] && minio_console_port=9001
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
        --network=host \
        -e "MINIO_ROOT_USER=${minio_root_user}" \
        -e "MINIO_ROOT_PASSWORD=${minio_root_password}" \
        -e TZ=Asia/Shanghai \
        -v ${MINIO_DATA_DATA}:/data \
        -v ${MINIO_DATA_CONFIG}:/root/.minio \
        minio/minio \
        server /data --address ":${minio_server_port}" --console-address ":${minio_console_port}"

    if [[ -n $(docker ps -q -f "name=^${minio_ip}$") ]]; then
      echo_content skyBlue "---> Minio安装完成"
      echo_content yellow "---> Minio的用户号名(请妥善保存): ${minio_root_user}"
      echo_content yellow "---> Minio的密码(请妥善保存): ${minio_root_password}"
    else
      echo_content red "---> Minio安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Minio"
  fi
}

cd "$HOME" || exit 0
init_var
clear
install_docker
install_minio
