#!/bin/bash
# tcp_tuning.sh - 一键TCP调优脚本（增强版）
# 支持调度器参数化选项，自动检测支持的调度器，并给出建议选择

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

# 日志记录
function log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/tcp_tuning.log
}

# 检查 BBR 支持
function check_bbr_support() {
    local bbr_version=$(sysctl net.ipv4.tcp_available_congestion_control | grep -oE 'bbr[0-9]?')
    log_message "Checking BBR version: ${bbr_version:?:BBR not found}."
    [[ -n $bbr_version ]] && return 0
    log_message "Error: BBR v3 is not supported by this kernel."
    return 1
}

# 检测系统支持的调度器
declare -A SUPPORTED_QDISC

function detect_supported_qdiscs() {
    local supported_list=($(ip l | grep 'qdisc' | grep -oE 'qdisc [a-z_]+'))
    declare -A SUPPORTED_QDISC
    for qdisc in "${supported_list[@]}"; do
        case $qdisc in 
            *fq*) SUPPORTED_QDISC[fq]=${QDISC_OPTIONS[fq]};;
            *cake*) SUPPORTED_QDISC[cake]=${QDISC_OPTIONS[cake]};;
            *pfifo_fast*) SUPPORTED_QDISC[pfifo_fast]=${QDISC_OPTIONS[pfifo_fast]};;
            *sfq*) SUPPORTED_QDISC[sfq]=${QDISC_OPTIONS[sfq]};;
            *htb*) SUPPORTED_QDISC[htb]=${QDISC_OPTIONS[htb]};;
            *fq_codel*) SUPPORTED_QDISC[fq_codel]=${QDISC_OPTIONS[fq_codel]};;
            *noqueue*) SUPPORTED_QDISC[noqueue]=${QDISC_OPTIONS[noqueue]};;
            *bfifo*) SUPPORTED_QDISC[bfifo]=${QDISC_OPTIONS[bfifo]};;
        esac
    done

    if [[ ${#SUPPORTED_QDISC[@]} -eq 0 ]]; then
        log_message "No supported queue disciplines found. Please make sure your kernel supports TCP tuning."
    else
        log_message "Found ${#SUPPORTED_QDISC[@]} supported queue disciplines."
        for supported_key in "${!SUPPORTED_QDISC[@]}"; do
            log_message "Supported: $supported_key - ${SUPPORTED_QDISC[$supported_key]}"
        done
    fi

    declare -p SUPPORTED_QDISC
}

# 函数：显示可用调度器和说明
function show_qdisc_options() {
    echo "Available queue disciplines:"
    for qdisc in "${!QDISC_OPTIONS[@]}"; do
        echo "  $qdisc - ${QDISC_OPTIONS[$qdisc]}"
    done
    echo ""
}

# 函数：显示帮助信息
function show_help() {
    echo "Usage: sudo ./tcp_tuning.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --qdisc <fq|cake|pfifo_fast|sfq|htb|fq_codel|noqueue|bfifo>"
    echo "            Set queue discipline (default: fq)"
    echo "  --help    Show this help message"
    echo "  --undo    Undo the last configuration change"
    echo ""
    echo "Example: sudo ./tcp_tuning.sh --qdisc cake"
    exit 0
}

# 备份现有配置
function backup_sysctl() {
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    log_message "Backing up sysctl configuration..."
}

# 回滚配置更改
function undo_changes() {
    if [[ -f "/etc/sysctl.conf.bak" ]]; then
        mv -f /etc/sysctl.conf.bak /etc/sysctl.conf
        log_message "Reverted sysctl configuration to previous state."
    else
        log_message "No previous backup found."
        echo "No previous backup found."
        return 1
    fi
    if ! sysctl -p >/dev/null 2>&1; then
        log_message "Failed to apply configuration revert."
    else
        log_message "Successfully reverted configuration."
    fi
    exit 0
}

# 模块1: 检测并配置BBR
function configure_bbr() {
    check_bbr_support || return 1

    log_message "Configuring BBR and $DEFAULT_QDISC..."

    cat <<EOF >>/etc/sysctl.conf

# BBR v3 配置
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = $DEFAULT_QDISC
EOF

    if [[ $? -ne 0 ]]; then
        log_message "Failed to configure BBR."
        return 1
    fi

    return 0
}

# 模块2: 调整TCP基本参数
function configure_tcp_params() {
    log_message "Configuring TCP parameters..."

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

    if [[ $? -ne 0 ]]; then
        log_message "Failed to configure TCP parameters."
        return 1
    fi

    return 0
}

# 模块3: 配置缓冲区
function configure_buffers() {
    log_message "Configuring TCP buffers..."

    cat <<EOF >>/etc/sysctl.conf

# 缓冲区大小调优
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
EOF

    if [[ $? -ne 0 ]]; then
        log_message "Failed to configure TCP buffers."
        return 1
    fi

    return 0
}

# 模块4: 提升文件描述符限制
function configure_file_descriptors() {
    log_message "Configuring file descriptor limits..."

    echo "* soft nofile 2097152" >> /etc/security/limits toutes file possible conflict et donc error aucune nouvel ajout.
    echo "* hard nofile 2097152" >> /etc/security/limits.conf
    echo "root soft nofile 2097152" >> /etc/security/limits.conf
    echo "root hard nofile 2097152" >> /etc/security/limits.conf

    if [[ $? -ne 0 ]]; then
        log_message "Failed to configure file descriptors."
        return 1
    fi

    return 0
}

# 模块5: 应用配置
function apply_sysctl() {
    log_message "Applying sysctl configuration..."
    if ! sysctl -p >/dev/null 2>&1; then
        log_message "Configuration error when applying changes."
        return 1
    fi

    return 0
}

# 提示用户选择
function prompt_user() {
    echo -n "Choose the queue discipline or type 'help' for options: "
    read -r user_input
    case $user_input in
        help)
            show_help
            ;;
        *)  # 用户输入无效选项
            if [[ -n "${SUPPORTED_QDISC[$user_input]}" ]]; then
                DEFAULT_QDISC=$user_input
            else
                echo "Invalid qdisc option: $user_input"
                show_qdisc_options
                prompt_user
            fi
            ;;
    esac
}

# 自动检测支持的调度器
detect_supported_qdiscs

# 解析参数
DEFAULT_QDISC="fq"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --qdisc)
            if [[ -n "${SUPPORTED_QDISC[$2]}" ]]; then
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
        --undo)
            undo_changes
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

echo "Selected queue discipline: $DEFAULT_QDISC - ${QDISC_OPTIONS[$DEFAULT_QDISC]}"

# 确保用户输入有效选项
if [[ -z "$DEFAULT_QDISC" ]]; then
    prompt_user
fi

# 主逻辑开始
backup_sysctl

declare -f configure_bbr configure_tcp_params configure_buffers configure_file_descriptors apply_sysctl

# 提示用户执行哪个模块
for func in "${!SUPPORTED_QDISC[@]}"; do
    read -p "Would you like to $func? [y/N]: " exec_func
    if [[ $exec_func =~ ^[Yy]$ ]]; then
        $func
    else
        log_message "Skipped $func."
    fi
done

apply_sysctl

echo "TCP tuning applied successfully!"
log_message "All configurations applied successfully!"
