#!/bin/bash
# tcp_tuning.sh - 一键TCP调优脚本（改进版）
# 支持调度器参数化选项，增加其他调度器选项及说明

# 检查是否为root用户运行
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# 可用调度器选项及说明
declare -A QDISC_OPTIONS=(
    ["fq"]="Fair Queuing (fq): 默认调度器，平衡带宽分配，适合大多数场景。"
    ["cake"]="Cake: 针对家庭网络设计，优化低延迟和公平性，支持高吞吐量场景。"
    ["pfifo_fast"]="PFIFO_FAST: 适合低流量环境的简单队列。"
    ["sfq"]="Stochastic Fairness Queuing (sfq): 提供流量公平性，但不适合高负载场景。"
    ["htb"]="Hierarchical Token Bucket (htb): 提供流量整形功能，适用于复杂的流量管理。"
    ["fq_codel"]="FQ-CoDel: 减少队列延迟，适合解决缓冲膨胀问题。"
    ["noqueue"]="NoQueue: 禁用队列调度，适用于回环接口或特殊场景。"
    ["bfifo"]="BFIFO: 基于简单FIFO队列，适合低负载或嵌入式设备。"
)

# 显示可用调度器和说明
function show_qdisc_options() {
    echo "Available queue disciplines:"
    for qdisc in "${!QDISC_OPTIONS[@]}"; do
        echo "  $qdisc - ${QDISC_OPTIONS[$qdisc]}"
    done
    echo ""
}

# 显示帮助信息
function show_help() {
    echo "Usage: sudo ./tcp_tuning.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --qdisc <fq|cake|pfifo_fast|sfq|htb|fq_codel|noqueue|bfifo>"
    echo "                      Set queue discipline (default: fq)"
    echo "  --help              Show this help message"
    echo ""
    echo "Example: sudo ./tcp_tuning.sh --qdisc cake"
    exit 0
}

# 解析参数
DEFAULT_QDISC="fq"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --qdisc)
            if [[ -n "${QDISC_OPTIONS[$2]}" ]]; then
                DEFAULT_QDISC="$2"
                shift 2
            else
                echo "Invalid qdisc option: $2"
                show_qdisc_options
                exit 1
            fi
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

echo "Selected queue discipline: $DEFAULT_QDISC - ${QDISC_OPTIONS[$DEFAULT_QDISC]}"

# 模块1: 检测并配置BBR
function configure_bbr() {
    echo "Checking BBR version..."

    # 检查BBR支持情况
    local bbr_version
    bbr_version=$(sysctl net.ipv4.tcp_available_congestion_control | grep -oE 'bbr[0-9]?')

    if [[ $bbr_version != "bbr3" ]]; then
        echo "Error: BBR v3 is required for this script."
        echo "Current BBR version detected: ${bbr_version:-None}"
        exit 1
    fi

    echo "BBR v3 detected. Configuring BBR and $DEFAULT_QDISC..."

    # 配置BBR和调度器
    cat <<EOF >>/etc/sysctl.conf

# BBR v3 配置
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = $DEFAULT_QDISC
EOF
}

# 模块2: 调整TCP基本参数
function configure_tcp_params() {
    echo "Configuring TCP parameters..."
    cat <<EOF >>/etc/sysctl.conf

# TCP基本参数调优
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
EOF
}

# 模块3: 配置缓冲区
function configure_buffers() {
    echo "Configuring TCP buffers..."
    cat <<EOF >>/etc/sysctl.conf

# 缓冲区大小调优
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
EOF
}

# 模块4: 提升文件描述符限制
function configure_file_descriptors() {
    echo "Configuring file descriptor limits..."
    echo "* soft nofile 2097152" >> /etc/security/limits.conf
    echo "* hard nofile 2097152" >> /etc/security/limits.conf
    echo "root soft nofile 2097152" >> /etc/security/limits.conf
    echo "root hard nofile 2097152" >> /etc/security/limits.conf
}

# 应用配置
function apply_sysctl() {
    echo "Applying sysctl configuration..."
    sysctl -p
}

# 执行模块
configure_bbr
configure_tcp_params
configure_buffers
configure_file_descriptors
apply_sysctl

# 提示成功信息
echo "TCP tuning applied successfully!"
