#!/usr/bin/env bash
# Kubernetes Installation Script
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-script

set -e # Exit immediately if a command exits with a non-zero status

# Initialize variables
init_var() {
  ECHO_TYPE="echo -e"
  SCRIPT_VERSION="1.1.0"

  # System variables
  package_manager=""
  release=""
  version=""
  arch=""
  can_access_internet=1 # Default to true, will be set to 0 if can't reach google

  # Host settings
  host_name="k8s-master"
  public_ip=""

  # K8s directories and files
  K8S_DATA="/k8sdata"
  K8S_LOG="${K8S_DATA}/log"
  K8S_NETWORK="${K8S_DATA}/network"
  k8s_lock_file="${K8S_DATA}/k8s.lock"

  # K8s configuration
  k8s_version="1.29"
  k8s_versions="1.24 1.25 1.26 1.27 1.28 1.29 1.30 1.31"
  is_master=1
  k8s_cri_sock="unix:///var/run/containerd/containerd.sock"
  network="flannel"
  network_file="${K8S_NETWORK}/kube-flannel.yml"

  # URLs and mirrors
  kube_flannel_url="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  calico_url="https://docs.projectcalico.org/manifests/calico.yaml"
  k8s_mirror="https://registry.cn-hangzhou.aliyuncs.com/google_containers"
  docker_mirror='"https://docker.m.daocloud.io"'
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
  mkdir -p ${K8S_DATA} ${K8S_LOG} ${K8S_NETWORK}
}

# Check if can connect to a host
can_connect() {
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  return $?
}

