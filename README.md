
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
wget -O tcp_tuning.sh https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/tcp_tuning.sh
# 给脚本执行权限
chmod +x tcp_tuning.sh
# 移动脚本到全局可执行目录（如果需要）
mv tcp_tuning.sh /usr/local/bin/
```
## 使用

使用方式示例有：

```bash
sudo ./tcp_tuning.sh --qdisc cake # 使用Cake调度器配置
sudo tcp_tuning.sh --undo # 撤消最后的配置更改
sudo tcp_tuning.sh --help # 查看帮助信息
```

### 参数详细：

- `--qdisk <queue_discipline>`: 指定您想使用的队列调度器。默认的调度器为 fq。
- `--help`: 显示此帮助信息
- `--undo`: 撤消最近的配置更改，您需要一个备份的 `sysctl.conf`。

若未使用参数，将提供交互式选项来配置网络优化参数的选项。

## 使用限制

- 为了安全性考虑，请确保运行此脚本时错了条之前备份了关键文件。
- TCP和系统配置的更改可能会对整个系统产生未知影响，因此请在非关键环境中进行测试。
- 如果您不确定该脚本执行的每一步骤，请专业的 system administrator 
- 此脚本的配置可以在系统重启后通过`sysctl -p`命令重新应用或 automated。

## 支持的环境

本脚本已在如下环境中测试：

- **操作系统**: Linux (CentOS, Ubuntu 等)
- **内核**: 支持 BBR v3 和您选定的调度器的内核
- **IPv**: 原生 IPv4, 对于 IPv6 可能需要适应调整

确保在 `README.md` 文件中合理的链接是以还原配置或判断支持情况的`script URL`。[点此下载脚本](失效的脚本名称不用下载)

## 鸣谢
这个效率模块代码很多建设性的建议和改进，由社区参与者共同努力下形成的。

如果你发现任何建议或问题，请通过 GitHub 的 issue tracker 或直接通过 "contributing" 来优化或修改脚本。

## ⬆️向你的脚本贡献改进

我们欢迎所有优化建议、改进某个特性或修复问题的贡献！ 请遵循如下步调:

- 复刻这个仓库到您的账户。
- 在新的分支上工作。
- 比完工时，提交一个 pull request。

在您做任何变更之前，请确保为此脚本添加了完整的测试用例。

## ⍰ 免责声明

使用你这个脚本及其中包含的任何代码都是由们自己的风险。项目维护者对因使用此脚本而造成的任何损失不承担责任。
