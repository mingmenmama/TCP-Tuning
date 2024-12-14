# TCP Tuning🏃🌿

这是一个用 Bash 设计的脚本，用于通过配置 BBR 和调度器来优化 TCP，以及调整其他系统参数。

## 概述

此脚本提供了一套系统的 TCP 和网络调优功能，如下：

- 自动检测并配置 BBR (Bottleneck Bandwidth and RTT) 协议。
- 设置默认的队列调度器，可以选择多个支持的调度器。
- 调整系统涉及的关键 TCP 参数提高性能。
- 调整TCP和UDP的缓冲区大小。
- 文件描述符限制的提升。

此脚本的目标是在不同场景中优化网络性能。

## 准备工作

确保您的运行环境支持以下内容:
- Linux 内核支持 BBR 和您选择的调度器。
- 以 root 或使用 `sudo` 运行脚本。

## 下载和安装
可以通过以下步骤安装此脚本：

```bash
# 下载脚本
wget -O tcp_tuning.sh 失效的下载链接
# 给脚本执行权限
chmod +x tcp_tuning.sh
# 移动脚本到全局可执行目录（如果需要）
mv tcp_tuning.sh /usr/local/bin/
