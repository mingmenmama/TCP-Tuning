#!/bin/bash

# 作者: Code Companion
# 许可证: MIT
# 描述: 一键网络优化脚本 for Linux 系统

sysctl_file='/etc/sysctl.conf'

echo "开始应用网络优化参数..."

function apply_param {
    echo "正在应用参数: $1 = $2"
    echo "$1 = $2" >> $sysctl_file
}

# 以下是一个参数调整的函数示例:
# 参数说明: $1是参数标题, $2是参数简述, $3是参数名, $4是参数值, $5是可选地标注
function apply_params {
    echo 
    echo "正在优化 ${1}:"
    echo "${2}"
    echo 
    apply_param "$3" "$4"
}

# 批量应用参数配置
apply_params "监听套接字队列" "提高最大监听队列深度，增强并发连接能力" "net.core.somaxconn" "4096"
apply_params "同步设置队列" "设置高并发的 SYN 请求队列" "net.ipv4.tcp_max_syn_backlog" "4096"

# TCP 性能和安全性相关的参数
apply_params "SYN cookies" "在 SYN 攻击时保持网络服务可用性" "net.ipv4.tcp_syncookies" "1"
apply_params "TCP 时间戳" "增强网络安全并启用精细化的 rtt 测量" "net.ipv4.tcp_timestamps" "1"
apply_params "time-wait 回收" "不推荐启用旧版本内核中的这个参数" "net.ipv4.tcp_tw_recycle" "0"
apply_params "time-wait 复用" "不推荐启用旧版本内核中的这个参数" "net.ipv4.tcp_tw_reuse" "0"
apply_params "TCP keep-alive 时间" "较长时间无数据的连接会自动关闭" "net.ipv4.tcp_keepalive_time" "7200"
apply_params "TCP 最终状态超时" "降低连接在最后状态停留的时间，提高资源利用效率" "net.ipv4.tcp_fin_timeout" "30"
apply_params "系统自动重启" "设置为-1，不自动重启，但根据具体要求设置时间（秒）" "kernel.panic" "-1"
apply_params "交换内存使用" "降低系统使用交换空间的频率" "vm.swappiness" "0"

# 一些不推荐开启的参数
apply_params "TCP 不保存指标" "减少资源占用，适用于高吞吐量服务器" "net.ipv4.tcp_no_metrics_save" "1"
apply_params "显式拥塞通知" "关闭可能增加网络复杂性的 ECN 功能" "net.ipv4.tcp_ecn" "0"
apply_params "快速重传超时" "关闭旧版本内核时可能不会提供任何优势的 F-RTO" "net.ipv4.tcp_frto" "0"

# TCP 数据传输的优化
apply_params "MTU 探测" "关闭，以简化网络栈" "net.ipv4.tcp_mtu_probing" "0"
apply_params "协议补丁1337" "关闭因可能带来不必要的优化而设置为0" "net.ipv4.tcp_rfc1337" "0"
apply_params "TCP 分解段最大数量" "如过高，可能会影响稳定性，设置上限为256" "net.ipv4.tcp_max_tso_segs" "256"
apply_params "TCP 分解段最小数量" "确保分段最小化，优化网络资源使用" "net.ipv4.tcp_min_tso_segs" "2"

# 高速网络传输相关的缓存大小调整
apply_params "TCP SACK(F)" "启用选择性确认和前向确认，改善网络稳定性" "net.ipv4.tcp_sack" "1" "[F] "
apply_params "TCP 窗口缩放" "支持大容量数据传输" "net.ipv4.tcp_window_scaling" "1"
apply_params "自动调整接受缓冲区" "维持接受窗口大小，防止缓冲区溢出" "net.ipv4.tcp_moderate_rcvbuf" "1"
apply_params "接受缓冲区最大值" "设置 max 大小以处理更高的网络吞吐量" "net.core.rmem_max" "33554432"
apply_params "发送缓冲区最大值" "设置 max 大小以处理更高的网络吞吐量" "net.core.wmem_max" "33554432"
apply_params "网络设备背压队列长度" "减少网络接口上的数据包聚积" "net.core.netdev_max_backlog" "5000"

# 使用 Cake QDisc
# 注意: 不同Linux发行版可能会有不同的方法加载 Cake QDisc
# 在某些情况下可能需要先安装相应的模块或包
apply_params "设置 QDisc" "使用 Cake 作为默认队列管理器，提供公平性和高效的网络带宽管理" "net.core.default_qdisc" "cake"

# 加载新设置
echo "相关内核参数已更新，当前加载中..."
sysctl -p $sysctl_file && {
    echo "系统设置已成功重载, 优化完成。"
} || {
    echo "系统设置重载失败, 请查看详细信息。"
    exit 1
}

# 如果 Cake 需要作为接口的默认 QDisc，使用如下命令(执行后需要网络重启)
ip link set dev eth0 qdisc cake

# 如果QDisc变更成功，重启网络服务以生效
echo "网络优化完成，现在请您手动重启网络服务以加载新QDisc设置。"
