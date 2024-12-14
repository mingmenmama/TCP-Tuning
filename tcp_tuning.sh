#!/bin/bash

# 定义函数
configure_bbr() {
    echo "正在配置 BBR..."
    echo "net.core.default_qdisc=cake" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p > /dev/null
    echo -e "\e[32mBBR 和 cake 配置成功。\e[0m"
}

### 配置模块
tune_tcp_parameters() {
    echo "调整 TCP 参数..."
    local params_list=(
        "net.ipv4.tcp_no_metrics_save=1"
        "net.ipv4.tcp_moderate_rcvbuf=1"
        "net.ipv4.tcp_ecn=1"
        "net.core.somaxconn=32768"
        "net.core.netdev_max_backlog=5000"
        "net.ipv4.tcp_slow_start_after_idle=0"
        "net.ipv4.tcp_tw_reuse=1"
        "net.ipv4.tcp_fin_timeout=30"
        "kernel.sched_migration_cost_ns=5000000"
        "net.ipv4.ip_forward=1"
    )
    for param in "${params_list[@]}"; do
        echo "$param" | sudo tee -a /etc/sysctl.conf > /dev/null || return 1
    done
    echo 1 | sudo tee /proc/sys/net/ipv4/conf/all/forwarding > /dev/null
    sudo sysctl -p > /dev/null
    echo -e "\e[32mTCP 参数配置成功。\e[0m"
}

tune_buffer_sizes() {
    echo "调整缓冲区..."
    echo "net.core.rmem_max=16777216" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.core.wmem_max=16777216" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_rmem=4096 87380 16777216" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_wmem=4096 65536 16777216" | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p > /dev/null
    echo -e "\e[32m缓冲区配置成功。\e[0m"
}

set_ulimit() {
    if ! grep -q "root soft nofile" /etc/security/limits.conf; then
        echo -e "root soft nofile 51200\n\nroot hard nofile 64000" | sudo tee -a /etc/security/limits.conf > /dev/null
        echo -e "\e[32m已配置文件描述符限制。\e[0m"
    fi
}

# 定义安装函数
install_tcp_tuning() {
    echo "是否立即配置以下模块？"
    PS3="请选择-"
    local options=("BBR 设置" "TCP 参数优化" "缓冲区优化" "文件描述符限制" "退出")

    while true; do
        select choice in "${options[@]}"; do
            case $choice in 
                "BBR 设置") configure_bbr || return 1;;
                "TCP 参数优化") tune_tcp_parameters || return 1;;
                "缓冲区优化") tune_buffer_sizes || return 1;;
                "文件描述符限制") set_ulimit || return 1;;
                "退出")
                    return 0
                    ;;
                *) echo "无效选项。";;
            esac
            echo "继续？(yes/no,直接回车选Y):"
            read -r ans
            [[ -z "$ans" ]] && ans=y
            if [ "$ans" != "y" ] && [ "$ans" != "yes" ]; then
                    return 0
            fi
        done
    done
}

# 脚本入口,用户选择执行
sudo bash << EOF
    echo "正在安装 TCP 调优脚本..."
    chmod +x tcp_tuning.sh
    mv tcp_tuning.sh /usr/local/sbin/
    
    echo -e "\e[32m安装成功！脚本位于 /usr/local/sbin/tcp_tuning.sh\e[0m"
    install_tcp_tuning
    echo -e "\e[32m配置完成，记得使用 'sysctl -p' 以应用更改。\e[0m"
EOF
