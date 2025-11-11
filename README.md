# SSH小管家 - 常驻SSH管道管理系统

## 📖 简介

SSH小管家是一个基于"纸带模型"设计的SSH连接管理系统，它将SSH连接抽象为简单的文件读写操作，让任何程序（包括AI）都能轻松使用SSH连接。

## 🎯 核心理念

- **stdin** = "往程序里塞东西的口" → `/tmp/ssh-0.in`
- **stdout** = "程序往外吐东西的口" → `/tmp/ssh-0.out`
- **小管家** = 永远保持SSH连接，自动重连，管理数据转发

## 🚀 快速开始

### 1. 启动SSH小管家

```bash
# 启动连接到co服务器的会话0
./ssh-start.sh co

# 启动多个会话（可选）
./ssh-start.sh co 1
./ssh-start.sh other-host 2
```

### 2. 发送命令

#### 方法一：使用 ai-run（推荐）
```bash
# 一条命令完成：发送 → 等待 → 读取 → 返回
./ai-run.sh "ls -la"
./ai-run.sh "systemctl restart nginx && systemctl status nginx"

# 带超时的命令
./ai-run.sh "sleep 60" 30  # 30秒超时
```

#### 方法二：手动管道操作
```bash
# 发送简单命令
echo "ls -la" > /tmp/ssh-0.in

# 发送复杂命令
echo "systemctl restart nginx && systemctl status nginx" > /tmp/ssh-0.in
```

### 3. 查看结果

#### 使用 ai-run（自动返回结果）
```bash
# ai-run 自动输出结果到屏幕
./ai-run.sh "whoami"
# 输出: username
```

#### 手动查看
```bash
# 查看单次结果
cat /tmp/ssh-0.out

# 持续监控输出
tail -f /tmp/ssh-0.out
```

### 4. 停止服务

```bash
# 停止会话0
./ssh-stop.sh 0

# 停止指定会话
./ssh-stop.sh 1
```

## 📁 文件结构

```
ssh-pipe-manager/
├── ssh-daemon.sh      # 核心守护进程
├── ssh-start.sh       # 启动脚本
├── ssh-stop.sh        # 停止脚本
├── ssh-status.sh      # 状态查看
├── ai-run.sh          # 同步SSH命令执行器 ⭐
├── test-ai-run.sh     # ai-run功能测试脚本
├── EXAMPLES.md        # 详细使用示例
└── README.md          # 使用说明
```

## 🔧 管道文件

| 文件路径 | 用途 | 说明 |
|---------|------|------|
| `/tmp/ssh-0.in` | 输入管道 | 写入命令 |
| `/tmp/ssh-0.out` | 输出管道 | 读取结果 |
| `/tmp/ssh-0.status` | 状态管道 | 连接状态 |
| `/tmp/ssh-0.pid` | PID文件 | 进程ID |
| `/tmp/ssh-0.log` | 日志文件 | 运行日志 |

## 🎮 使用示例

### 基础操作

```bash
# 启动服务
./ssh-start.sh co

# 查看状态
./ssh-status.sh 0

# 发送命令
echo "whoami" > /tmp/ssh-0.in
cat /tmp/ssh-0.out

# 持续监控
tail -f /tmp/ssh-0.out &
echo "top -n 1" > /tmp/ssh-0.in
```

### 脚本集成

```bash
#!/bin/bash
# 自动化脚本示例

# 启动小管家
./ssh-start.sh co

# 发送一系列命令
commands=(
    "cd /var/log"
    "ls -la *.log"
    "tail -10 nginx.log"
    "df -h"
)

for cmd in "${commands[@]}"; do
    echo "执行: $cmd"
    echo "$cmd" > /tmp/ssh-0.in
    sleep 2
    cat /tmp/ssh-0.out
    echo "---"
done

# 清理
./ssh-stop.sh 0
```

### AI集成示例

```python
# Python示例
import time
import os

def send_command(cmd, session_id=0):
    pipe_in = f"/tmp/ssh-{session_id}.in"
    pipe_out = f"/tmp/ssh-{session_id}.out"
    
    # 发送命令
    with open(pipe_in, 'w') as f:
        f.write(cmd + '\n')
    
    # 等待执行
    time.sleep(1)
    
    # 读取结果
    result = []
    with open(pipe_out, 'r') as f:
        for line in f:
            if line.startswith('== exit='):
                break
            result.append(line.strip())
    
    return '\n'.join(result)

# 使用
output = send_command('ls -la')
print(output)
```

## 🔍 特殊命令

| 命令 | 功能 |
|------|------|
| `__PING__` | 心跳检测，返回PONG和时间 |
| `__STATUS__` | 获取运行状态 |

```bash
# 心跳测试
echo "__PING__" > /tmp/ssh-0.in
cat /tmp/ssh-0.out
# 输出: PONG:2024-01-01 12:00:00
```

