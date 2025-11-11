# sshrun - SSH管道管理器CLI命令

`sshrun` 是SSH管道管理器的命令行界面，提供了简洁易用的方式来管理SSH会话和执行远程命令。

## 🚀 快速开始

### 安装

```bash
# 在项目目录中运行
./sshrun install
```

### 基本使用

```bash
# 执行远程命令
sshrun "whoami"
sshrun "ls -la | head -5"

# 启动SSH会话
sshrun start mini

# 查看状态
sshrun status
```

## 📖 命令参考

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
```

### 选项

```bash
-s, --session N    指定会话ID (默认: 0)
-h, --help         显示帮助信息
-v, --version      显示版本信息
```

## 💡 使用示例

### 单会话使用

```bash
# 启动连接
sshrun start mini

# 执行命令
sshrun "whoami"
sshrun "pwd"
sshrun "ls -la | head -5"
sshrun "ps aux | grep ssh"

# 查看状态
sshrun status

# 停止连接
sshrun stop
```

### 多会话管理

```bash
# 启动多个会话
sshrun start mini              # 默认会话0
sshrun start prod 1            # 会话1
sshrun start test 2            # 会话2

# 在不同会话执行命令
sshrun "hostname"              # 会话0
sshrun "hostname" -s 1         # 会话1
sshrun "hostname" -s 2         # 会话2

# 查看所有会话
sshrun list

# 停止特定会话
sshrun stop 1                  # 停止会话1
```

### 高级用法

```bash
# 复杂命令
sshrun "find . -name '*.log' -mtime +7 -delete"
sshrun "docker ps -a | grep 'Exited' | awk '{print \$1}' | xargs docker rm"
sshrun "tar -czf backup.tar.gz /var/www/html && scp backup.tar.gz user@backup:/backups/"

# 重启会话
sshrun restart prod 1

# 监控会话状态
watch -n 5 'sshrun status'
```

## 🔧 配置

### 环境变量

- `SSH_SESSION`: 指定默认会话ID（默认: 0）
- `DEBUG`: 设置为1启用调试模式

### 配置文件位置

- 脚本目录: 自动检测
- 安装目录: `$HOME/.local/bin`
- 配置目录: `$HOME/.config/sshrun`

## 📝 故障排除

### 常见问题

**Q: 命令执行失败**
```bash
# 检查会话状态
sshrun status

# 重启会话
sshrun restart <hostname>

# 查看详细错误
DEBUG=1 sshrun "whoami"
```

**Q: 找不到sshrun命令**
```bash
# 重新安装
./sshrun install

# 检查PATH
echo $PATH | grep -o $HOME/.local/bin
```

**Q: 权限问题**
```bash
# 确保脚本有执行权限
chmod +x sshrun
chmod +x *.sh
```

### 调试模式

```bash
DEBUG=1 sshrun "command"
```

## 🎯 最佳实践

1. **会话管理**: 为不同环境使用不同的会话ID
2. **命令格式**: 使用引号包围复杂命令
3. **错误处理**: 检查会话状态后再执行命令
4. **资源清理**: 定期清理不需要的会话

### 示例脚本

```bash
#!/bin/bash
# 批量服务器检查

servers=("prod" "staging" "dev")

for server in "${servers[@]}"; do
    echo "检查服务器: $server"
    sshrun start "$server"
    sshrun "uptime && df -h"
    sshrun stop
done
```

## 🔄 与原始脚本对比

| 原始命令 | sshrun命令 |
|---------|------------|
| `./ssh-start.sh mini` | `sshrun start mini` |
| `./ai-run.sh "command"` | `sshrun "command"` |
| `./ssh-status.sh 0` | `sshrun status` |
| `./ssh-stop.sh 0` | `sshrun stop` |

## 📄 许可证

MIT License - 与SSH管道管理器项目保持一致

---

**一句话记住**: `sshrun` - 让SSH管理像本地命令一样简单！