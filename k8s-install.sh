#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  version=""
  get_arch=""

  can_google=0

  host_name="k8s-master"
  public_ip=""

  # k8s
  K8S_DATA="/k8sdata"
  K8S_LOG="/k8sdata/log"
  K8S_NETWORK="/k8sdata/network"
  k8s_lock_file="/k8sdata/k8s.lock"

  k8s_version="1.29"
  k8s_versions="1.24 1.25 1.26 1.27 1.28 1.29 1.30 1.31"
  is_master=1
  k8s_cri_sock="unix:///var/run/containerd/containerd.sock"
  network="flannel"
  network_file="/k8sdata/network/kube-flannel.yml"

  kube_flannel_url="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  calico_url="https://docs.projectcalico.org/manifests/calico.yaml"
  k8s_mirror="registry.cn-hangzhou.aliyuncs.com/google_containers"
  docker_mirror='"https://docker.m.daocloud.io"'
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
  mkdir -p ${K8S_DATA}
  mkdir -p ${K8S_LOG}
  mkdir -p ${K8S_NETWORK}
}

can_connect() {
  if ping -c2 -i0.3 -W1 "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

get_config_val() {
  while read -r line; do
    k=${line%=*}
    v=${line#*=}
    if [[ "${k}" == "$1" ]]; then
      echo "${v}"
      break
    fi
  done <${k8s_lock_file}
}

service_exists() {
  systemctl list-units --type=service --all | grep -Fq "$1.service"
}

# 检查系统
check_sys() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "You must be root to run this script"
    exit 1
  fi

  can_connect www.google.com && can_google=1

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
    echo_content red "This system is not currently supported"
    exit 1
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
    if rpm -q centos-stream-release &>/dev/null; then
      version=$(rpm -q --queryformat '%{VERSION}' centos-stream-release)
    elif rpm -q centos-release &>/dev/null; then
      version=$(rpm -q --queryformat '%{VERSION}' centos-release)
    fi
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
    version=$(cat /etc/debian_version)
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
    version=$(lsb_release -sr)
  fi

  major_version=$(echo "${version}" | cut -d. -f1)

  case $release in
  centos)
    if [[ $major_version -ge 6 ]]; then
      echo_content green "Supported CentOS version detected: $version"
    else
      echo_content red "Unsupported CentOS version: $version. Only supports CentOS 6+."
      exit 1
    fi
    ;;
  ubuntu)
    if [[ $major_version -ge 16 ]]; then
      echo_content green "Supported Ubuntu version detected: $version"
    else
      echo_content red "Unsupported Ubuntu version: $version. Only supports Ubuntu 16+."
      exit 1
    fi
    ;;
  debian)
    if [[ $major_version -ge 8 ]]; then
      echo_content green "Supported Debian version detected: $version"
    else
      echo_content red "Unsupported Debian version: $version. Only supports Debian 8+."
      exit 1
    fi
    ;;
  *)
    echo_content red "Only supports CentOS 6+/Ubuntu 16+/Debian 8+"
    exit 1
    ;;
  esac

  if [[ $(arch) =~ ("x86_64"|"amd64") ]]; then
    get_arch="amd64"
  elif [[ $(arch) =~ ("aarch64"|"arm64") ]]; then
    get_arch="arm64"
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "Only supports x86_64/amd64 arm64/aarch64"
    exit 1
  fi
}

# 修改主机名
set_hostname() {
  echo "${public_ip} $1" >>/etc/hosts
  hostnamectl set-hostname "$1"
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
    bash-completion \
    gpg
}

# 环境准备
install_prepare() {
  # 同步时间
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0

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
}

