# 网络优化脚本

此项目包含了一个用于Linux操作系统的网络优化脚本，它通过调整TCP/IP参数和安装`cake` QDisc来增强系统的网络性能。

## 简介

这个`net_opt.sh`脚本主要实现了以下功能：
- 增强系统网络队列的管理能力，提高并发连接和处理能力。
- 设置安全和提高性能的TCP/IP参数。
- 将默认队列管理器（QDisc）设置为`cake`，以提供公平性和高效的网络资源分配。

## 软件使用

### 需求

- 支持的Linux发行版（如Debian, Ubuntu, CentOS等）
- 需要root或sudo权限以应用优化配置和安装`cake`模块。

### 使用指南

1. **获取脚本代码**: 2. **设置权限**: 3. **运行脚本**:
   - 将代码库克隆或下载到您的系统中。
     ```bash
     wget https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/net_opt.sh
     chmod +x net_opt.sh
     sudo ./net_opt.sh
     ```

2. **Cake QDisc支持情况**：
   - 对于可能不附带`cake`模块的系统，需要自行安装`cake`QDisc。可通过下方示例安装模块（以Debian系为例），或依据发行版文档进行相关配置：
     ```bash
     sudo apt update
     sudo apt install sch-cake
     ```

3. **应用QDisc**:
   - 脚本调整完成后，你需要手动重启网络服务或直接设置接口的QDisc：
   - # 以`eth0`接口为例
     ```bash
     sudo ip link set dev eth0 qdisc cake
     ```
     或者     # 重启网络服务示例（可能因发行版不同）
     ```bash
     sudo systemctl restart networking
     ```

## 参数说明

**脚本中设置的参数包括但不限于以下内容：**

- `net.core.somaxconn`：监听套接字队列
- `net.ipv4.tcp_max_syn_backlog`：同步设置队列
- `net.ipv4.tcp_syncookies`：启用SYN cookies
- `net.ipv4.tcp_timestamps`：启用TCP时间戳
- `net.ipv4.tcp_keepalive_time`：TCP keep-alive 间隔
- `net.ipv4.tcp_fin_timeout`：TCP连接进入FIN状态的超时时间
- `kernel.panic`：系统自动重启设置
- `vm.swappiness`：设置交换分区使用率
- `net.ipv4.tcp_window_scaling`：TCP窗口缩放
- `net.core.default_qdisc`：默认队列管理器

请注意，这些参数的设置可能需要根据具体网络环境做适当调整。

## 警告

- **实验性质**：本脚本提供了实验性设置，**自行评估和测试**后再应用于生产环境，避免影响既有的工作或服务。
- **备份**：执行此脚本前，强烈建议**备份你的配置文件**（如`/etc/sysctl.conf`等）。
- **重启服务**：某些变更需要重启网络服务或系统才能生效，因此请务必查看完成脚本后的指示信息。
- **非专业用户请谨慎使用**：如果你对这些网络优化配置不熟悉，请在应用此优化策略前先咨询专业人员。
