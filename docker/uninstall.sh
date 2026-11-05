#!/usr/bin/env bash
# Docker Uninstallation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  version=""
  arch=""
}

echo_content() {
  local color_code
  case $1 in
  "red") color_code="\033[31m" ;;
  "green") color_code="\033[32m" ;;
  "yellow") color_code="\033[33m" ;;
  "blue") color_code="\033[34m" ;;
  "purple") color_code="\033[35m" ;;
  "skyBlue") color_code="\033[36m" ;;
  "white") color_code="\033[37m" ;;
  *) color_code="\033[0m" ;;
  esac
  ${ECHO_TYPE} "${color_code}$2\033[0m"
}

# 检查系统
check_system() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "You must be root to run this script"
    exit 1
  fi

  # Determine package manager
  if command -v yum &>/dev/null; then
    package_manager='yum'
  elif command -v dnf &>/dev/null; then
    package_manager='dnf'
  elif command -v apt-get &>/dev/null; then
    package_manager='apt-get'
  elif command -v apt &>/dev/null; then
    package_manager='apt'
  else
    echo_content red "Unsupported system. No compatible package manager found."
    exit 1
  fi

  # Determine OS distribution and version
  if [[ -f /etc/os-release ]]; then
    os_id=$(. /etc/os-release && echo "${ID}")
    version=$(. /etc/os-release && echo "${VERSION_ID}")
  fi
  case "${os_id}" in
  centos | rhel | rocky | almalinux)
    release="centos"
    ;;
  debian | ubuntu)
    release="${os_id}"
    ;;
  esac

  # Check version compatibility
  major_version=$(echo "${version}" | cut -d. -f1)
  case $release in
  centos)
    if [[ $major_version -lt 8 ]]; then
      echo_content red "Unsupported CentOS version: $version. Only supports CentOS/RHEL/Rocky/AlmaLinux 8+."
      exit 1
    fi
    ;;
  ubuntu)
    if [[ $major_version -lt 20 ]]; then
      echo_content red "Unsupported Ubuntu version: $version. Only supports Ubuntu 20+."
      exit 1
    fi
    ;;
  debian)
    if [[ $major_version -lt 11 ]]; then
      echo_content red "Unsupported Debian version: $version. Only supports Debian 11+."
      exit 1
    fi
    ;;
  *)
    echo_content red "Only supports CentOS/RHEL/Rocky/AlmaLinux 8+/Ubuntu 20+/Debian 11+"
    exit 1
    ;;
  esac

  # Check architecture
  if [[ $(arch) =~ ("x86_64"|"amd64") ]]; then
    arch="amd64"
  elif [[ $(arch) =~ ("aarch64"|"arm64") ]]; then
    arch="arm64"
  else
    echo_content red "Only supports x86_64/amd64 or arm64/aarch64 architectures"
    exit 1
  fi

  echo_content green "System check passed: ${release} ${version} (${arch})"
}

# 卸载Docker
uninstall_docker() {
  if [[ $(command -v docker) ]]; then
    if [[ "${release}" == "centos" ]]; then
      ${package_manager} remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
      ${package_manager} purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
    fi
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
  else
    echo_content skyBlue "---> 请先安装 Docker"
  fi
}

main() {
  cd "$HOME" || exit 1

  init_var

  check_system

  uninstall_docker
}

main "$@"
