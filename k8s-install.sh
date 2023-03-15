#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.0.0
# Description: One click install K8s
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/jonssonyan/install-scipt

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  host_name="k8s-master"
  public_ip=""

  # k8s
  K8S_DATA="/k8sdata"
  K8S_LOG="/k8sdata/log"
  K8S_NETWORK="/k8sdata/network"

  k8s_version="1.23.17"
  is_master=1
  network="flannel"
  k8s_mirror="registry.cn-hangzhou.aliyuncs.com/google_containers"
  kube_flannel_url="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  calico_url="https://docs.projectcalico.org/manifests/calico.yaml"

  # Docker
  docker_version="20.10.23"
  docker_mirror='"https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn","https://registry.docker-cn.com"'
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

  can_connect www.google.com && can_google=1
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
    bash-completion
}

# 环境准备
install_prepare() {
  echo_content green "---> 环境准备"

  # 同步时间
  timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0
  systemctl restart rsyslog
  systemctl restart crond

  # 关闭防火墙
  if [[ "${release}" == "centos" ]]; then
    systemctl disable firewalld.service && systemctl stop firewalld.service
  elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
    ufw disable
  fi

  echo_content skyBlue "---> 环境准备完成"
}

setup_docker() {
  mkdir -p /etc/docker
  if [[ ${can_google} == 0 ]]; then
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
    "registry-mirrors":[${docker_mirror}]
}
EOF
  else
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
  systemctl daemon-reload
}

# 安装Docker
install_docker() {
  if [[ ! $(command -v docker) ]]; then
    echo_content green "---> 安装Docker"

    while read -r -p "请输入Docker版本(1/20.10.23 2/latest 默认:1/20.10.23): " dockerVersionNum; do
      if [[ -z "${dockerVersionNum}" || ${dockerVersionNum} == 1 ]]; then
        docker_version=""
        break
      else
        if [[ ${dockerVersionNum} != 2 ]]; then
          echo_content red "不可以输入除1和2之外的其他字符"
        else
          docker_version="20.10.23"
          break
        fi
      fi
    done

    if [[ "${release}" == "centos" ]]; then
      ${package_manager} remove docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine
      ${package_manager} install -y yum-utils
      if [[ ${can_google} == 0 ]]; then
        ${package_manager}-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      else
        ${package_manager}-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi
      ${package_manager} makecache || ${package_manager} makecache fast
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
      ${package_manager} remove docker docker-engine docker.io containerd runc
      ${package_manager} update -y
      ${package_manager} install -y \
        apt-transport-https \
        ca-certificates
      mkdir -p /etc/apt/keyrings
      if [[ ${can_google} == 0 ]]; then
        curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/${release}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] http://mirrors.aliyun.com/docker-ce/linux/${release} \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      else
        curl -fsSL https://download.docker.com/linux/${release}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${release} \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      fi
      ${package_manager} update -y
    fi

    if [[ -z "${docker_version}" ]]; then
      ${package_manager} install -y docker-ce docker-ce-cli containerd.io
    else
      if [[ ${package_manager} == "yum" || ${package_manager} == "dnf" ]]; then
        ${package_manager} install -y docker-ce-${docker_version} docker-ce-cli-${docker_version} containerd.io docker-compose-plugin
      elif [[ ${package_manager} == "apt" || ${package_manager} == "apt-get" ]]; then
        ${package_manager} install -y docker-ce=5:${docker_version}~3-0~${release}-"$(lsb_release -c --short)" docker-ce-cli=5:${docker_version}~3-0~${release}-"$(lsb_release -c --short)" containerd.io docker-compose-plugin
      fi
    fi

    setup_docker

    systemctl enable docker && systemctl restart docker

    if [[ $(command -v docker) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
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

# 安装Containerd
install_containerd() {
  if [[ ! $(command -v containerd) ]]; then
    echo_content green "---> 安装Containerd"

    if [[ "${release}" == "centos" ]]; then
      ${package_manager} install -y yum-utils
      if [[ ${can_google} == 0 ]]; then
        ${package_manager}-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      else
        ${package_manager}-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi
      ${package_manager} makecache || ${package_manager} makecache fast
      ${package_manager} install -y containerd.io
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
      ${package_manager} update -y
      ${package_manager} install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
      mkdir -p /etc/apt/keyrings
      if [[ ${can_google} == 0 ]]; then
        curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/${release}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] http://mirrors.aliyun.com/docker-ce/linux/${release} \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      else
        curl -fsSL https://download.docker.com/linux/${release}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${release} \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      fi
      ${package_manager} update -y
      ${package_manager} install -y containerd.io
    fi

    setup_containerd

    systemctl enable containerd && systemctl restart containerd

    if [[ $(command -v containerd) ]]; then
      echo_content skyBlue "---> Containerd安装完成"
    else
      echo_content red "---> Containerd安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了Containerd"
  fi
}

# 安装运行时
install_runtime() {
  echo_content green "---> 安装运行时"

  install_docker
  if [[ -z "${k8s_version}" ]]; then
    setup_containerd
  fi

  cho_content skyBlue "---> 运行时安装完成"
}

# k8s命令行补全
k8s_bash_completion() {
  ! grep -q kubectl "$HOME/.bashrc" && echo "source /usr/share/bash-completion/bash_completion" >>"$HOME/.bashrc"
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
  if [[ -z "${network}" ]]; then
    echo_content green "---> 安装网络系统"

    while read -r -p "请输入安装哪个网络系统?(1/flannel 2/calico 默认:1/flannel): " networkNum; do
      if [[ -z "${networkNum}" || ${networkNum} == 1 ]]; then
        network="flannel"
        break
      else
        if [[ ${networkNum} != 2 ]]; then
          echo_content red "不可以输入除1和2之外的其他字符"
        else
          network="calico"
          break
        fi
      fi
    done

    if [[ ${network} == "flannel" ]]; then
      wget --no-check-certificate -O /k8sdata/network/flannelkube-flannel.yml ${kube_flannel_url}
      kubectl create -f /k8sdata/network/flannelkube-flannel.yml
    elif [[ ${network} == "calico" ]]; then
      wget --no-check-certificate -O /k8sdata/network/flannelkube-flannel.yml ${calico_url}
      kubectl create -f /k8sdata/network/flannelkube-flannel.yml
    fi

    if [[ "$?" == "0" ]]; then
      echo_content skyBlue "---> 网络系统安装完成"
    else
      echo_content red "---> 网络系统安装失败"
    fi
  else
    echo_content red "---> 未设置网络系统"
  fi
}

# 运行k8s
k8s_run() {
  if [[ ${is_master} == 1 ]]; then
    echo_content green "---> 运行k8s"

    # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
    kubeadm init \
      --apiserver-advertise-address "${public_ip}" \
      --image-repository "${k8s_mirror}" \
      --kubernetes-version "${k8s_version}" \
      --service-cidr=10.96.0.0/12 \
      --pod-network-cidr=10.244.0.0/16 | tee /k8sdata/log/kubeadm-init.log
    if [[ "$?" == "0" ]]; then
      mkdir -p "$HOME"/.kube
      cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
      chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
      echo_content skyBlue "---> k8s运行完成"
    else
      echo_content red "---> k8s运行失败"
      exit 1
    fi
  else
    echo "该节点为从节点, 请手动运行 kubeadm join 命令. 如果你忘记了命令, 可以在主节点上运行 $(
      echo_content yellow "kubeadm token create --print-join-command"
    )"
  fi
}