## 🛠️ 高级功能

### 多会话管理

```bash
# 启动多个连接
./ssh-start.sh co 0      # 会话0
./ssh-start.sh test 1    # 会话1
./ssh-start.sh prod 2    # 会话2

# 并行使用
echo "hostname" > /tmp/ssh-0.in
echo "hostname" > /tmp/ssh-1.in
echo "hostname" > /tmp/ssh-2.in

# 查看不同结果
cat /tmp/ssh-0.out
cat /tmp/ssh-1.out
cat /tmp/ssh-2.out
```

### 状态监控

```bash
# 查看详细状态
./ssh-status.sh 0

# 实时监控连接状态
watch -n 5 './ssh-status.sh 0'
```

### 日志查看

```bash
# 查看完整日志
cat /tmp/ssh-0.log

# 实时监控日志
tail -f /tmp/ssh-0.log

# 查看错误日志
grep -i error /tmp/ssh-0.log
```

## ⚠️ 注意事项

1. **权限要求**: 确保有SSH密钥认证或密码less SSH配置
2. **网络稳定性**: 小管家会自动重连，但频繁断开会影响性能
3. **命令执行**: 每次只执行一个命令，长时间运行的命令会阻塞后续命令
4. **资源清理**: 停止服务时会自动清理管道文件
5. **并发限制**: 同一会话内命令串行执行，多会话可并行

## 🐛 故障排除

### 常见问题

**Q: 启动失败**
```bash
# 检查日志
cat /tmp/ssh-0.log

# 检查SSH配置
ssh -o ConnectTimeout=5 co "echo test"
```

**Q: 管道无响应**
```bash
# 检查进程状态
./ssh-status.sh 0

# 重启服务
./ssh-stop.sh 0
./ssh-start.sh co
```

**Q: 命令执行超时**
```bash
# 检查网络连接
ping co

# 查看SSH配置
ssh -G co
```

## 🚀 ai-run - 同步SSH命令执行器

`ai-run` 是SSH小管家的核心客户端工具，将复杂的"写→等→读→返回"过程封装为一个简单的函数调用。

### 💫 核心特性

- **一步完成**: 一个命令完成"发送→等待→读取→返回"全部过程
- **同步阻塞**: 像本地命令一样使用，返回即结果
- **自动清理**: 自动生成唯一订单号，自动清理临时文件
- **超时控制**: 支持自定义超时时间，防止命令卡死
- **错误处理**: 正确返回远程命令的退出码
- **多会话**: 支持多个SSH会话并行使用

### 🎯 用法

```bash
# 基础用法
./ai-run.sh "远程命令" [超时秒数]

# 环境变量
SSH_SESSION=1  # 指定会话ID
DEBUG=1        # 启用调试模式

# 示例
./ai-run.sh "whoami"
./ai-run.sh "systemctl restart nginx && systemctl status nginx"
./ai-run.sh "sleep 60" 30  # 30秒超时
SSH_SESSION=2 ./ai-run.sh "hostname"
```

### 🔧 内部机制

1. **生成订单号**: 使用时间戳+PID+随机数生成唯一订单号
2. **创建临时文件**: `cmd-XXXX.json` 和 `result-XXXX.json`
3. **发送命令**: 通过`__AI_RUN__`特殊命令发送到SSH小管家
4. **等待结果**: 阻塞等待SSH小管家执行完成并写回结果
5. **返回输出**: 将远程输出打印到屏幕，返回退出码
6. **自动清理**: 删除临时文件，无残留

### 📖 更多示例

查看 [EXAMPLES.md](EXAMPLES.md) 获取详细的使用示例和最佳实践。

### 🧪 测试

```bash
# 测试ai-run功能
./test-ai-run.sh

# 需要先启动SSH小管家
./ssh-start.sh <hostname>
```

## 📝 开发说明

### 核心机制

1. **命名管道**: 使用`mkfifo`创建无限长度的数据通道
2. **进程管理**: 守护进程监控SSH连接，自动重连
3. **命令队列**: 串行执行命令，避免冲突
4. **状态同步**: 实时报告连接状态和执行结果
5. **订单系统**: ai-run使用订单号系统实现异步命令的同步等待

### 扩展开发

- 支持更多SSH选项
- 添加命令优先级队列
- 增加认证方式支持
- 实现批量命令执行

## 📄 许可证

MIT License - 自由使用和修改

---

**一句话记住**: stdin就是"往里塞的口子"，stdout就是"往外吐的口子"，小管家把SSH永远吊着，两口子钉成文件，读写即命令！

---

💡 **提示**: 所有脚本都支持 `--help` 或 `-h` 参数查看详细帮助信息：

```bash
./ai-run.sh --help
./test-ai-run.sh --help
./ssh-start.sh --help
```# SSH-pipe-manager
# SSH-pipe-manager