setup_containerd() {
  mkdir -p /etc/containerd
  containerd config default >/etc/containerd/config.toml
  sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" /etc/containerd/config.toml
  if [[ ${can_google} == 0 ]]; then
    k8s_mirror_escape=${k8s_mirror//\//\\\/}
    docker_mirror_escape=${docker_mirror//\//\\\/}
    sed -i "s#registry.k8s.io#${k8s_mirror_escape}#g" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors\]/a\        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"]" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"\]/a\          endpoint = [${docker_mirror_escape}]" /etc/containerd/config.toml
    sed -i "/endpoint = \[${docker_mirror_escape}]/a\        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"registry.k8s.io\"]" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"registry.k8s.io\"\]/a\          endpoint = [\"${k8s_mirror_escape}\"]" /etc/containerd/config.toml
    sed -i "/endpoint = \[\"${k8s_mirror_escape}\"]/a\        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"k8s.gcr.io\"]" /etc/containerd/config.toml
    sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"k8s.gcr.io\"\]/a\          endpoint = [\"${k8s_mirror_escape}\"]" /etc/containerd/config.toml
  fi
  systemctl daemon-reload
}

# 安装 Containerd
install_containerd() {
  if [[ ! $(command -v containerd) ]]; then
    echo_content green "---> 安装 Containerd"

    if [[ "${release}" == "centos" ]]; then
      ${package_manager} install -y yum-utils
      if [[ ${can_google} == 0 ]]; then
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
      if [[ ${can_google} == 0 ]]; then
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

    setup_containerd

    systemctl enable containerd && systemctl restart containerd

    if [[ $(command -v containerd) ]]; then
      echo_content skyBlue "---> Containerd 安装完成"
    else
      echo_content red "---> Containerd 安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了 Containerd"
  fi
}

# 安装运行时
install_runtime() {
  echo_content green "---> 安装运行时"

  # 转发 IPv4 并让 iptables 看到桥接流量
  cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
  modprobe overlay
  modprobe br_netfilter

  cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
  sysctl --system

  install_containerd

  echo "k8s_cri_sock=${k8s_cri_sock}" >>${k8s_lock_file}

  echo_content skyBlue "---> 运行时安装完成"
}

# k8s 命令行补全
k8s_bash_completion() {
  ! grep -q bash_completion "$HOME/.bashrc" && echo "source /usr/share/bash-completion/bash_completion" >>"$HOME/.bashrc"
  if [[ $(command -v kubectl) ]]; then
    ! grep -q kubectl "$HOME/.bashrc" && echo "source <(kubectl completion bash)" >>"$HOME/.bashrc"
  fi
  if [[ $(command -v kubeadm) ]]; then
    ! grep -q kubeadm "$HOME/.bashrc" && echo "source <(kubeadm completion bash)" >>"$HOME/.bashrc"
  fi
  if [[ $(command -v crictl) ]]; then
    ! grep -q crictl "$HOME/.bashrc" && echo "source <(crictl completion bash)" >>"$HOME/.bashrc"
  fi
  source "$HOME/.bashrc"
}

# 安装网络系统
k8s_network_install() {
  systemctl status kubelet
  if [[ ${PIPESTATUS[0]} -eq 0 && -z $(kubectl get pods -n kube-system | grep -E 'calico|flannel') ]]; then
    echo_content green "---> 安装网络系统"

    #    while read -r -p "请输入安装哪个网络系统?(1/flannel 2/calico 默认:1/flannel): " networkNum; do
    #      if [[ -z "${networkNum}" || ${networkNum} == 1 ]]; then
    #        network="flannel"
    #        break
    #      else
    #        if [[ ${networkNum} != 2 ]]; then
    #          echo_content red "不可以输入除1和2之外的其他字符"
    #        else
    #          network="calico"
    #          break
    #        fi
    #      fi
    #    done

    if [[ ${network} == "flannel" ]]; then
      wget --no-check-certificate -O "${network_file}" ${kube_flannel_url}
      kubectl create -f "${network_file}"
    fi

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
      echo_content skyBlue "---> 网络系统安装完成"
    else
      echo_content red "---> 网络系统安装失败"
    fi
  fi
}

setup_k8s() {
  cat >/etc/sysconfig/kubelet <<EOF
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
EOF
  if [[ $(command -v crictl) ]]; then
    crictl config --set runtime-endpoint=${k8s_cri_sock}
    crictl config --set image-endpoint=${k8s_cri_sock}
  fi
  k8s_bash_completion
}

# 1.24 版本及以上的 K8s
k8s_ge_1_24() {
  if [[ "${release}" == "centos" ]]; then
    if [[ ${can_google} == 0 ]]; then
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
    if [[ ${can_google} == 0 ]]; then
      curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v"${k8s_version}"/deb/Release.key |
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v${k8s_version}/deb/ /" |
        tee /etc/apt/sources.list.d/kubernetes.list
    else
      mkdir -p -m 755 /etc/apt/keyrings
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v"${k8s_version}"/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    fi
    ${package_manager} update -y
  fi
}

# 安装 k8s
k8s_install() {
  if [[ ! $(command -v kubeadm) ]]; then
    echo_content green "---> 安装k8s"

    while read -r -p "请输入是否为主节点?(0/否 1/是 默认:1/是): " is_master; do
      if [[ -z "${is_master}" || ${is_master} == 1 ]]; then
        is_master=1
        break
      else
        if [[ ${is_master} != 0 ]]; then
          echo_content red "不可以输入除0和1之外的其他字符"
        else
          break
        fi
      fi
    done
    echo "is_master=${is_master}" >>${k8s_lock_file}

    if [[ $(grep -c "processor" /proc/cpuinfo) == 1 && ${is_master} == 1 ]]; then
      echo_content red "主节点需要CPU 2核心及以上"
      exit 1
    fi

    while read -r -p "请输入本机公网IP(必填): " public_ip; do
      if [[ -z "${public_ip}" ]]; then
        echo_content red "公网IP不能为空"
      else
        break
      fi
    done
    echo "public_ip=${public_ip}" >>${k8s_lock_file}

    # 设置主机名称
    read -r -p "请输入主机名(默认:k8s-master): " host_name
    [[ -z "${host_name}" ]] && host_name="k8s-master"
    set_hostname ${host_name}

    while read -r -p "请输入 K8s 版本(1.24-1.31 默认:1.29): " k8s_version; do
      [[ -z "${k8s_version}" ]] && k8s_version="1.29"
      if echo "${k8s_versions}" | grep -w -q "${k8s_version}"; then
        break
      else
        echo_content red "不支持 ${k8s_version}"
      fi
    done
    echo "k8s_version=${k8s_version}" >>${k8s_lock_file}

    # 关闭selinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
      setenforce 0 && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    fi

    # 关闭swap分区
    swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab

    # 安装运行时 https://v1-29.docs.kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/
    install_runtime

    k8s_ge_1_24

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

    setup_k8s

    systemctl enable --now kubelet

    if [[ $(command -v kubeadm) ]]; then
      echo_content skyBlue "---> k8s 安装完成"
    else
      echo_content red "---> k8s 安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了 k8s"
  fi
}

# 运行 k8s
k8s_run() {
  if [[ $(command -v kubeadm) ]]; then
    is_master=$(get_config_val is_master)
    public_ip=$(get_config_val public_ip)
    k8s_version=$(get_config_val k8s_version)
    k8s_cri_sock=$(get_config_val k8s_cri_sock)

    if [[ "${is_master}" == "1" ]]; then
      echo_content green "---> 运行k8s"

      # 精确到小版本
      k8s_version_mini=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-"${k8s_version}".txt)

      # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
      if [[ ${can_google} == 0 ]]; then
        kubeadm init \
          --apiserver-advertise-address="${public_ip}" \
          --image-repository="${k8s_mirror}" \
          --kubernetes-version="${k8s_version_mini}" \
          --service-cidr=10.96.0.0/12 \
          --pod-network-cidr=10.244.0.0/16 \
          --cri-socket="${k8s_cri_sock}" | tee /k8sdata/log/kubeadm-init.log
      else
        kubeadm init \
          --apiserver-advertise-address="${public_ip}" \
          --kubernetes-version="${k8s_version_mini}" \
          --service-cidr=10.96.0.0/12 \
          --pod-network-cidr=10.244.0.0/16 \
          --cri-socket="${k8s_cri_sock}" | tee /k8sdata/log/kubeadm-init.log
      fi

      if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        mkdir -p "$HOME"/.kube
        cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
        chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
        echo_content skyBlue "---> k8s 运行完成"
        k8s_network_install
      else
        echo_content red "---> k8s 运行失败"
        exit 1
      fi
    elif [[ "${is_master}" == "0" ]]; then
      echo "该节点为从节点, 请手动运行 kubeadm join 命令. 如果你忘记了命令, 可以在主节点上运行 $(
        echo_content yellow "kubeadm token create --print-join-command"
      )"
    fi
  else
    echo_content skyBlue "---> 请先安装 K8s"
  fi
}

