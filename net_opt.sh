#!/bin/bash

# 作者: mingmenmama
# 描述: 一键网络优化脚本 for Linux 系统
# 许可证: MIT

set -euo pipefail

LOG_FILE="/var/log/network_optimization.log"
BACKUP_DIR="/root/system_backup"
SYSCTL_FILE="/etc/sysctl.conf"
DEFAULT_QDISC="fq"

echo "开始网络优化..."
mkdir -p "$BACKUP_DIR"

# 日志函数
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# 备份文件
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/$(basename "$file").bak.$(date +%F-%H%M%S)"
        log "已备份 $file 到 $BACKUP_DIR"
    fi
}

# 检测硬件配置
detect_hardware() {
    log "检测硬件配置..."
    local total_memory_mb=0
    local cpu_cores=0

    if [ -f /proc/meminfo ]; then
        total_memory_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
        log "内存大小: ${total_memory_mb}MB"
    else
        log "无法检测内存信息"
    fi

    if [ -f /proc/cpuinfo ]; then
        cpu_cores=$(grep -m1 "cpu cores" /proc/cpuinfo | awk '{print $4}')
        log "CPU核心数: ${cpu_cores}"
    else
        log "无法检测CPU信息"
    fi

    echo "$total_memory_mb $cpu_cores"
}

# 动态生成网络优化参数
generate_dynamic_params() {
    local total_memory_mb=$1
    local cpu_cores=$2
    log "根据硬件生成动态网络优化参数..."

    local params="net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432"

    if [ "$cpu_cores" -le 2 ]; then
        params="${params}
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 2048"
    else
        params="${params}
net.core.netdev_max_backlog = 30000
net.core.somaxconn = 8192"
    fi

    echo "$params"
}

# 固定生成网络优化参数
generate_fixed_params() {
    log "生成固定网络优化参数..."
    cat <<EOF
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.netdev_max_backlog = 10000
net.core.somaxconn = 2048
EOF
}

# 检测系统支持的 QDisc
detect_qdisc_support() {
    log "检测当前系统支持的 QDisc..."
    if tc qdisc add dev lo root cake 2>/dev/null; then
        log "检测到支持 Cake QDisc"
        tc qdisc del dev lo root cake
        echo "cake"
    else
        log "未检测到 Cake QDisc，切换到 FQ QDisc"
        echo "fq"
    fi
}

# 配置 QDisc
configure_qdisc() {
    local qdisc
    qdisc=$(detect_qdisc_support)

    log "设置默认 QDisc 为: $qdisc"
    echo "net.core.default_qdisc = $qdisc" >>"$SYSCTL_FILE"

    if [ "$qdisc" == "cake" ]; then
        log "推荐命令: ip link set dev <接口名> qdisc cake"
    else
        log "推荐命令: ip link set dev <接口名> qdisc fq"
    fi
}

# 应用优化参数
apply_optimization() {
    log "应用优化参数..."
    backup_file "$SYSCTL_FILE"

    local params="$1"
    echo "$params" >"$SYSCTL_FILE"

    if sysctl -p; then
        log "优化参数已成功加载"
    else
        log "加载优化参数失败，请检查日志 $LOG_FILE"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --mode dynamic    根据硬件动态生成网络优化参数（默认）
  --mode fixed      使用固定网络优化参数
  --help            显示此帮助信息
EOF
    exit 0
}

# 解析命令行参数
parse_args() {
    local mode="dynamic"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --mode)
            if [[ "$2" == "dynamic" || "$2" == "fixed" ]]; then
                mode="$2"
                shift 2
            else
                log "无效模式: $2"
                show_help
            fi
            ;;
        --help)
            show_help
            ;;
        *)
            log "未知选项: $1"
            show_help
            ;;
        esac
    done

    echo "$mode"
}

# 主函数
main() {
    log "开始优化流程..."

    # 解析命令行参数
    local mode
    mode=$(parse_args "$@")

    # 检测硬件配置
    local total_memory_mb
    local cpu_cores
    read total_memory_mb cpu_cores < <(detect_hardware)

    # 生成优化参数
    local optimization_params
    if [ "$mode" == "dynamic" ]; then
        optimization_params=$(generate_dynamic_params "$total_memory_mb" "$cpu_cores")
    else
        optimization_params=$(generate_fixed_params)
    fi

    # 应用优化参数
    apply_optimization "$optimization_params"

    # 配置 QDisc
    configure_qdisc

    log "网络优化完成！建议重启系统以确保所有设置生效。"
}

main "$@"
