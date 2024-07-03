#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  # buildx
  DOCKER_CONFIG_PATH='/root/.docker/'
  docker_config='/root/.docker/config.json'
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

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
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

cd "$HOME" || exit 0
init_var
clear
install_docker
install_buildx
