#!/bin/bash

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

# 应用优化参数
apply_optimization() {
    log "应用优化参数..."
    backup_file "$SYSCTL_FILE"

    local params="$1"
    if [ -z "$params" ]; then
        log "生成的参数为空，跳过优化"
        exit 1
    fi

    echo "$params" >"$SYSCTL_FILE"

    if sysctl -p; then
        log "优化参数已成功加载"
    else
        log "加载优化参数失败，请检查日志 $LOG_FILE"
        exit 1
    fi
}

# 配置 QDisc
configure_qdisc() {
    log "检测当前系统支持的 QDisc..."
    local qdisc
    if tc qdisc add dev lo root cake 2>/dev/null; then
        log "检测到支持 Cake QDisc"
        tc qdisc del dev lo root cake
        qdisc="cake"
    else
        log "未检测到 Cake QDisc，切换到 FQ QDisc"
        qdisc="fq"
    fi

    if [ -z "$qdisc" ] || ! [[ "$qdisc" =~ ^(fq|cake)$ ]]; then
        log "无效的 QDisc 配置: $qdisc"
        exit 1
    fi

    log "设置默认 QDisc 为: $qdisc"
    echo "net.core.default_qdisc = $qdisc" >>"$SYSCTL_FILE"
}

# 主函数
main() {
    log "开始优化流程..."

    # 检测硬件配置
    read total_memory_mb cpu_cores < <(detect_hardware || echo "0 0")
    if [ "$total_memory_mb" -eq 0 ] || [ "$cpu_cores" -eq 0 ]; then
        log "无法检测硬件配置，使用默认值"
        total_memory_mb=1024
        cpu_cores=1
    fi

    # 生成优化参数
    local optimization_params
    optimization_params=$(generate_fixed_params)

    # 应用优化参数
    apply_optimization "$optimization_params"

    # 配置 QDisc
    configure_qdisc

    log "网络优化完成！建议重启系统以确保所有设置生效。"
}

main "$@"
