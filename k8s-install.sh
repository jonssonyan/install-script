#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.0.0
# Description: One click install k8s
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # k8s
  k8s_version=""
  is_master=1
  network="flannel"
  K8S_DATA="/k8sdata"
  K8S_LOG="/k8sdata/log"
  K8S_NETWORK="/k8sdata/network"
  K8S_MIRROR="registry.aliyuncs.com/google_containers"
  kube_flannel_url="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  calico_url="https://docs.projectcalico.org/manifests/calico.yaml"

  # Docker
  DOCKER_MIRROR='"https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn","https://registry.docker-cn.com"'
}

mkdir_tools() {
  mkdir -p ${K8S_DATA}
  mkdir -p ${K8S_LOG}
  mkdir -p ${K8S_NETWORK}
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

set_hostname() {
  echo "127.0.0.1 $1" >>/etc/hosts
  hostnamectl --static set-hostname "$1"
}

# 检查系统
check_sys() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "必须是 root 才能运行此脚本"
    exit 1
  fi
  if [[ $(grep -c "processor" /proc/cpuinfo) == 1 && ${is_master} == 1 ]]; then
    echo_content red "主节点 需要 2 CPU 核或更多"
    exit 1
  fi

  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v dnf) ]]; then
    package_manager='dnf'
  elif [[ $(command -v apt) ]]; then
    package_manager='apt'
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

  if [[ $(arch) =~ ("x86_64"|"amd64") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "仅支持x86_64/amd64处理器架构"
    exit 1
  fi
}

# 安装依赖
install_depend() {
  if [[ "${package_manager}" == 'apt' && "${package_manager}" == 'apt-get' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    systemd \
    bash-completion \
    lrzsz
}

# 准备安装
install_prepare() {
  echo_content green "---> 环境准备"
  if [[ ${release} == 'centos' ]]; then
    systemctl disable firewalld.service && systemctl stop firewalld.service
  fi
  if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    setenforce 0 && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  fi
  swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab
  cat >/etc/modules-load.d/k8s.conf <<EOF
br_netfilter
EOF
  cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
  sysctl --system
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0
  systemctl restart rsyslog
  systemctl restart crond
  echo_content green "---> 环境准备完成"
}

# 安装Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> 安装Docker"

    can_connect www.google.com && can_google=1

    mkdir -p /etc/docker
    if [[ ${can_google} == 0 ]]; then
      sh <(curl -sL https://get.docker.com) --mirror Aliyun
      cat >/etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
    ],
    "registry-mirrors":[${DOCKER_MIRROR}]
}
EOF
    else
      sh <(curl -sL https://get.docker.com)
      cat >/etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOF
    fi

    systemctl daemon-reload && systemctl enable docker && systemctl restart docker

    containerd config default >/etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    systemctl enable containerd && systemctl restart containerd

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

# 安装k8s
install_k8s() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
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

    while read -r -p "请输入安装哪个网络系统?(1/flannel 2/calico 默认:1/flannel): " is_master; do
      if [[ -z "${network}" || ${network} == 1 ]]; then
        network="flannel"
        break
      else
        if [[ ${network} != 2 ]]; then
          echo_content red "不可以输入除1和2之外的其他字符"
        else
          network="calico"
          break
        fi
      fi
    done

    if [[ ${can_google} == 0 ]]; then
      # https://developer.aliyun.com/mirror/kubernetes
      if [[ ${release} == 'centos' ]]; then
        if [[ ${can_google} == 0 ]]; then
          cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
        else
          cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
        fi
      elif [[ ${release} == 'debian' || ${release} == 'ubuntu' ]]; then
        ${package_manager} install -y apt-transport-https ca-certificates
        if [[ ${can_google} == 0 ]]; then
          curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
          cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
        else
          curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
          cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main
EOF
        fi
        ${package_manager} update
      else
        echo_content red "仅支持CentOS 7+/Ubuntu 18+/Debian 10+系统"
        exit 1
      fi
    fi
    if [[ -z ${k8s_version} ]]; then
      ${package_manager} install -y kubelet kubeadm kubectl
    else
      if [[ ${package_manager} == "apt" || ${package_manager} == "apt-get" ]]; then
        install_version=$(apt-cache madison kubectl | grep "${k8s_version}" | cut -d \| -f 2 | sed 's/ //g')
        ${package_manager} install -y kubelet="${install_version}" kubeadm="${install_version}" kubectl="${install_version}"
      else
        ${package_manager} install -y --nogpgcheck kubelet-"${k8s_version}" kubeadm-"${k8s_version}" kubectl-"${k8s_version}"
      fi
    fi
    systemctl enable kubelet && systemctl start kubelet

    if [[ $(kubelet --version 2>/dev/null) ]]; then
      echo_content skyBlue "---> k8s安装完成"
      k8s_run
      k8s_network_install
      k8s_bash_completion
    else
      echo_content red "---> k8s安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了k8s"
  fi
}

# 运行k8s
k8s_run() {
  echo_content green "---> 运行k8s"
  if [[ ${is_master} == 1 ]]; then
    # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
    kubeadm init \
      --image-repository ${K8S_MIRROR} \
      --kubernetes-version "${k8s_version}" \
      --apiserver-advertise-address 192.168.0.101 \
      --pod-network-cidr=10.244.0.0/16 \
      --service-cidr=10.96.0.0/12 \
      --token-ttl 0 | tee /k8sdata/log/kubeadm-init.log
    mkdir -p "$HOME"/.kube
    cp -i /etc/kubernetes/admin.conf "$HOM"E/.kube/config
    chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
  else
    echo "该节点为从节点, 请手动运行 kubeadm join 命令. 如果你忘记了命令, 可以在主节点上运行 $(
      echo_content green "kubeadm token create --print-join-command"
    )"
  fi
  echo_content skyBlue "---> k8s运行完成"
}

# 安装网络系统
k8s_network_install() {
  if [[ -n ${network} ]]; then
    echo_content green "---> 安装网络系统"
    if [[ ${network} == "flannel" ]]; then
      wget --no-check-certificate -O /k8sdata/network/flannelkube-flannel.yml ${kube_flannel_url}
      kubectl create -f /k8sdata/network/flannelkube-flannel.yml
    elif [[ ${network} == "calico" ]]; then
      wget --no-check-certificate -O /k8sdata/network/flannelkube-flannel.yml ${calico_url}
      kubectl create -f /k8sdata/network/flannelkube-flannel.yml
    fi
    echo_content skyBlue "---> 网络系统安装完成"
  else
    echo_content red "---> 未设置网络系统"
  fi
}

# k8s命令行补全
k8s_bash_completion() {
  if [[ $(command -v kubectl) ]]; then
    ! grep -q kubectl "$HOME/.bashrc" && echo "source <(kubectl completion bash)" >>"$HOME/.bashrc"
  fi
  if [[ $(command -v kubeadm) ]]; then
    ! grep -q kubeadm "$HOME/.bashrc" && echo "source <(kubeadm completion bash)" >>"$HOME/.bashrc"
  fi
  source "$HOME/.bashrc"
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  install_depend
  install_prepare
  install_docker
  install_k8s
}

main