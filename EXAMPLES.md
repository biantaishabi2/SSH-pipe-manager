# ai-run 使用示例

`ai-run` 是一个极简的SSH命令执行工具，将复杂的"写→等→读→返回"过程封装成一个函数调用。

## 🚀 基础使用

### 简单命令
```bash
# 查看当前用户
ai-run "whoami"

# 列出文件
ai-run "ls -la"

# 查看系统信息
ai-run "uname -a"
```

### 带超时的命令
```bash
# 默认30秒超时
ai-run "sleep 10"

# 自定义超时（60秒）
ai-run "sleep 50" 60
```

## 🔧 高级用法

### 复杂命令组合
```bash
# 重启服务并检查状态
ai-run "systemctl restart nginx && systemctl status nginx"

# 查看磁盘使用
ai-run "df -h | grep -v tmpfs | sort -hr"

# 查找大文件
ai-run "find /var/log -type f -size +100M -exec ls -lh {} \;"
```

### 脚本和管道操作
```bash
# 统计日志文件行数
ai-run "wc -l /var/log/nginx/access.log"

# 实时监控（需要注意超时）
ai-run "tail -20 /var/log/syslog"

# 复杂的shell脚本
ai-run 'for i in {1..5}; do echo "Count: \$i"; sleep 1; done'
```

### 引号处理
```bash
# 包含空格和引号的命令
ai-run 'echo "Hello, World!"'

# 使用变量
ai-run 'echo "Date: $(date)"'

# 复杂字符串
ai-run 'echo "System: $(uname -n), Kernel: $(uname -r)"'
```

## 🔄 批处理和自动化

### 循环执行
```bash
#!/bin/bash
# 批量检查多个服务状态

services=("nginx" "mysql" "redis" "docker")

for service in "${services[@]}"; do
    echo "检查服务: $service"
    ai-run "systemctl is-active $service"
    echo "---"
done
```

### 读取配置文件执行
```bash
#!/bin/bash
# 从配置文件读取命令列表

while IFS= read -r cmd; do
    echo "执行: $cmd"
    ai-run "$cmd"
    echo
done < commands.txt
```

### 条件执行
```bash
#!/bin/bash
# 根据前一个命令的结果执行后续操作

if ai-run "systemctl is-active nginx" | grep -q "active"; then
    echo "Nginx正在运行，重新加载配置"
    ai-run "nginx -s reload"
else
    echo "Nginx未运行，启动服务"
    ai-run "systemctl start nginx"
fi
```

## 🤖 AI/机器人集成

### Python 集成示例
```python
import subprocess
import json

def run_remote_command(cmd, timeout=30):
    """通过ai-run执行远程命令"""
    try:
        result = subprocess.run(
            ['./ai-run.sh', cmd, str(timeout)],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout, result.returncode
    except subprocess.CalledProcessError as e:
        return e.stdout, e.returncode

# 使用示例
output, exit_code = run_remote_command("ls -la")
print(f"输出: {output}")
print(f"退出码: {exit_code}")
```

### Node.js 集成示例
```javascript
const { execSync } = require('child_process');

function runRemoteCommand(cmd, timeout = 30) {
    try {
        const output = execSync(`./ai-run.sh "${cmd}" ${timeout}`, {
            encoding: 'utf8',
            timeout: timeout * 1000
        });
        return { success: true, output };
    } catch (error) {
        return { success: false, error: error.message, exitCode: error.status };
    }
}

// 使用示例
const result = runRemoteCommand('whoami');
console.log(result);
```

## 🎯 CI/CD 集成

### GitHub Actions 示例
```yaml
name: Remote Server Check
on: [push]

jobs:
  check-server:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Setup SSH Manager
        run: |
          cd ssh-pipe-manager
          ./ssh-start.sh ${{ secrets.REMOTE_HOST }}

      - name: Check Services
        run: |
          cd ssh-pipe-manager
          ./ai-run.sh "systemctl status nginx"
          ./ai-run.sh "systemctl status mysql"

      - name: Deploy Application
        run: |
          cd ssh-pipe-manager
          ./ai-run.sh "git pull origin main"
          ./ai-run.sh "npm install --production"
          ./ai-run.sh "pm2 restart app"
```