setup_k8s() {
  cat >/etc/sysconfig/kubelet <<EOF
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
EOF

  crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
  crictl config image-endpoint unix:///var/run/containerd/containerd.sock

  if [[ ! -d /var/lib/kubelet/ ]]; then
    mkdir -p /var/lib/kubelet/
  fi
  if [[ ! -f /var/lib/kubelet/kubeadm-flags.env ]]; then
    cat >/var/lib/kubelet/kubeadm-flags.env <<EOF
KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock"
EOF
  else
    if [[ -z "$(grep "KUBELET_KUBEADM_ARGS" /var/lib/kubelet/kubeadm-flags.env)" ]]; then
      cat >/var/lib/kubelet/kubeadm-flags.env <<EOF
KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock"
EOF
    else
      sed -i '/KUBELET_KUBEADM_ARGS/s/"$/ --container-runtime=remote --container-runtime-endpoint=unix:\/\/\/run\/containerd\/containerd.sock"/' /var/lib/kubelet/kubeadm-flags.env
    fi
  fi
}

# 安装k8s
install_k8s() {
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

    # 设置主机名称
    read -r -p "请输入主机名(默认:k8s-master): " host_name
    [[ -z "${host_name}" ]] && host_name="k8s-master"
    set_hostname host_name

    while read -r -p "请输入K8s版本(1/1.23.17 2/latest 默认:1/1.23.17): " k8sVersionNum; do
      if [[ -z "${k8sVersionNum}" || ${k8sVersionNum} == 1 ]]; then
        k8s_version=""
        break
      else
        if [[ ${k8sVersionNum} != 2 ]]; then
          echo_content red "不可以输入除1和2之外的其他字符"
        else
          k8s_version="1.23.17"
          break
        fi
      fi
    done

    # 安装运行时
    install_runtime

    # 关闭selinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
      setenforce 0 && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    fi

    # 关闭swap分区
    swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab

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

    # https://developer.aliyun.com/mirror/kubernetes
    if [[ "${release}" == "centos" ]]; then
      if [[ ${can_google} == 0 ]]; then
        cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
      else
        cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
      fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
      ${package_manager} install -y apt-transport-https ca-certificates
      if [[ ${can_google} == 0 ]]; then
        curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg
        cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
      else
        curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
        cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main
EOF
      fi
      ${package_manager} update -y
    fi

    if [[ -z "${k8s_version}" ]]; then
      ${package_manager} install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    else
      if [[ ${package_manager} == "yum" || ${package_manager} == "dnf" ]]; then
        ${package_manager} install -y kubelet="${k8s_version}" kubeadm="${k8s_version}" kubectl="${k8s_version}" --disableexcludes=kubernetes
      elif [[ ${package_manager} == "apt" || ${package_manager} == "apt-get" ]]; then
        ${package_manager} install -y kubelet-${k8s_version} kubeadm-${k8s_version} kubectl-${k8s_version}
      fi
    fi

    setup_k8s

    systemctl enable --now kubelet

    if [[ $(command -v kubeadm) ]]; then
      echo_content skyBlue "---> k8s安装完成"
      k8s_run
      k8s_bash_completion
      k8s_network_install
    else
      echo_content red "---> k8s安装失败"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了k8s"
  fi
}

# 重设K8s
reset_k8s() {
  if [[ $(command -v kubeadm) ]]; then
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
  else
    echo_content skyBlue "---> 请先安装K8s"
  fi
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
  echo_content skyBlue "Description: One click install K8s"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-scipt"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 安装K8s"
  echo_content green "=============================================================="
  echo_content yellow "2. 重设K8s"
  read -r -p "请选择:" selectInstall_type
  case ${selectInstall_type} in
  1)
    install_k8s
    ;;
  2)
    reset_k8s
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main
