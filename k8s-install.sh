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

  k8s_version=""
  is_master=1
  k8s_cri_sock="unix:///var/run/containerd/containerd.sock"
  network="flannel"
  network_file="/k8sdata/network/flannelkube-flannel.yml"
  k8s_mirror="registry.cn-hangzhou.aliyuncs.com/google_containers"
  # kube_flannel_url="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  # calico_url="https://docs.projectcalico.org/manifests/calico.yaml"

  # Docker
  docker_mirror='"https://docker.m.daocloud.io","https://atomhub.openatom.cn"'
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

# 比较版本大小
version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

service_exists() {
  systemctl list-units --type=service --all | grep -Fq "$1.service"
}

# 检查系统
check_sys() {
  if [[ $(id -u) != "0" ]]; then
    echo_content red "You must be root to run this script"
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
    echo_content red "This system is not currently supported"
    exit 1
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
    version=$(rpm -q --queryformat '%{VERSION}' centos-release)
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
        ${package_manager}-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      else
        ${package_manager}-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi
      ${package_manager} makecache || ${package_manager} makecache fast
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

  while read -r -p "请选择容器运行时(1/containerd 2/dockershim 默认:1/containerd): " runtimeNum; do
    case ${runtimeNum} in
    "" | 1)
      k8s_cri_sock="unix:///var/run/containerd/containerd.sock"
      install_containerd
      break
      ;;
    2)
      # 自 1.24 版起，Dockershim 已从 Kubernetes 项目中移除
      if version_lt "${k8s_version}" "1.24.0"; then
        k8s_cri_sock="/var/run/dockershim.sock"
        bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
        break
      else
        echo_content red "自1.24版起，Dockershim 已从 Kubernetes 项目中移除，详情：https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/"
      fi
      ;;
    *)
      echo_content red "没有这个选项"
      ;;
    esac
  done

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
      cat >"${network_file}" <<EOF
---
kind: Namespace
apiVersion: v1
metadata:
  name: kube-flannel
  labels:
    pod-security.kubernetes.io/enforce: privileged
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes/status
  verbs:
  - patch
- apiGroups:
  - "networking.k8s.io"
  resources:
  - clustercidrs
  verbs:
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-flannel
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-flannel
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni-plugin
        image: flannel/flannel-cni-plugin:v1.1.2
       #image: rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.2
        command:
        - cp
        args:
        - -f
        - /flannel
        - /opt/cni/bin/flannel
        volumeMounts:
        - name: cni-plugin
          mountPath: /opt/cni/bin
      - name: install-cni
        image: flannel/flannel:v0.21.3
       #image: rancher/mirrored-flannelcni-flannel:v0.21.3
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: flannel/flannel:v0.21.3
       #image: rancher/mirrored-flannelcni-flannel:v0.21.3
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --iface=enp0s8
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: EVENT_QUEUE_DEPTH
          value: "5000"
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
        - name: xtables-lock
          mountPath: /run/xtables.lock
      volumes:
      - name: run
        hostPath:
          path: /run/flannel
      - name: cni-plugin
        hostPath:
          path: /opt/cni/bin
      - name: cni
        hostPath:
          path: /etc/cni/net.d
      - name: flannel-cfg
        configMap:
          name: kube-flannel-cfg
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
EOF
      # wget --no-check-certificate -O "${network_file}" ${kube_flannel_url}
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

    while read -r -p "请输入 K8s 版本(1/latest 2/1.23.17 默认:1/latest): " k8sVersionNum; do
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
    echo "k8s_version=${k8s_version}" >>${k8s_lock_file}

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

    # https://developer.aliyun.com/mirror/kubernete
    # k8s version >= v1.24.0软件包仓库变更
    if version_lt "${k8s_version}" "1.24.0"; then
      if [[ "${release}" == "centos" ]]; then
        if [[ ${can_google} == 0 ]]; then
          cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-$(arch)/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
        else
          cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-$(arch)
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
    else
      echo_content red "k8s version >= v1.24.0"
      exit 1
    fi

    if [[ -z "${k8s_version}" ]]; then
      ${package_manager} install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    else
      if [[ ${package_manager} == "yum" || ${package_manager} == "dnf" ]]; then
        ${package_manager} install -y kubelet-"${k8s_version}" kubeadm-"${k8s_version}" kubectl-"${k8s_version}" --disableexcludes=kubernetes
      elif [[ ${package_manager} == "apt" || ${package_manager} == "apt-get" ]]; then
        ${package_manager} install -y kubelet="${k8s_version}" kubeadm="${k8s_version}" kubectl="${k8s_version}"
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

      # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
      kubeadm init \
        --apiserver-advertise-address="${public_ip}" \
        --image-repository="${k8s_mirror}" \
        --kubernetes-version="${k8s_version}" \
        --service-cidr=10.96.0.0/12 \
        --pod-network-cidr=10.244.0.0/16 \
        --cri-socket="${k8s_cri_sock}" | tee /k8sdata/log/kubeadm-init.log

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
  echo_content red "\n=============================================================="
  echo_content skyBlue "Recommended OS: CentOS 8+/Ubuntu 20+/Debian 11+"
  echo_content skyBlue "Description: Install K8s"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/jonssonyan/install-script"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 安装 K8s"
  echo_content yellow "2. 运行 K8s"
  echo_content green "=============================================================="
  echo_content yellow "3. 重设 K8s"
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
