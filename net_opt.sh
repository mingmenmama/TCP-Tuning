#!/bin/bash

# 作者: mingmenmama
# 描述: 一键网络优化脚本 for Linux 系统
# 许可证: MIT

set -euo pipefail

LOG_FILE="/var/log/network_optimization.log"
BACKUP_DIR="/root/system_backup"
SYSCTL_FILE="/etc/sysctl.conf"

echo "开始网络优化..."
mkdir -p "$BACKUP_DIR"

# 日志函数
log() {
    echo "$(date +%Y-%m-%d_%H:%M:%S) $1" | tee -a "$LOG_FILE"
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

# 检测系统支持的 QDisc (不再使用，因为重启网络接口后需要重新配置)
# detect_qdisc_support() {
#     log "检测当前系统支持的 QDisc..."
#     if tc qdisc add dev lo root cake 2>/dev/null; then
#         log "检测到支持 Cake QDisc"
#         tc qdisc del dev lo root cake
#         echo "cake"
#     else
#         log "未检测到 Cake QDisc，切换到 FQ QDisc"
#         echo "fq"
#     fi
# }

# 配置 QDisc (移到重启网络接口之后)
configure_qdisc() {
  local interface=$1
  local qdisc="fq" # 默认使用fq，可以根据需要修改
  log "设置接口 $interface 的 QDisc 为: $qdisc"
  tc qdisc del dev "$interface" root 2>/dev/null #删除可能已存在的qdisc
  tc qdisc add dev "$interface" root "$qdisc"
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

# 重启网络接口
restart_network() {
    log "重启网络接口..."
    local interface
    # 自动检测网络接口，排除lo回环接口
    interface=$(ip -4 route get 1 | awk '{print $5}' | grep -v lo)
    if [ -z "$interface" ]; then
        log "未找到活动的网络接口，请手动配置。"
        return 1 # 返回1表示失败
    fi
    log "检测到的网络接口：$interface"

    if systemctl is-active networking.service &>/dev/null; then #检测systemd
      systemctl restart networking.service
    elif /etc/init.d/networking status &>/dev/null; then #检测init.d
      /etc/init.d/networking restart
    else
      log "未检测到systemd或init.d网络服务，请手动重启网络"
      return 1
    fi

    sleep 2 # 等待网络重启完成

    configure_qdisc "$interface" #重启后配置qdisc

    log "网络接口已重启。"
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

    # 重启网络接口并配置QDisc
    if ! restart_network; then
        log "网络重启或QDisc配置失败，请检查日志。"
    fi

    log "网络优化完成！"
}

main "$@"
