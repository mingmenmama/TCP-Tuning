#!/bin/bash

# 作者: mingmenmama (修改自原脚本)
# 描述: 一键网络优化脚本 for Linux 系统 (已修复并增强)
# 许可证: MIT

set -euo pipefail

LOG_FILE="/var/log/network_optimization.log"
BACKUP_DIR="/root/system_backup"
SYSCTL_FILE="/etc/sysctl.conf"
DEFAULT_QDISC="cake" # 默认使用 cake

echo "开始网络优化..."
mkdir -p "$BACKUP_DIR"

# 日志函数
log() {
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1" | tee -a "$LOG_FILE"
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

# 检测系统支持的 QDisc 并设置
configure_qdisc() {
    log "检测并配置 QDisc..."
    backup_file /etc/default/grub #备份grub文件
    local qdisc="$DEFAULT_QDISC"
    if ! command -v tc &>/dev/null; then
      apt-get update
      apt-get install -y iproute2
    fi
    if ! tc qdisc add dev lo root cake 2>/dev/null; then
        log "未检测到 Cake QDisc，尝试安装并切换到 FQ QDisc"
        apt-get install -y qdisc-utils
        if ! tc qdisc add dev lo root cake 2>/dev/null;then
            qdisc="fq"
            log "安装cake失败，切换到fq"
        fi
    fi
    if [[ "$qdisc" == "cake" ]];then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.core.default_qdisc=cake"/g' /etc/default/grub
    else
       sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.core.default_qdisc=fq"/g' /etc/default/grub
    fi
    update-grub
    log "设置默认 QDisc 为: $qdisc,并更新grub"
}

# 应用优化参数
apply_optimization() {
    log "应用优化参数..."
    backup_file "$SYSCTL_FILE"

    local params="$1"
    echo "$params" >"$SYSCTL_FILE"

    # 修复 sysctl 语法错误问题：使用 sysctl --system 加载所有配置
    if sysctl --system; then
        log "优化参数已成功加载"
    else
        log "加载优化参数失败，请检查日志 $LOG_FILE 和 /etc/sysctl.conf 语法"
        exit 1
    fi
}

# 重启网络服务
restart_network() {
    log "重启网络服务..."
    if systemctl is-active networking &>/dev/null; then
        systemctl restart networking
        log "使用systemctl重启networking"
    elif /etc/init.d/networking restart &>/dev/null; then
        /etc/init.d/networking restart
        log "使用/etc/init.d/networking重启"
    else
        log "未能检测到可用的网络服务重启命令，请手动重启网络"
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

    # 重启网络服务
    restart_network

    log "网络优化完成！"
}

main "$@"