# Get configuration value from lock file
get_config_val() {
  grep "^$1=" ${k8s_lock_file} | cut -d= -f2
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

# Set hostname and update hosts file
set_hostname() {
  echo "${public_ip} $1" >>/etc/hosts
  hostnamectl set-hostname "$1"
  echo_content green "Hostname set to: $1"
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
    bash-completion \
    gpg

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

  # Disable swap
  swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab
  echo_content skyBlue "---> Swap disabled"

  echo_content skyBlue "---> Environment preparation complete"
}

# Configure containerd
configure_containerd() {
  echo_content green "---> Configuring containerd"

  mkdir -p /etc/containerd
  containerd config default >/etc/containerd/config.toml

  # Enable SystemdCgroup
  sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" /etc/containerd/config.toml

  # Configure mirrors if limited internet access
  if [[ ${can_access_internet} == 0 ]]; then
    k8s_mirror_escape=${k8s_mirror//\//\\\/}
    docker_mirror_escape=${docker_mirror//\//\\\/}

    # Replace registry.k8s.io with mirror
    sed -i "s#registry.k8s.io#${k8s_mirror_escape}#g" /etc/containerd/config.toml

    # Add Docker.io mirror
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors\]/a\        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"]" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"\]/a\          endpoint = [${docker_mirror_escape}]" /etc/containerd/config.toml

    # Add registry.k8s.io mirror
    sed -i "/endpoint = \[${docker_mirror_escape}]/a\        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"registry.k8s.io\"]" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"registry.k8s.io\"\]/a\          endpoint = [\"${k8s_mirror_escape}\"]" /etc/containerd/config.toml

    # Add k8s.gcr.io mirror
    sed -i "/endpoint = \[\"${k8s_mirror_escape}\"]/a\        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"k8s.gcr.io\"]" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"k8s.gcr.io\"\]/a\          endpoint = [\"${k8s_mirror_escape}\"]" /etc/containerd/config.toml
  fi

  systemctl daemon-reload
  echo_content skyBlue "---> containerd configured"
}

# Install containerd
install_containerd() {
  if command -v containerd &>/dev/null; then
    echo_content skyBlue "---> containerd is already installed"
    return
  fi

  echo_content green "---> Installing containerd"

  if [[ "${release}" == "centos" ]]; then
    ${package_manager} install -y yum-utils
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

  ${package_manager} install -y containerd.io

  configure_containerd

  systemctl enable containerd && systemctl restart containerd

  if command -v containerd &>/dev/null; then
    echo_content skyBlue "---> containerd installation complete"
  else
    echo_content red "---> containerd installation failed"
    exit 1
  fi
}

# Install Kubernetes runtime
install_runtime() {
  echo_content green "---> Installing container runtime"

  # Setup kernel modules for networking
  cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
  modprobe overlay
  modprobe br_netfilter

  # Setup required sysctl params
  cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
  sysctl --system

  # Install containerd
  install_containerd

  # Save CRI socket to lock file
  echo "k8s_cri_sock=${k8s_cri_sock}" >>${k8s_lock_file}

  echo_content skyBlue "---> Container runtime installation complete"
}

# Setup Kubernetes bash completion
setup_bash_completion() {
  echo_content green "---> Setting up bash completion for Kubernetes tools"

  if ! grep -q bash_completion "$HOME/.bashrc"; then
    echo "source /usr/share/bash-completion/bash_completion" >>"$HOME/.bashrc"
  fi

  if command -v kubectl &>/dev/null && ! grep -q kubectl "$HOME/.bashrc"; then
    echo "source <(kubectl completion bash)" >>"$HOME/.bashrc"
  fi

  if command -v kubeadm &>/dev/null && ! grep -q kubeadm "$HOME/.bashrc"; then
    echo "source <(kubeadm completion bash)" >>"$HOME/.bashrc"
  fi

  if command -v crictl &>/dev/null && ! grep -q crictl "$HOME/.bashrc"; then
    echo "source <(crictl completion bash)" >>"$HOME/.bashrc"
  fi

  source "$HOME/.bashrc"
  echo_content skyBlue "---> Bash completion setup complete"
}

# Install Kubernetes network plugin
install_network_plugin() {
  if ! systemctl is-active kubelet >/dev/null 2>&1; then
    echo_content yellow "---> Kubelet not running, skipping network plugin installation"
    return
  fi

  if kubectl get pods -n kube-system 2>/dev/null | grep -E 'calico|flannel' >/dev/null; then
    echo_content skyBlue "---> Network plugin already installed"
    return
  fi

  echo_content green "---> Installing network plugin: ${network}"

  if [[ ${network} == "flannel" ]]; then
    wget --no-check-certificate -O "${network_file}" ${kube_flannel_url} || {
      echo_content red "---> Failed to download flannel manifest"
      exit 1
    }

    kubectl create -f "${network_file}" || {
      echo_content red "---> Failed to apply flannel manifest"
      exit 1
    }
  elif [[ ${network} == "calico" ]]; then
    wget --no-check-certificate -O "${K8S_NETWORK}/calico.yaml" ${calico_url} || {
      echo_content red "---> Failed to download calico manifest"
      exit 1
    }

    kubectl create -f "${K8S_NETWORK}/calico.yaml" || {
      echo_content red "---> Failed to apply calico manifest"
      exit 1
    }
  fi

  echo_content skyBlue "---> Network plugin installation complete"
}

# Set up Kubernetes components
setup_kubernetes() {
  echo_content green "---> Setting up Kubernetes components"

  # Configure kubelet to use systemd cgroup driver
  for file in /etc/default/kubelet /etc/sysconfig/kubelet; do
    if [[ -f "$file" ]]; then
      if ! grep -q "KUBELET_EXTRA_ARGS" "$file"; then
        echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' >>"$file"
      fi
      break
    fi
  done

  # Configure crictl
  if command -v crictl &>/dev/null; then
    crictl config --set runtime-endpoint=${k8s_cri_sock}
    crictl config --set image-endpoint=${k8s_cri_sock}
  fi

  # Setup bash completion
  setup_bash_completion

  echo_content skyBlue "---> Kubernetes components setup complete"
}

# Setup Kubernetes repository
setup_kubernetes_repo() {
  echo_content green "---> Setting up Kubernetes repository for version ${k8s_version}"

  if [[ "${release}" == "centos" ]]; then
    if [[ ${can_access_internet} == 0 ]]; then
      cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v${k8s_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v${k8s_version}/rpm/repodata/repomd.xml.key
EOF
    else
      cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    fi
  elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
    ${package_manager} install -y apt-transport-https ca-certificates

    if [[ ${can_access_internet} == 0 ]]; then
      curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v"${k8s_version}"/deb/Release.key |
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v${k8s_version}/deb/ /" |
        tee /etc/apt/sources.list.d/kubernetes.list
    else
      mkdir -p -m 755 /etc/apt/keyrings
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v"${k8s_version}"/deb/Release.key |
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" |
        tee /etc/apt/sources.list.d/kubernetes.list
    fi

    ${package_manager} update -y
  fi

  echo_content skyBlue "---> Kubernetes repository setup complete"
}

# Install Kubernetes
install_kubernetes() {
  if command -v kubeadm &>/dev/null; then
    echo_content skyBlue "---> Kubernetes is already installed"
    return
  fi

  echo_content green "---> Installing Kubernetes ${k8s_version}"

  # Get node type
  echo_content yellow "Please select node type:"
  echo_content yellow "1) Master node (control plane)"
  echo_content yellow "2) Worker node"
  read -r -p "Your choice (default: 1): " node_type_choice

  case ${node_type_choice} in
  2)
    is_master=0
    ;;
  *)
    is_master=1
    ;;
  esac

  echo "is_master=${is_master}" >>${k8s_lock_file}

  # Check CPU cores for master node
  if [[ ${is_master} == 1 && $(grep -c "processor" /proc/cpuinfo) -lt 2 ]]; then
    echo_content red "Error: Master node requires at least 2 CPU cores"
    exit 1
  fi

  # Get public IP
  echo_content yellow "Please enter this node's public IP address (required):"
  read -r -p "> " public_ip

  if [[ -z "${public_ip}" ]]; then
    echo_content red "Error: Public IP cannot be empty"
    exit 1
  fi

  echo "public_ip=${public_ip}" >>${k8s_lock_file}

  # Get hostname
  echo_content yellow "Please enter hostname for this node (default: k8s-master):"
  read -r -p "> " host_name

  [[ -z "${host_name}" ]] && host_name="k8s-master"
  set_hostname ${host_name}

  # Get Kubernetes version
  echo_content yellow "Please select Kubernetes version:"
  echo_content yellow "Available versions: ${k8s_versions}"
  read -r -p "Enter version (default: ${k8s_version}): " selected_version

  [[ -z "${selected_version}" ]] && selected_version="${k8s_version}"

  if ! echo "${k8s_versions}" | grep -w -q "${selected_version}"; then
    echo_content red "Error: Version ${selected_version} is not supported"
    exit 1
  fi

  k8s_version="${selected_version}"
  echo "k8s_version=${k8s_version}" >>${k8s_lock_file}

  # Install container runtime
  install_runtime

  # Setup Kubernetes repositories
  setup_kubernetes_repo

  # Install Kubernetes components
  echo_content green "---> Installing Kubernetes components for version ${k8s_version}"

  if [[ -z "${k8s_version}" ]]; then
    ${package_manager} install -y kubelet kubeadm kubectl
  else
    if [[ ${package_manager} == "yum" || ${package_manager} == "dnf" ]]; then
      ${package_manager} install -y kubelet-"${k8s_version}" kubeadm-"${k8s_version}" kubectl-"${k8s_version}"
    elif [[ ${package_manager} == "apt" || ${package_manager} == "apt-get" ]]; then
      kubelet_version=$(apt-cache madison kubelet | grep ${k8s_version} | head -n1 | awk '{print $3}')
      kubeadm_version=$(apt-cache madison kubeadm | grep ${k8s_version} | head -n1 | awk '{print $3}')
      kubectl_version=$(apt-cache madison kubectl | grep ${k8s_version} | head -n1 | awk '{print $3}')
      ${package_manager} install -y kubelet="${kubelet_version}" kubeadm="${kubeadm_version}" kubectl="${kubectl_version}"
    fi
  fi

  # Setup Kubernetes components
  setup_kubernetes

  # Enable and start kubelet
  systemctl enable --now kubelet

  if command -v kubeadm &>/dev/null; then
    echo_content skyBlue "---> Kubernetes installation complete"
  else
    echo_content red "---> Kubernetes installation failed"
    exit 1
  fi
}

# Initialize Kubernetes master node
initialize_kubernetes_master() {
  if ! command -v kubeadm &>/dev/null; then
    echo_content red "---> Kubernetes is not installed. Please install Kubernetes first."
    return
  fi

  # Load configuration from lock file
  is_master=$(get_config_val is_master)
  public_ip=$(get_config_val public_ip)
  k8s_version=$(get_config_val k8s_version)
  k8s_cri_sock=$(get_config_val k8s_cri_sock)

  if [[ "${is_master}" != "1" ]]; then
    echo_content yellow "---> This is configured as a worker node."
    echo_content yellow "---> Please run 'kubeadm join' command provided by your master node."
    echo_content yellow "---> If you forgot the command, run this on the master node:"
    echo_content green "     kubeadm token create --print-join-command"
    return
  fi

  echo_content green "---> Initializing Kubernetes master node"

  # Get exact Kubernetes version
  k8s_version_mini=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-"${k8s_version}".txt) || {
    echo_content yellow "---> Could not determine exact Kubernetes version, using specified version"
    k8s_version_mini="v${k8s_version}.0"
  }

  # Initialize Kubernetes master
  local init_log="${K8S_LOG}/kubeadm-init-$(date +%Y%m%d-%H%M%S).log"

  echo_content green "---> Running kubeadm init with version ${k8s_version_mini}"

  if [[ ${can_access_internet} == 0 ]]; then
    kubeadm init \
      --apiserver-advertise-address="${public_ip}" \
      --image-repository="${k8s_mirror}" \
      --kubernetes-version="${k8s_version_mini}" \
      --service-cidr=10.96.0.0/12 \
      --pod-network-cidr=10.244.0.0/16 \
      --cri-socket="${k8s_cri_sock}" | tee "${init_log}"
  else
    kubeadm init \
      --apiserver-advertise-address="${public_ip}" \
      --kubernetes-version="${k8s_version_mini}" \
      --service-cidr=10.96.0.0/12 \
      --pod-network-cidr=10.244.0.0/16 \
      --cri-socket="${k8s_cri_sock}" | tee "${init_log}"
  fi

  if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    # Set up kubeconfig
    mkdir -p "$HOME"/.kube
    cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
    chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

    echo_content skyBlue "---> Kubernetes master node initialization complete"

    # Extract join command for future use
    local join_command=$(grep -A 1 "kubeadm join" "${init_log}" | tr -d '\\\n' | sed 's/^[ \t]*//')
    echo "${join_command}" >"${K8S_DATA}/join-command.txt"
    echo_content green "---> Worker join command saved to ${K8S_DATA}/join-command.txt"

    # Install network plugin
    install_network_plugin

    # Print cluster status
    echo_content green "---> Kubernetes cluster status:"
    kubectl get nodes
  else
    echo_content red "---> Kubernetes master node initialization failed"
    echo_content yellow "---> Check logs in ${init_log}"
    exit 1
  fi
}

