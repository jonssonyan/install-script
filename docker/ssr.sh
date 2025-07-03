#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_var() {
  ECHO_TYPE="echo -e"

  # ShadowsocksR
  SSR_DATA="/jydata/ssr/"
  ssr_ip="jy-ssr"
  ssr_port=80
  ssr_password="123456"
  ssr_method=""
  ssr_protocols=""
  ssr_obfs=""
  methods=(
    none
    aes-256-cfb
    aes-192-cfb
    aes-128-cfb
    aes-256-cfb8
    aes-192-cfb8
    aes-128-cfb8
    aes-256-ctr
    aes-192-ctr
    aes-128-ctr
    chacha20-ietf
    chacha20
    salsa20
    xchacha20
    xsalsa20
    rc4-md5
  )
  # https://github.com/shadowsocksr-rm/shadowsocks-rss/blob/master/ssr.md
  protocols=(
    origin
    verify_deflate
    auth_sha1_v4
    auth_sha1_v4_compatible
    auth_aes128_md5
    auth_aes128_sha1
    auth_chain_a
    auth_chain_b
    auth_chain_c
    auth_chain_d
    auth_chain_e
    auth_chain_f
  )
  obfs=(
    plain
    http_simple
    http_simple_compatible
    http_post
    http_post_compatible
    tls1.2_ticket_auth
    tls1.2_ticket_auth_compatible
    tls1.2_ticket_fastauth
    tls1.2_ticket_fastauth_compatible
  )
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

mkdir_tools() {
  mkdir -p ${SSR_DATA}
}

install_docker() {
  bash <(curl -fsSL https://github.com/jonssonyan/install-script/raw/main/docker/install.sh)
}

install_ssr() {
  if [[ -z $(docker ps -q -f "name=^${ssr_ip}$") ]]; then
    echo_content green "---> 安装ShadowsocksR"

    read -r -p "请输入ShadowsocksR的端口(默认:80): " ssr_port
    [[ -z "${ssr_port}" ]] && ssr_port=80
    read -r -p "请输入ShadowsocksR的密码(默认:123456): " ssr_password
    [[ -z "${ssr_password}" ]] && ssr_password="123456"

    while true; do
      for ((i = 1; i <= ${#methods[@]}; i++)); do
        hint="${methods[$i - 1]}"
        echo "${i}) $(echo_content yellow "${hint}")"
      done
      read -r -p "请选择ShadowsocksR的加密类型(默认:${methods[0]}): " r_methods
      [[ -z "${r_methods}" ]] && r_methods=1
      expr ${r_methods} + 1 &>/dev/null
      if [[ "$?" != "0" ]]; then
        echo_content red "请输入数字"
        continue
      fi
      if [[ "${r_methods}" -lt 1 || "${r_methods}" -gt ${#methods[@]} ]]; then
        echo_content red "输入的数字范围在 1 到 ${#methods[@]}"
        continue
      fi
      ssr_method=${methods[r_methods - 1]}
      break
    done

    while true; do
      for ((i = 1; i <= ${#protocols[@]}; i++)); do
        hint="${protocols[$i - 1]}"
        echo "${i}) $(echo_content yellow "${hint}")"
      done
      read -r -p "请选择ShadowsocksR的协议(默认:${protocols[0]}): " r_protocols
      [[ -z "${r_protocols}" ]] && r_protocols=1
      expr ${r_protocols} + 1 &>/dev/null
      if [[ "$?" != "0" ]]; then
        echo_content red "请输入数字"
        continue
      fi
      if [[ "${r_protocols}" -lt 1 || "${r_protocols}" -gt ${#protocols[@]} ]]; then
        echo_content red "输入的数字范围在 1 到 ${#protocols[@]}"
        continue
      fi
      ssr_protocols=${protocols[r_protocols - 1]}
      break
    done

    while true; do
      for ((i = 1; i <= ${#obfs[@]}; i++)); do
        hint="${obfs[$i - 1]}"
        echo "${i}) $(echo_content yellow "${hint}")"
      done
      read -r -p "请选择ShadowsocksR的混淆方式(默认:${obfs[0]}): " r_obfs
      [[ -z "${r_obfs}" ]] && r_obfs=1
      expr ${r_obfs} + 1 &>/dev/null
      if [[ "$?" != "0" ]]; then
        echo_content red "请输入数字"
        continue
      fi
      if [[ "${r_obfs}" -lt 1 || "${r_obfs}" -gt ${#obfs[@]} ]]; then
        echo_content red "输入的数字范围在 1 到 ${#obfs[@]}"
        continue
      fi
      ssr_obfs=${obfs[r_obfs - 1]}
      break
    done

    cat >${SSR_DATA}config.json <<EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${ssr_port},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${ssr_password}",
    "timeout":120,
    "method":"${ssr_method}",
    "protocol":"${ssr_protocols}",
    "protocol_param":"",
    "obfs":"${ssr_obfs}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":true,
    "workers":1
}
EOF

    docker pull teddysun/shadowsocks-r &&
      docker run -d --name ${ssr_ip} --restart=always \
        --network=host \
        -e TZ=Asia/Shanghai \
        -v ${SSR_DATA}config.json:/etc/shadowsocks-r/config.json \
        teddysun/shadowsocks-r

    if [[ -n $(docker ps -q -f "name=^${ssr_ip}$") ]]; then
      echo_content skyBlue "---> ShadowsocksR安装完成"
      echo_content yellow "---> 端口: ${ssr_port}"
      echo_content yellow "---> 密码(请妥善保存): ${ssr_password}"
      echo_content yellow "---> 加密类型: ${ssr_method}"
      echo_content yellow "---> 协议: ${ssr_protocols}"
      echo_content yellow "---> 混淆方式: ${ssr_obfs}"
    else
      echo_content red "---> ShadowsocksR安装失败或运行异常,请尝试修复或卸载重装"
      exit 1
    fi
  else
    echo_content skyBlue "---> 你已经安装了ShadowsocksR"
  fi
}

cd "$HOME" || exit 0
init_var
mkdir_tools
clear
install_docker
install_ssr