### Jenkins Pipeline 示例
```groovy
pipeline {
    agent any

    stages {
        stage('Setup') {
            steps {
                sh 'cd ssh-pipe-manager && ./ssh-start.sh production-server'
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    cd ssh-pipe-manager
                    ./ai-run.sh "git pull origin main"
                    ./ai-run.sh "docker-compose up -d --build"
                '''
            }
        }

        stage('Verify') {
            steps {
                sh 'cd ssh-pipe-manager && ./ai-run.sh "curl -f http://localhost:3000/health"'
            }
        }
    }

    post {
        always {
            sh 'cd ssh-pipe-manager && ./ssh-stop.sh 0'
        }
    }
}
```

## 🔍 调试和故障排除

### 启用调试模式
```bash
# 查看详细执行过程
DEBUG=1 ai-run "ls -la"

# 调试特定会话
SSH_SESSION=1 DEBUG=1 ai-run "hostname"
```

### 错误处理
```bash
#!/bin/bash
# 检查命令执行结果

if ! ai-run "systemctl start nginx"; then
    echo "启动Nginx失败，检查日志"
    ai-run "journalctl -u nginx --no-pager -l"
    exit 1
fi

echo "Nginx启动成功"
```

### 超时处理
```bash
#!/bin/bash
# 处理长时间运行的命令

# 快速命令（10秒超时）
ai-run "systemctl reload nginx" 10

# 慢速命令（5分钟超时）
ai-run "mysqldump --all-databases > backup.sql" 300

# 超时后重试
max_retries=3
for i in $(seq 1 $max_retries); do
    if ai-run "wget http://example.com/large-file.zip" 60; then
        echo "下载成功"
        break
    else
        echo "下载失败或超时，重试 $i/$max_retries"
    fi
done
```

## 💡 最佳实践

### 1. 命令组织
```bash
# ✅ 好：单行命令，清晰明了
ai-run "systemctl restart nginx && systemctl status nginx"

# ❌ 避免：过于复杂的单行命令
ai-run "cd /var/log && find . -name '*.log' -mtime +30 -delete && echo 'cleanup done' && df -h"
```

### 2. 错误处理
```bash
# ✅ 好：检查退出码
if ai-run "ping -c 3 google.com"; then
    echo "网络连通"
else
    echo "网络不通"
fi

# ✅ 好：使用set -e
set -e
ai-run "apt-get update"
ai-run "apt-get upgrade -y"
```

### 3. 资源管理
```bash
# ✅ 好：适当设置超时
ai-run "apt-get update" 60
ai-run "docker build -t myapp ." 300

# ✅ 好：及时清理
./ssh-start.sh production-server
ai-run "rm -rf /tmp/cache/*"
./ssh-stop.sh 0
```

### 4. 安全考虑
```bash
# ✅ 好：避免在命令中包含敏感信息
TOKEN="secret123"
ai-run "curl -H \"Authorization: Bearer \$TOKEN\" https://api.example.com"

# ❌ 避免：直接暴露敏感信息
# ai-run "curl -H \"Authorization: Bearer secret123\" https://api.example.com"
```

## 🎪 进阶技巧

### 多会话并行执行
```bash
#!/bin/bash
# 启动多个SSH会话
./ssh-start.sh server1 0
./ssh-start.sh server2 1
./ssh-start.sh server3 2

# 并行执行命令
SSH_SESSION=0 ai-run "hostname" &
SSH_SESSION=1 ai-run "hostname" &
SSH_SESSION=2 ai-run "hostname" &

# 等待所有命令完成
wait
```

### 实时监控模式
```bash
#!/bin/bash
# 持续监控系统状态

while true; do
    clear
    echo "=== 系统状态监控 $(date) ==="
    ai-run "top -b -n1 | head -10"
    echo
    ai-run "df -h | head -5"
    echo
    ai-run "free -h"
    sleep 10
done
```

---

记住：`ai-run` 让远程SSH调用变得像本地命令一样简单！