# Reset Kubernetes
reset_kubernetes() {
  if ! command -v kubeadm &>/dev/null; then
    echo_content yellow "---> Kubernetes is not installed, nothing to reset"
    return
  fi

  echo_content green "---> Resetting Kubernetes cluster"

  echo_content yellow "WARNING: This will remove all Kubernetes configurations and data!"
  read -r -p "Are you sure you want to continue? (y/N): " confirm_reset

  if [[ ! ${confirm_reset} =~ ^[Yy]$ ]]; then
    echo_content yellow "---> Reset cancelled"
    return
  fi

  # Reset Kubernetes
  kubeadm reset -f

  # Clean up directories
  rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/run/kubernetes "$HOME"/.kube

  # Reset iptables
  iptables -F && iptables -X
  iptables -t nat -F && iptables -t nat -X
  iptables -t raw -F && iptables -t raw -X
  iptables -t mangle -F && iptables -t mangle -X

  # Reload systemd
  systemctl daemon-reload

  # Restart container runtime
  if command -v docker &>/dev/null; then
    systemctl restart docker
  elif command -v containerd &>/dev/null; then
    systemctl restart containerd
  fi

  # Apply sysctl settings
  sysctl --system

  # Remove lock file
  rm -f ${k8s_lock_file}

  echo_content skyBlue "---> Kubernetes reset complete"
}

