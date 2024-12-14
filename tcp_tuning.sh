#!/bin/bash

# 定义函数
detect_supported_qdiscs() {
    local tmp_file=$(mktemp)
    lsmod | grep '[sf]ch\_' > "$tmp_file"
    if [ -s "$tmp_file" ]; then
        cat "$tmp_file" | awk '{print $1}' | sed 's/^sch_//g'
    else
        echo "默认队列调度器"
    fi
    rm -f "$tmp_file"
}

configure_bbr() {
    echo "正在配置 BBR..."
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p > /dev/null
    if grep -q "bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
    echo -e "\e[32mBBR 配置成功。\e[0m"
    else
    echo -e "\e[31m错误：BBR 配置失败。\e[0m"
    fi
}


### 配置模块
tune_tcp_parameters() {
    echo "调整 TCP 参数..."
    for param in \
        "net.ipv4.tcp_no_metrics_save=1" \
        "net.ipv4.tcp_moderate_rcvbuf=1" \
        "net.ipv4.tcp_ecn=1" \
        "net.core.somaxconn=32768" \
        "net.core.netdev_max_backlog=5000" \
        "net.ipv4.tcp_slow_start_after_idle=0" \
        "net.ipv4.tcp_tw_reuse=1" \
        "net.ipv4.tcp_fin_timeout=30" \
        "kernel.sched_migration_cost_ns=5000000" \
        "net.ipv4.ip_forward=1"
    do
        echo "$param" | sudo tee -a /etc/sysctl.conf > /dev/null
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
    echo -e "\e[32m缓冲区 配置成功。\e[0m"
}

set_ulimit() {
    if ! grep -q "root soft nofile" /etc/security/limits.conf
    then
        echo -e "root soft nofile 51200 
        root hard nofile 64000" | sudo tee -a /etc/security/limits.conf > /dev/null
        echo -e "\e[32m已配置文件描述符限制。\e[0m"
    fi
}

# 定义安装函数
install_tcp_tuning() {
    echo "是否立即配置以下模块？"
    PS3="请选择-"
    options=("BBR 设置" "TCP 参数优化" "缓冲区优化" "文件描述符限制" "退出")

    while true; do
        select choice in "${options[@]}"; do
            case $choice in 
                "BBR 设置") configure_bbr;;
                "TCP 参数优化") tune_tcp_parameters;;
                "缓冲区优化") tune_buffer_sizes;;
                "文件描述符限制") set_ulimit;;
                "退出")
                    break 2
                    ;;
                *) echo "无效选项。";;
            esac
            echo "继续？(yes/no,直接回车选Y):"
            read -r ans
            [[ -z "$ans" ]] && ans=y
            if [ "$ans" != "y" ] && [ "$ans" != "yes" ]; then
                break 2
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
    
    # 输出帮助信息
    echo "以下选项供您选择，请键入对应的数字，选择是否更改:"
    echo "1. 配置 BBR"
    echo "2. 优化 TCP 参数"
    echo "3. 调整缓冲区大小"
    echo "4. 设置文件描述符限制"
    echo "5. 退出"
    echo "请输入选项编号:"

    install_tcp_tuning

EOF
