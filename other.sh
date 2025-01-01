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

detect_cpu() {
    OUT_INFO "[信息] 检测CPU配置..."
    if [ ! -f /proc/cpuinfo ]; then
        OUT_ERROR "[错误] 无法访问 /proc/cpuinfo"
        return 1
    fi

    cpu_cores=$(grep "cpu cores" /proc/cpuinfo | uniq | awk '{print $4}')
    cpu_threads=$(grep -c processor /proc/cpuinfo)
}

detect_memory() {
    OUT_INFO "[信息] 检测内存配置..."
    if [ -f /proc/meminfo ]; then
        total_memory_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    else
        OUT_ERROR "[错误] 无法检测内存大小"
        return 1
    fi
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
}

configure_ntp() {
    OUT_INFO "配置NTP时间同步..."
    cat > /etc/chrony.conf << 'EOF'
server ntp.aliyun.com iburst
server cn.ntp.org.cn iburst
server ntp.tencent.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

    systemctl enable chrony.service
    systemctl restart chrony.service
    OUT_SUCCESS "NTP配置完成"
}

generate_optimization_params() {
    local params=""

    if [ $total_memory_mb -eq 0 ] || [ $cpu_cores -eq 0 ]; then
        params="net.ipv4.tcp_mem = 98304 131072 196608
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 1024"
    else
        params="net.core.netdev_max_backlog = 100000
net.core.somaxconn = 65535"
    fi

    echo "${params}"
}

optimize_system() {
    OUT_INFO "[信息] 优化系统参数..."
    detect_cpu
    detect_memory

    local optimization_params
    optimization_params=$(generate_optimization_params)

    cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr

${optimization_params}
EOF

    sysctl -p
    OUT_SUCCESS "[成功] 系统参数优化完成"
}

main() {
    OUT_INFO "[信息] 开始系统优化..."
    mkdir -p "${BACKUP_DIR}"
    check_root
    check_system
    install_requirements
    configure_ntp
    optimize_system
    OUT_SUCCESS "[成功] 系统优化完成！建议重启系统使所有优化生效。"
}

main
