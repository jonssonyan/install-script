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
  network=""
  is_master=0
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
  mkir - p ${K8S_DATA}
  mkir - p ${K8S_LOG}
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
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  if [[ "$?" == "0" ]]; then
    return 0
  else
    return 1
  fi
}

set_hostname() {
  local hostname=$1
  if [[ ${hostname} =~ '_' ]]; then
    echo_content red "hostname can't contain '_' character, auto change to '-'.."
    hostname=$(echo ${hostname} | sed 's/_/-/g')
  fi
  echo_content skyBlue "127.0.0.1 ${hostname}" >>/etc/hosts
  hostnamectl --static set-hostname ${hostname}
}

check_sys() {
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
    exit 0
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
    exit 0
  fi

  if [[ $(arch) =~ ("x86_64"|"amd64") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "仅支持amd64处理器架构"
    exit 0
  fi
}

install_depend() {
  if [[ "${package_manager}" != 'yum' && "${package_manager}" != 'dnf' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    systemd \
    bash-completion \
    lrzsz
}

install_prepare() {
  echo_content green "---> 准备安装"
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
  systemctl restart rsyslog && systemctl restart crond
  echo_content green "---> 准备安装完成"
}

# 安装Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> 安装Docker"

    can_connect www.google.com
    [[ "$?" == "0" ]] && can_google=1

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

    containerd config default >/etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    systemctl enable containerd && systemctl restart containerd

    systemctl daemon-reload && systemctl enable docker && systemctl restart docker

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
}

k8s_install() {
  echo_content green "---> 安装k8s"
  if [[ ${release} == 'centos' ]]; then
    cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    setenforce 0
    yum install -y --nogpgcheck kubeadm-${k8s_version} kubelet-${k8s_version} kubectl-${k8s_version}
    systemctl enable kubelet && systemctl start kubelet
  elif [[ ${release} == 'debian' || ${release} == 'ubuntu' ]]; then
    apt-get update && apt-get install -y apt-transport-https
    curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
    apt-get update
    apt-get install -y kubeadm-${k8s_version} kubelet-${k8s_version} kubectl-${k8s_version}
  else
    echo_content red "仅支持CentOS 7+/Ubuntu 18+/Debian 10+系统"
    exit 0
  fi
  k8s_version=$(kubectl version --output=yaml | grep gitVersion | awk 'NR==1{print $2}')
  echo_content skyBlue "---> k8s安装完成"
}

k8s_run() {
  echo_content green "---> 运行k8s"
  if [[ ${is_master} == 1 ]]; then
    kubeadm init \
      --image-repository ${K8S_MIRROR} \
      --kubernetes-version ${k8s_version} \
      --apiserver-advertise-address 192.168.0.101 \
      --pod-network-cidr=10.244.0.0/16 \
      --service-cidr=10.233.0.0/16 \
      --token-ttl 0 | tee /k8sdata/log/kubeadm-init.log
    mkdir -p "$HOME"/.kube
    cp -i /etc/kubernetes/admin.conf "$HOM"E/.kube/config
    chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
  else
    echo "this node is slave, please manual run 'kubeadm join' command. if forget join command, please run $(
      echo_content green
      "kubeadm token create --print-join-command"
    ) in master node"
  fi
  echo_content skyBlue "---> k8s运行完成"
}

k8s_network_install() {
  echo_content green "---> 安装k8s网络"
  if [[ ${network} == "flannel" ]]; then
    wget --no-check-certificate -O /k8sdata/network/flannelkube-flannel.yml ${kube_flannel_url}
    kubectl create -f /k8sdata/network/flannelkube-flannel.yml
  elif [[ ${network} == "calico" ]]; then
    wget --no-check-certificate -O /k8sdata/network/flannelkube-flannel.yml ${calico_url}
    kubectl create -f /k8sdata/network/flannelkube-flannel.yml
  fi
  echo_content skyBlue "---> k8s网络安装完成"
}

k8s_bash_completion() {
  if [[ $(command -v kubectl) ]]; then
    source <(kubectl completion bash)
    [[ -z $(grep kubectl ~/.bashrc) ]] && echo "source <(kubectl completion bash)" >>~/.bashrc
  fi
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  install_depend
  install_prepare
  install_docker
  k8s_install
  k8s_run
  k8s_network_install
  k8s_bash_completion
}

main
