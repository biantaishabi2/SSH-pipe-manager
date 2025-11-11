#!/bin/bash

# SSH小管家状态查看脚本

SESSION_ID="${1:-0}"

echo "=== SSH小管家状态报告 ==="
echo "会话ID: $SESSION_ID"
echo ""

# 检查PID文件
PID_FILE="/tmp/ssh-${SESSION_ID}.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
        echo "✅ 进程状态: 运行中 (PID: $PID)"
        
        # 显示进程信息
        echo "📊 进程详情:"
        ps -p $PID -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || echo "无法获取进程详情"
        echo ""
    else
        echo "❌ 进程状态: PID文件存在但进程已死"
        echo "清理PID文件..."
        rm -f "$PID_FILE"
    fi
else
    echo "❌ 进程状态: 未运行"
fi

# 检查管道文件
echo "📁 管道文件状态:"
for pipe_type in in out status; do
    pipe_file="/tmp/ssh-${SESSION_ID}.${pipe_type}"
    if [ -p "$pipe_file" ]; then
        echo "  ✅ $pipe_file: 存在 (命名管道)"
    elif [ -f "$pipe_file" ]; then
        echo "  ⚠️  $pipe_file: 存在但不是管道"
    else
        echo "  ❌ $pipe_file: 不存在"
    fi
done
echo ""

# 检查状态管道内容
STATUS_FILE="/tmp/ssh-${SESSION_ID}.status"
if [ -p "$STATUS_FILE" ]; then
    echo "📡 连接状态:"
    # 发送ping请求
    echo "__PING__" > "/tmp/ssh-${SESSION_ID}.in" 2>/dev/null
    sleep 1
    
    # 尝试读取状态
    if read -t 2 status < "$STATUS_FILE" 2>/dev/null; then
        echo "  $status"
    else
        echo "  ⚠️  无法读取状态信息"
    fi
    echo ""
fi

# 显示日志文件信息
LOG_FILE="/tmp/ssh-${SESSION_ID}.log"
if [ -f "$LOG_FILE" ]; then
    echo "📝 日志文件: $LOG_FILE"
    echo "  文件大小: $(du -h "$LOG_FILE" | cut -f1)"
    echo "  最后修改: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOG_FILE" 2>/dev/null || stat -c "%y" "$LOG_FILE" 2>/dev/null)"
    echo ""
    echo "📋 最近5行日志:"
    tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
else
    echo "📝 日志文件: 不存在"
fi

echo ""
echo "🔧 使用提示:"
echo "  启动服务: ./ssh-start.sh <host> [$SESSION_ID]"
echo "  停止服务: ./ssh-stop.sh $SESSION_ID"
echo "  发送命令: echo \"command\" > /tmp/ssh-${SESSION_ID}.in"
echo "  查看结果: cat /tmp/ssh-${SESSION_ID}.out"
echo "  持续监控: tail -f /tmp/ssh-${SESSION_ID}.out"