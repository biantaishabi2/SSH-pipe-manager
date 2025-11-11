#!/bin/bash

# SSH小管家停止脚本

SESSION_ID="${1:-0}"

# 检查PID文件
PID_FILE="/tmp/ssh-${SESSION_ID}.pid"
if [ ! -f "$PID_FILE" ]; then
    echo "❌ SSH小管家会话 $SESSION_ID 没有在运行"
    exit 1
fi

# 读取PID
PID=$(cat "$PID_FILE")

# 检查进程是否存在
if ! kill -0 $PID 2>/dev/null; then
    echo "❌ 进程 $PID 不存在，清理PID文件"
    rm -f "$PID_FILE"
    exit 1
fi

echo "正在停止SSH小管家会话 $SESSION_ID (PID: $PID)..."

# 发送TERM信号
kill -TERM $PID 2>/dev/null

# 等待进程结束
for i in {1..10}; do
    if ! kill -0 $PID 2>/dev/null; then
        echo "✅ SSH小管家已正常停止"
        break
    fi
    echo "等待进程结束... ($i/10)"
    sleep 1
done

# 如果进程还在运行，强制杀死
if kill -0 $PID 2>/dev/null; then
    echo "⚠️  进程未响应TERM信号，强制终止..."
    kill -KILL $PID 2>/dev/null
    sleep 1
fi

# 清理文件
echo "清理管道文件..."
rm -f "/tmp/ssh-${SESSION_ID}.in"
rm -f "/tmp/ssh-${SESSION_ID}.out"
rm -f "/tmp/ssh-${SESSION_ID}.status"
rm -f "$PID_FILE"

echo "✅ SSH小管家会话 $SESSION_ID 已完全停止"

# 显示日志文件位置（如果存在）
LOG_FILE="/tmp/ssh-${SESSION_ID}.log"
if [ -f "$LOG_FILE" ]; then
    echo "日志文件保留在: $LOG_FILE"
    echo "如需查看日志: cat $LOG_FILE"
fi