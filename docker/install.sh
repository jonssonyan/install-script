#!/usr/bin/env bash
# Docker Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e # Exit immediately if a command exits with a non-zero status

# Initialize variables
init_var() {
  ECHO_TYPE="echo -e"

  # System variables
  package_manager=""
  release=""
  version=""
  arch=""
  can_access_internet=1 # Default to true, will check google.com accessibility

  # Docker directories and files
  DOCKER_DATA="/dockerdata"

  # Docker configuration
  docker_mirror='"https://docker.m.daocloud.io"'
  DOCKER_CONFIG="/etc/docker"
}

# Colorized output functions
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

# Create necessary directories
create_dirs() {
  mkdir -p ${DOCKER_DATA}
}

# Check if can connect to a host
can_connect() {
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  return $?
}

# Check if service exists
service_exists() {
  systemctl list-units --type=service --all | grep -Fq "$1.service"
}

# Check system compatibility and gather information
check_system() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "You must be root to run this script"
    exit 1
  fi

  # Check internet connectivity
  if ! can_connect www.google.com; then
    can_access_internet=0
    echo_content yellow "Limited internet connectivity detected. Using Chinese mirrors."
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
  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
    if rpm -q centos-stream-release &>/dev/null; then
      version=$(rpm -q --queryformat '%{VERSION}' centos-stream-release)
    elif rpm -q centos-release &>/dev/null; then
      version=$(rpm -q --queryformat '%{VERSION}' centos-release)
    fi
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </proc/version -q -i "debian"; then
    release="debian"
    version=$(cat /etc/debian_version)
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </proc/version -q -i "ubuntu"; then
    release="ubuntu"
    version=$(lsb_release -sr)
  fi

  # Check version compatibility
  major_version=$(echo "${version}" | cut -d. -f1)
  case $release in
  centos)
    if [[ $major_version -lt 6 ]]; then
      echo_content red "Unsupported CentOS version: $version. Only supports CentOS 6+."
      exit 1
    fi
    ;;
  ubuntu)
    if [[ $major_version -lt 16 ]]; then
      echo_content red "Unsupported Ubuntu version: $version. Only supports Ubuntu 16+."
      exit 1
    fi
    ;;
  debian)
    if [[ $major_version -lt 8 ]]; then
      echo_content red "Unsupported Debian version: $version. Only supports Debian 8+."
      exit 1
    fi
    ;;
  *)
    echo_content red "Only supports CentOS 6+/Ubuntu 16+/Debian 8+"
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

# Install dependencies
install_dependencies() {
  echo_content green "---> Installing dependencies"

  if [[ "${package_manager}" == 'apt-get' || "${package_manager}" == 'apt' ]]; then
    ${package_manager} update -y
  fi

  ${package_manager} install -y \
    curl \
    wget \
    systemd \
    lrzsz \
    bash-completion

  echo_content skyBlue "---> Dependencies installed"
}

# Prepare environment
prepare_environment() {
  echo_content green "---> Preparing environment"

  # Sync time
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0
  echo_content skyBlue "---> Timezone set to Asia/Shanghai"

  # Restart required services
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

  # Disable SELinux if enabled
  if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    setenforce 0 && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    echo_content skyBlue "---> SELinux disabled"
  fi

  echo_content skyBlue "---> Environment preparation complete"
}

# Configure Docker daemon
setup_docker() {
  echo_content green "---> Configuring Docker daemon"

  mkdir -p ${DOCKER_CONFIG}

  if [[ ${can_access_internet} == 0 ]]; then
    cat >${DOCKER_CONFIG}/daemon.json <<EOF
{
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"100m"
  },
  "registry-mirrors":[${docker_mirror}]
}
EOF
  else
    cat >${DOCKER_CONFIG}/daemon.json <<EOF
{
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"100m"
  }
}
EOF
  fi

  systemctl daemon-reload
  echo_content skyBlue "---> Docker daemon configured"
}

# Install Docker
install_docker() {
  if command -v docker &>/dev/null; then
    echo_content skyBlue "---> Docker is already installed"
    return
  fi

  echo_content green "---> Installing Docker"

  if [[ "${release}" == "centos" ]]; then
    if [[ "${package_manager}" == "dnf" ]]; then
      ${package_manager} install -y dnf-plugins-core
    else
      ${package_manager} install -y yum-utils
    fi
    if [[ ${can_access_internet} == 0 ]]; then
      ${package_manager} config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    else
      ${package_manager} config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
    ${package_manager} makecache || ${package_manager} makecache fast
  elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
    ${package_manager} update -y
    ${package_manager} install -y \
      ca-certificates \
      curl \
      gnupg \
      lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings
    if [[ ${can_access_internet} == 0 ]]; then
      sudo curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/${release}/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/${release} \
                    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    else
      sudo curl -fsSL https://download.docker.com/linux/${release}/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${release} \
            $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi
    ${package_manager} update -y
  fi

  ${package_manager} install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  setup_docker

  systemctl enable docker && systemctl restart docker

  if command -v docker &>/dev/null; then
    echo_content skyBlue "---> Docker installation complete"
  else
    echo_content red "---> Docker installation failed"
    exit 1
  fi
}

# Main execution function
main() {
  cd "$HOME" || exit 1

  # Initialize variables
  init_var

  # Create necessary directories
  create_dirs

  # Check system compatibility
  check_system

  # Install basic dependencies
  install_dependencies

  # Default behavior: prepare environment and install Docker
  prepare_environment

  install_docker
}

# Execute main function with all arguments
main "$@"
