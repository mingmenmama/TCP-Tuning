# TCP Tuning Script
  
这是一个为您的 Linux 系统设计的 Bash 脚本, 能够优化 TCP 和系统参数，包括：

- 自动检测并配置 BBR (Bottleneck Bandwidth and RTT) 协议。
- 设置默认的队列调度器，包括 fq, cake, pfifo_fast, sfq, htb, fq_codel, noqueue, 和 bfifo。
- 调整TCP和系统的关键参数提升性能。
- 重新配置TCP和UDP的缓冲区大小。
- 增加文件描述符限制。
  
## 脚本地址

- **下载 URL**: [GitHub Raw URL](https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/tcp_tuning.sh)

## 准备工作

请确保您的环境满足以下条件：

- 内核支持 BBR 和选定的队列调度器。
- 以 root 或使用 `sudo` 运行此脚本。

## 安装

```bash
# 下载脚本
wget -O tcp_tuning.sh https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/tcp_tuning.sh

# 给脚本执行权限
chmod +x tcp_tuning.sh

# 移动到全局可执行目录
sudo mv tcp_tuning.sh /usr/local/sbin/
