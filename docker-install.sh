#!/usr/bin/env bash
# Docker Services Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e # Exit immediately if a command exits with a non-zero status

# Initialize variables
init_var() {
  ECHO_TYPE="echo -e"
  SCRIPT_VERSION="1.2.0"

  # System variables
  package_manager=""
  release=""
  version=""
  arch=""

  # Docker directories and files
  DOCKER_DATA="/dockerdata"

  # Remote script base URL
  REMOTE_SCRIPT_BASE="https://github.com/jonssonyan/install-script/raw/main/docker"
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
create_directories() {
  mkdir -p ${DOCKER_DATA}
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

  # Disable SELinux
  if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    setenforce 0 && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    echo_content skyBlue "---> SELinux disabled"
  fi

  echo_content skyBlue "---> Environment preparation complete"
}

# Install Docker service with remote script
install_docker_service() {
  local service_name=$1
  local script_name=$2
  local require_docker=$3

  echo_content green "---> Installing ${service_name}"

  # Check if Docker is required and not installed
  if [[ "${require_docker}" == "true" ]] && ! command -v docker &>/dev/null; then
    echo_content yellow "---> Docker not found, installing Docker first..."
    bash <(curl -fsSL ${REMOTE_SCRIPT_BASE}/docker.sh)
  fi

  # Run the remote installation script
  bash <(curl -fsSL ${REMOTE_SCRIPT_BASE}/${script_name})

  echo_content skyBlue "---> ${service_name} installation complete"
}

# Show installation help
show_help() {
  echo_content green "Docker Services Installation Script v${SCRIPT_VERSION}"
  echo_content green "Usage: $0 [option]"
  echo_content green "Options:"
  echo_content yellow "  docker            Install Docker Engine"
  echo_content yellow "  buildx            Install Docker Buildx"
  echo_content yellow "  uninstall         Uninstall Docker"
  echo_content yellow "  mysql             Install MySQL 5.7.38"
  echo_content yellow "  postgresql        Install PostgreSQL 13"
  echo_content yellow "  redis             Install Redis 6.2.13"
  echo_content yellow "  elasticsearch     Install Elasticsearch 7.17.10"
  echo_content yellow "  kibana            Install Kibana 7.17.10"
  echo_content yellow "  minio             Install Minio"
  echo_content yellow "  nacos             Install Nacos v2.1.2"
  echo_content yellow "  ssr               Install ShadowsocksR"
  echo_content yellow "  nexus3            Install Nexus3"
  echo_content yellow "  gitlab            Install GitLab"
  echo_content yellow "  skywalking-oap    Install SkyWalking OAP"
  echo_content yellow "  skywalking-ui     Install SkyWalking UI"
  echo_content yellow "  rustdesk-server   Install RustDesk Server"
  echo_content yellow "  help              Show this help message"
  echo_content yellow "If no option is provided, the interactive menu will be displayed."
}

# Main menu for interactive use
show_menu() {
  clear
  echo_content red "=============================================================="
  echo_content skyBlue "Docker Services Installation Script v${SCRIPT_VERSION}"
  echo_content skyBlue "Supported OS: CentOS 8+/Ubuntu 20+/Debian 11+"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-script"
  echo_content red "=============================================================="
  echo_content yellow "1. Install Docker Engine"
  echo_content yellow "2. Install Docker Buildx"
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
  echo_content yellow "16. Install RustDesk Server"
  echo_content red "=============================================================="
  echo_content yellow "0. Exit"
  echo_content red "=============================================================="
}

# Process CLI arguments
process_args() {
  case "$1" in
  docker)
    prepare_environment
    install_docker_service "Docker Engine" "docker.sh" "false"
    ;;
  buildx)
    install_docker_service "Docker Buildx" "buildx.sh" "true"
    ;;
  uninstall)
    install_docker_service "Docker" "uninstall.sh" "true"
    ;;
  mysql)
    install_docker_service "MySQL" "mysql.sh" "true"
    ;;
  postgresql)
    install_docker_service "PostgreSQL" "postgresql.sh" "true"
    ;;
  redis)
    install_docker_service "Redis" "redis.sh" "true"
    ;;
  elasticsearch)
    install_docker_service "Elasticsearch" "es.sh" "true"
    ;;
  kibana)
    install_docker_service "Kibana" "kibana.sh" "true"
    ;;
  minio)
    install_docker_service "Minio" "minio.sh" "true"
    ;;
  nacos)
    install_docker_service "Nacos" "nacos.sh" "true"
    ;;
  ssr)
    install_docker_service "ShadowsocksR" "ssr.sh" "true"
    ;;
  nexus3)
    install_docker_service "Nexus3" "nexus3.sh" "true"
    ;;
  gitlab)
    install_docker_service "GitLab" "gitlab.sh" "true"
    ;;
  skywalking-oap)
    install_docker_service "SkyWalking OAP" "skywalking-oap.sh" "true"
    ;;
  skywalking-ui)
    install_docker_service "SkyWalking UI" "skywalking-ui.sh" "true"
    ;;
  rustdesk-server)
    install_docker_service "RustDesk Server" "rustdesk-server.sh" "true"
    ;;
  help | --help | -h)
    show_help
    ;;
  *)
    return 1
    ;;
  esac
  return 0
}

# Main execution function
main() {
  cd "$HOME" || exit 1

  # Initialize variables
  init_var

  # Create necessary directories
  create_directories

  # Check system compatibility
  check_system

  # Install basic dependencies
  install_dependencies

  # Prepare environment
  prepare_environment

  # Process command line arguments if provided
  if [[ $# -gt 0 ]]; then
    if process_args "$@"; then
      exit 0
    fi
  fi

  # Interactive menu
  while true; do
    show_menu
    read -r -p "Please choose an option: " input_option
    case ${input_option} in
    1)
      install_docker_service "Docker Engine" "install.sh" "false"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    2)
      install_docker_service "Docker Buildx" "buildx.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    3)
      install_docker_service "Docker" "uninstall.sh"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    4)
      install_docker_service "MySQL" "mysql.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    5)
      install_docker_service "PostgreSQL" "postgresql.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    6)
      install_docker_service "Redis" "redis.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    7)
      install_docker_service "Elasticsearch" "es.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    8)
      install_docker_service "Kibana" "kibana.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    9)
      install_docker_service "Minio" "minio.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    10)
      install_docker_service "Nacos" "nacos.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    11)
      install_docker_service "ShadowsocksR" "ssr.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    12)
      install_docker_service "Nexus3" "nexus3.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    13)
      install_docker_service "GitLab" "gitlab.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    14)
      install_docker_service "SkyWalking OAP" "skywalking-oap.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    15)
      install_docker_service "SkyWalking UI" "skywalking-ui.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    16)
      install_docker_service "RustDesk Server" "rustdesk-server.sh" "true"
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    0)
      echo_content green "Exiting..."
      exit 0
      ;;
    *)
      echo_content red "Invalid option. Please try again."
      sleep 2
      ;;
    esac
  done
}

# Execute main function with all arguments
main "$@"
