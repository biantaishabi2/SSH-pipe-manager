# sshrun - 简洁强大的SSH管道管理器

## 📖 简介

`sshrun` 是一个基于"纸带模型"设计的SSH连接管理系统，它将复杂的SSH连接操作简化为一条命令，让你像执行本地命令一样轻松管理远程服务器。

## 🎯 核心特点

- **一步到位**: `sshrun "command"` - 像本地命令一样执行远程命令
- **自动重连**: 永久保持SSH连接，断线自动重连
- **多会话**: 同时管理多个SSH连接
- **简单安装**: 一条命令安装到系统PATH
- **强大支持**: 支持管道、重定向、复杂脚本

## 🚀 快速开始

### 1. 安装

```bash
# 克隆项目
git clone https://github.com/biantaishabi2/SSH-pipe-manager.git
cd SSH-pipe-manager

# 一键安装到系统
./sshrun install
```

### 2. 基本使用

```bash
# 启动SSH连接
sshrun start mini

# 执行远程命令（就像本地命令一样！）
sshrun "whoami"
sshrun "ls -la | head -5"
sshrun "ps aux | grep nginx"
sshrun "date '+%Y-%m-%d %H:%M:%S'"
```

### 3. 查看状态

```bash
sshrun status      # 查看连接状态
sshrun list        # 列出所有活动会话
```

## 📚 命令参考

### 基本命令

```bash
sshrun "command"                 # 执行远程命令
sshrun start host [session_id]   # 启动SSH会话
sshrun stop [session_id]         # 停止SSH会话
sshrun restart host [session_id] # 重启SSH会话
sshrun status [session_id]       # 查看会话状态
sshrun list                      # 列出所有活动会话
```

### 配置管理

```bash
sshrun install                   # 安装到系统PATH
sshrun uninstall                 # 从系统移除
sshrun config                    # 显示配置信息
sshrun --help                    # 显示帮助
sshrun --version                 # 显示版本
```

### 选项

```bash
-s N, --session N    # 指定会话ID (默认: 0)
-h, --help          # 显示帮助信息
-v, --version       # 显示版本信息
```

## 💡 使用示例

### 日常运维

```bash
# 启动连接
sshrun start prod

# 系统检查
sshrun "uptime"
sshrun "df -h"
sshrun "free -h"

# 服务管理
sshrun "systemctl restart nginx"
sshrun "systemctl status nginx"

# 日志查看
sshrun "tail -f /var/log/nginx/access.log"
```

### 复杂操作

```bash
# 批量操作
sshrun "find /var/log -name '*.log' -mtime +7 -delete"

# 管道操作
sshrun "ps aux | grep python | head -5"

# 重定向
sshrun "df -h > /tmp/disk_usage.txt && cat /tmp/disk_usage.txt"

# 脚本执行
sshrun "bash /path/to/script.sh"
```

### 多会话管理

```bash
# 启动多个连接
sshrun start prod              # 默认会话0 (生产环境)
sshrun start staging 1         # 会话1 (测试环境)
sshrun start dev 2             # 会话2 (开发环境)

# 在不同环境执行命令
sshrun "hostname"              # 生产环境
sshrun "hostname" -s 1         # 测试环境
sshrun "hostname" -s 2         # 开发环境

# 批量检查
for i in {0..2}; do
    echo "环境 $i:"
    sshrun "hostname && uptime" -s $i
done
```

## 🔧 高级功能

### 调试模式

```bash
DEBUG=1 sshrun "whoami"
```

### 会话持久化

```bash
# 重启会话（保持连接）
sshrun restart prod

# 查看所有活动连接
sshrun list
```

### 环境变量

```bash
# 设置默认会话
export SSH_SESSION=1
sshrun "whoami"  # 会使用会话1
```

## 📝 实际应用场景

### 1. 自动化部署

```bash
#!/bin/bash
# deploy.sh

sshrun start production

# 拉取最新代码
sshrun "cd /var/www/app && git pull origin main"

# 安装依赖
sshrun "cd /var/www/app && npm install"

# 重启服务
sshrun "systemctl restart myapp"

# 检查状态
sshrun "systemctl status myapp"

echo "部署完成！"
```

### 2. 系统监控

```bash
#!/bin/bash
# monitor.sh

servers=("web1" "web2" "db1" "db2")

for server in "${servers[@]}"; do
    echo "=== $server ==="
    sshrun start "$server"
    sshrun "uptime && df -h && free -h"
    sshrun stop
    echo ""
done
```

### 3. 日志分析

```bash
# 查看错误日志
sshrun "tail -100 /var/log/nginx/error.log | grep ERROR"

# 分析访问量
sshrun "cat /var/log/nginx/access.log | awk '{print \$1}' | sort | uniq -c | sort -nr"

# 清理日志
sshrun "find /var/log -name '*.log' -mtime +30 -delete"
```

## 🔍 故障排除

### 常见问题

**Q: 命令执行超时**
```bash
# 检查连接状态
sshrun status

# 重启连接
sshrun restart <hostname>
```

**Q: 找不到sshrun命令**
```bash
# 重新安装
./sshrun install

# 检查PATH
echo $PATH
```

**Q: 权限问题**
```bash
# 确保有执行权限
chmod +x sshrun
```

### 调试技巧

```bash
# 启用调试模式
DEBUG=1 sshrun "command"

# 查看详细配置
sshrun config

# 监控连接状态
watch -n 5 'sshrun status'
```

## ⚡ 性能优化

- **连接复用**: 使用会话持久化，避免重复连接
- **批量操作**: 在一个会话中执行多个命令
- **并发执行**: 使用不同会话ID并行处理任务

## 🛠️ 原理说明

`sshrun` 基于"纸带模型"设计：

1. **输入磁带** (`/tmp/ssh-N.in`) - 写入命令
2. **输出磁带** (`/tmp/ssh-N.out`) - 读取结果
3. **守护进程** - 永远保持SSH连接，自动处理数据转发

这种设计让SSH操作变得像文件读写一样简单可靠。

## 📄 许可证

MIT License - 自由使用和修改

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**一句话记住**: `sshrun` - 让远程操作像本地命令一样简单！🚀