# Display cluster information
show_cluster_info() {
  if ! command -v kubectl &>/dev/null; then
    echo_content yellow "---> Kubernetes is not installed"
    return
  fi

  if ! kubectl cluster-info &>/dev/null; then
    echo_content yellow "---> Kubernetes cluster is not running or kubeconfig is not configured"
    return
  fi

  echo_content green "---> Cluster Information"
  echo "----------------------------------------"
  kubectl cluster-info
  echo "----------------------------------------"
  echo_content green "---> Node Status"
  echo "----------------------------------------"
  kubectl get nodes -o wide
  echo "----------------------------------------"
  echo_content green "---> Pod Status"
  echo "----------------------------------------"
  kubectl get pods --all-namespaces
  echo "----------------------------------------"
}

# Display installation help
show_help() {
  echo_content green "Kubernetes Installation Script v${SCRIPT_VERSION}"
  echo_content green "Usage: $0 [option]"
  echo_content green "Options:"
  echo_content yellow "  install    Install Kubernetes"
  echo_content yellow "  init       Initialize Kubernetes master node"
  echo_content yellow "  reset      Reset Kubernetes cluster"
  echo_content yellow "  info       Show cluster information"
  echo_content yellow "  help       Show this help message"
  echo_content yellow "If no option is provided, the interactive menu will be displayed."
}

