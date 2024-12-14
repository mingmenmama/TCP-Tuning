请使用以下内容更新`README.md`以反映新脚本的功能和一键安装选项：

```markdown

# TCP Tuning Script

这是一个为您的 Linux 系统设计的 Bash 脚本来帮助自动化 TCP 调优,提供提高网络性能的解决方案。该脚本提供自动配置 BBR 以及其他关键系统参数,同时支持用户自定义选择不同的队列调度器。

## 支持的特性
- **BBR (Bottleneck Bandwidth and RTT) 配置**: 设置默认TCP拥塞控制算法为BBR，并将队列调度器切换到`cake`。
- **TCP参数优化**: 调整TCP参数来提升网络和系统的性能。
- **缓冲区调整**: 配置TCP和UDP缓冲区大小，以优化网络流量。
- **文件描述符限制**: 增加文件描述符限制以支持更高的并发连接。

## 脚本地址

- **下载 URL**: [GitHub Raw URL](https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/tcp_tuning.sh)

## 准备工作

系统配置要求：

- 您的系统必须支持 BBR 和 `cake` 队列策略。
- 脚本需要以 `root` `超级用户执行权限运行。
- 更改配置可能会影响您的系统或服务的性能，务必保证备份和测试评估。

## 一键安装并配置

```bash
# 一键安装并使用脚本
# 注意，此脚本将在执行时设置 root 或超级用户权限
wget -O /tmp/tcp_tuning.sh https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/tcp_tuning.sh && sudo bash /tmp/tcp_tuning.sh
```

### 说明：
- 此脚本会自动将自己移动到 `/usr/local/sbin/`.
- 安装后，您将被引导进行配置选择操作。
- 提供安装过程中的确认，允许用户随时结束或继续配置。

## 使用

### 手动执行
如果您不想使用一键安装功能，可以手动运行脚本：

```bash
# 从 GitHub 下载脚本
wget -O tcp_tuning.sh https://raw.githubusercontent.com/mingmenmama/TCP-Tuning/refs/heads/main/tcp_tuning.sh

# 脚本授权限
chmod +x tcp_tuning.sh

# 移动脚本到全局可执行目录
sudo mv tcp_tuning.sh /usr/local/sbin/

# 运行脚本
sudo tcp_tuning.sh
```

### 参数详解

- `none`: 使用默认配置，提供用户选择选项。
- `--help`: 查看帮助信息。
- `--qdisc <queue_discipline>`: 如需要，可以手动指定队列调度策略（e.g. `fq`, `cake`, etc.）。

## 注意事项

- 本脚本直接配置系统，可能会影响到应用程序或服务的网络行为。在应用之前请进行备份和测试。
- 配置更改会在系统启动时需要以 `sysctl -p` 重新应用，请确保在系统运行时及时恢复默认配置。
- 错误处理和日志机制的增强可确保脚本执行过程中的错误检测和问题排查。
- 请了解运行时所需的超级用户权限，以确保脚本能够正确执行系统设置。

## 支持的环境

- **操作系统**: 基于 Linux 的环境 (如 CentOS, Ubuntu, Debian)。
- **内核**: 需支持 BBR 和 `cake` 调度器的内核。此脚本默认配置`cake`为默认项，将不再检测BBR版本。
- **网络协议**: TCP 相关优化，默认支持 IPv4 环境。

## 向脚本贡献

如果您想为脚本的进一步改进做出贡献或提交改进请求：

1. **Fork 项目**: 将仓库复制到您自己的 GitHub 账户中。
2. **分支**: 创建一个新分支来进行开发工作。
3. **测试**: 新增测试用例或验证已有的功能。
4. **Pull Request**: 通过向源项目提交请求来提议您的更改。

所有讨论、共享建议与使用情况建议，都可以在 [GitHub页面](https://github.com/mingmenmama/TCP-Tuning) 中找到。

### 更新历史

- **最后更新**: `<Last Update Date>`
- **支持版本**: `<Version Number>` 更新后请记得替换此标记。
```

请确保将 `<Last Update Date>` 和 `<Version Number>` 替换为适当的值来反映最新更新日期和脚本版本。
