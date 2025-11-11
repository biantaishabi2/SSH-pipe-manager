#!/bin/bash

# SSH小管家启动脚本

SSH_HOST="$1"
SESSION_ID="${2:-0}"

# 检查参数
if [ -z "$SSH_HOST" ]; then
    echo "用法: $0 <ssh-host> [session-id]"
    echo "示例: $0 co"
    echo "示例: $0 co 1"
    exit 1
fi

# 检查是否已经运行
PID_FILE="/tmp/ssh-${SESSION_ID}.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
        echo "SSH小管家会话 $SESSION_ID 已经在运行 (PID: $PID)"
        exit 1
    else
        echo "清理过期的PID文件..."
        rm -f "$PID_FILE"
    fi
fi

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "启动SSH小管家..."
echo "目标主机: $SSH_HOST"
echo "会话ID: $SESSION_ID"
echo "输入管道: /tmp/ssh-${SESSION_ID}.in"
echo "输出管道: /tmp/ssh-${SESSION_ID}.out"
echo "状态管道: /tmp/ssh-${SESSION_ID}.status"

# 启动守护进程
nohup "$SCRIPT_DIR/ssh-daemon.sh" "$SSH_HOST" "$SESSION_ID" > "/tmp/ssh-${SESSION_ID}.log" 2>&1 &

# 等待启动
sleep 2

# 检查是否启动成功
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
        echo "✅ SSH小管家启动成功!"
        echo "PID: $PID"
        echo "日志文件: /tmp/ssh-${SESSION_ID}.log"
        echo ""
        echo "使用方法:"
        echo "  发送命令: echo \"your command\" > /tmp/ssh-${SESSION_ID}.in"
        echo "  查看结果: cat /tmp/ssh-${SESSION_ID}.out"
        echo "  持续监控: tail -f /tmp/ssh-${SESSION_ID}.out"
        echo "  查看状态: cat /tmp/ssh-${SESSION_ID}.status"
        echo "  停止服务: $SCRIPT_DIR/ssh-stop.sh $SESSION_ID"
    else
        echo "❌ SSH小管家启动失败"
        echo "请检查日志: /tmp/ssh-${SESSION_ID}.log"
        exit 1
    fi
else
    echo "❌ SSH小管家启动失败 - PID文件未创建"
    echo "请检查日志: /tmp/ssh-${SESSION_ID}.log"
    exit 1
fi