# Main menu for interactive use
show_menu() {
  clear
  echo_content red "=============================================================="
  echo_content skyBlue "Kubernetes Installation Script v${SCRIPT_VERSION}"
  echo_content skyBlue "Supported OS: CentOS 8+/Ubuntu 20+/Debian 11+"
  echo_content skyBlue "Author: Original by jonssonyan, optimized version"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-script"
  echo_content red "=============================================================="
  echo_content yellow "1. Install Kubernetes"
  echo_content yellow "2. Initialize Kubernetes Master Node"
  echo_content yellow "3. Show Cluster Information"
  echo_content red "=============================================================="
  echo_content yellow "4. Reset Kubernetes"
  echo_content red "=============================================================="
  echo_content yellow "0. Exit"
  echo_content red "=============================================================="
}

# Check if lock file exists and load configuration
check_lock_file() {
  if [[ -f "${k8s_lock_file}" ]]; then
    echo_content skyBlue "---> Loading configuration from ${k8s_lock_file}"

    is_master=$(get_config_val is_master)
    public_ip=$(get_config_val public_ip)
    k8s_version=$(get_config_val k8s_version)
    k8s_cri_sock=$(get_config_val k8s_cri_sock)

    echo_content skyBlue "---> Configuration loaded"
  else
    echo_content yellow "---> No configuration found. This appears to be a new installation."
  fi
}

# Process CLI arguments
process_args() {
  case "$1" in
  install)
    prepare_environment
    install_kubernetes
    ;;
  init)
    initialize_kubernetes_master
    ;;
  reset)
    reset_kubernetes
    ;;
  info)
    show_cluster_info
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

  # Check for existing configuration
  check_lock_file

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
      prepare_environment
      install_kubernetes
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    2)
      initialize_kubernetes_master
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    3)
      show_cluster_info
      echo_content yellow "Press Enter to continue..."
      read -r
      ;;
    4)
      reset_kubernetes
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