# 重设 K8s
k8s_reset() {
  if [[ $(command -v kubeadm) ]]; then
    echo_content green "---> 重设 K8s"

    kubeadm reset -f
    rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/run/kubernetes "$HOME"/.kube
    iptables -F && iptables -X
    iptables -t nat -F && iptables -t nat -X
    iptables -t raw -F && iptables -t raw -X
    iptables -t mangle -F && iptables -t mangle -X
    systemctl daemon-reload
    if [[ ! $(command -v docker) ]]; then
      systemctl restart docker
    elif [[ ! $(command -v containerd) ]]; then
      systemctl restart containerd
    fi

    echo_content skyBlue "---> 重设 K8s 完成"
  else
    echo_content skyBlue "---> 请先安装 K8s"
  fi
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  install_depend
  clear
  echo_content red "=============================================================="
  echo_content skyBlue "Recommended OS: CentOS 8+/Ubuntu 20+/Debian 11+"
  echo_content skyBlue "Description: Install K8s"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-script"
  echo_content red "=============================================================="
  echo_content yellow "1. 安装 K8s"
  echo_content yellow "2. 运行 K8s"
  echo_content red "=============================================================="
  echo_content yellow "3. 重设 K8s"
  echo_content red "=============================================================="
  read -r -p "Please choose:" input_option
  case ${input_option} in
  1)
    install_prepare
    k8s_install
    ;;
  2)
    k8s_run
    ;;
  3)
    k8s_reset
    ;;
  *)
    echo_content red "No such option"
    ;;
  esac
}

main
