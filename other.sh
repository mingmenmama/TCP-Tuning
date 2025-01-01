#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/server-optimization.log"
BACKUP_DIR="/root/system_backup"
declare release=""
declare -i total_memory_mb=0
declare -i cpu_cores=0
declare -i cpu_threads=0

CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CCYAN="${CSI}1;36m"

OUT_ALERT() { echo -e "${CYELLOW}$1${CEND}" | tee -a "${LOG_FILE}"; }
OUT_ERROR() { echo -e "${CRED}$1${CEND}" | tee -a "${LOG_FILE}"; }
OUT_INFO() { echo -e "${CCYAN}$1${CEND}" | tee -a "${LOG_FILE}"; }
OUT_SUCCESS() { echo -e "${CGREEN}$1${CEND}" | tee -a "${LOG_FILE}"; }

check_root() {
    if [ $EUID -ne 0 ]; then
        OUT_ERROR "[错误] 此脚本需要root权限运行"
        return 1
    fi
}

check_system() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if echo "${ID}" | grep -qi "debian"; then
            release="debian"
            return 0
        elif echo "${ID}" | grep -qi "ubuntu"; then
            release="ubuntu"
            return 0
        elif echo "${ID}" | grep -qi "centos|rhel|fedora"; then
            release="centos"
            return 0
        fi
    fi

    if [ -f /etc/redhat-release ]; then
        release="centos"
        return 0
    fi

    if [ -f /etc/debian_version ]; then
        release="debian"
        return 0
    fi

    OUT_ERROR "[错误] 不支持的操作系统！"
    return 1
}

install_requirements() {
    OUT_INFO "[信息] 安装必要工具..."
    if [ "${release}" = "centos" ]; then
        yum install -y epel-release
        yum install -y wget curl chrony
    else
        apt-get update
        apt-get install -y wget curl chrony
    fi
    OUT_SUCCESS "[成功] 工具安装完成"
    return 0
}

configure_dns() {
    OUT_INFO "配置系统DNS..."

    if [ ! -d "${BACKUP_DIR}" ]; then
        mkdir -p "${BACKUP_DIR}"
    fi

    if [ -L /etc/resolv.conf ]; then
        rm -f /etc/resolv.conf
    fi

    if [ -f /etc/resolv.conf ]; then
        chattr -i /etc/resolv.conf 2>/dev/null || true
        mv /etc/resolv.conf "${BACKUP_DIR}/resolv.conf.bak"
    fi

    cat > /etc/resolv.conf << 'EOF'
options timeout:2 attempts:3 rotate
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
nameserver 208.67.222.222
EOF

    chattr +i /etc/resolv.conf
    OUT_SUCCESS "DNS配置完成"
    return 0
}

configure_ntp() {
    OUT_INFO "配置NTP时间同步..."
    NTP_SERVICE="chrony.service"

    cat > /etc/chrony.conf << 'EOF'
pool pool.ntp.org iburst
pool time.google.com iburst
pool time.cloudflare.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

    systemctl enable "${NTP_SERVICE}"
    systemctl restart "${NTP_SERVICE}"
    OUT_SUCCESS "NTP配置完成"
    return 0
}

generate_optimization_params() {
    echo "net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr"
    return 0
}

optimize_system() {
    OUT_INFO "[信息] 优化系统参数..."
    if [ -f /etc/sysctl.conf ] && cp -f /etc/sysctl.conf "${BACKUP_DIR}/sysctl.conf.bak"; then
        local optimization_params
        optimization_params=$(generate_optimization_params)
        cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 20
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_tw_buckets = 550000
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
${optimization_params}
EOF
        sysctl -p
        OUT_SUCCESS "[成功] 系统参数优化完成"
    else
        OUT_ERROR "[错误] 无法备份或写入sysctl配置"
        return 1
    fi
}

main() {
    OUT_INFO "[信息] 开始系统优化..."
    mkdir -p "${BACKUP_DIR}"
    check_root || exit 1
    check_system || exit 1
    install_requirements || exit 1
    configure_dns || exit 1
    configure_ntp || exit 1
    optimize_system || exit 1
    OUT_SUCCESS "[成功] 系统优化完成！"
    OUT_INFO "[信息] 建议重启系统使所有优化生效"
}

main
