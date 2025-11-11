#!/bin/bash

# SSH小管家 - 核心守护进程 (改进版)
# 使用文件轮询而非命名管道，避免阻塞问题

SSH_HOST="$1"
SESSION_ID="${2:-0}"
PIPE_IN="/tmp/ssh-${SESSION_ID}.in"
PIPE_OUT="/tmp/ssh-${SESSION_ID}.out"
PIPE_STATUS="/tmp/ssh-${SESSION_ID}.status"
PID_FILE="/tmp/ssh-${SESSION_ID}.pid"
LOCK_FILE="/tmp/ssh-${SESSION_ID}.lock"

# 检查参数
if [ -z "$SSH_HOST" ]; then
    echo "用法: $0 <ssh-host> [session-id]"
    exit 1
fi

# 清理函数
cleanup() {
    echo "正在清理SSH小管家..."
    
    # 杀掉SSH进程
    if [ -n "$SSH_PID" ]; then
        kill $SSH_PID 2>/dev/null
    fi
    
    # 删除文件
    rm -f "$PIPE_IN" "$PIPE_OUT" "$PIPE_STATUS" "$PID_FILE" "$LOCK_FILE"
    
    echo "SSH小管家已停止"
    exit 0
}

# 信号处理
trap cleanup SIGINT SIGTERM

# 创建文件（不是管道）
echo "创建通信文件..."
rm -f "$PIPE_IN" "$PIPE_OUT" "$PIPE_STATUS" "$LOCK_FILE"
touch "$PIPE_IN" "$PIPE_OUT" "$PIPE_STATUS"

# 保存PID
echo $$ > "$PID_FILE"

# 更新状态
echo "STATUS:STARTING" > "$PIPE_STATUS"

# 主循环
while true; do
    echo "正在连接到 $SSH_HOST..."
    
    # 更新状态
    echo "STATUS:CONNECTING" > "$PIPE_STATUS"
    
    # 测试SSH连接
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_HOST" "echo 'SSH_OK'" >/dev/null 2>&1; then
        echo "SSH连接失败，5秒后重试..."
        sleep 5
        continue
    fi
    
    echo "STATUS:CONNECTED" > "$PIPE_STATUS"
    
    # 命令处理循环
    while true; do
        # 检查SSH连接是否还活着
        if ! ssh -o ConnectTimeout=3 -o BatchMode=yes "$SSH_HOST" "echo 'PING'" >/dev/null 2>&1; then
            echo "STATUS:DISCONNECTED" > "$PIPE_STATUS"
            break
        fi
        
        # 检查是否有新命令（使用锁文件避免竞争）
        if [ ! -f "$LOCK_FILE" ]; then
            # 检查输入文件是否有内容且不为空
            if [ -s "$PIPE_IN" ]; then
                # 创建锁文件
                touch "$LOCK_FILE"
                
                # 读取命令
                command=$(cat "$PIPE_IN")
                
                # 清空输入文件
                > "$PIPE_IN"
                
                # 移除锁文件
                rm -f "$LOCK_FILE"
                
                # 跳过空命令
                if [ -z "$command" ]; then
                    continue
                fi
                
                # 特殊命令处理
                if [ "$command" = "__PING__" ]; then
                    echo "PONG:$(date)" >> "$PIPE_OUT"
                    continue
                fi

                if [ "$command" = "__STATUS__" ]; then
                    echo "STATUS:RUNNING" >> "$PIPE_OUT"
                    continue
                fi

                # AI_RUN命令处理：__AI_RUN__:order_id:cmd_file:result_file:timeout
                if [[ "$command" == __AI_RUN__:* ]]; then
                    # 解析AI_RUN命令参数
                    IFS=':' read -r __ order_id cmd_file result_file timeout <<< "$command"

                    echo "AI_RUN: 处理订单 $order_id" >> "$PIPE_OUT"

                    # 检查命令文件是否存在
                    if [ ! -f "$cmd_file" ]; then
                        echo "AI_RUN ERROR: 命令文件不存在 $cmd_file" >> "$PIPE_OUT"
                        continue
                    fi

                    # 读取实际命令（从JSON文件中提取）
                    actual_command=""
                    if command -v jq >/dev/null 2>&1; then
                        # 有jq，使用jq解析
                        actual_command=$(jq -r '.command // ""' "$cmd_file" 2>/dev/null || echo "")
                    else
                        # 没有jq，简单解析（假设命令在command字段中）
                        actual_command=$(grep '"command"' "$cmd_file" | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
                    fi

                    if [ -z "$actual_command" ]; then
                        echo "1" > "$result_file"
                        echo "AI_RUN ERROR: 无法解析命令" >> "$PIPE_OUT"
                        continue
                    fi

                    echo "AI_RUN: 执行命令: $actual_command" >> "$PIPE_OUT"

                    # 执行命令并捕获输出和退出码
                    output=""
                    exit_code=0

                    # 设置超时（如果系统支持timeout命令）
                    if command -v timeout >/dev/null 2>&1 && [ "$timeout" -gt 0 ]; then
                        output=$(timeout "$timeout" ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_HOST" "$actual_command" 2>&1)
                        exit_code=$?
                        if [ $exit_code -eq 124 ]; then
                            output="${output}"$'\n'"命令执行超时 (${timeout}秒)"
                        fi
                    else
                        output=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_HOST" "$actual_command" 2>&1)
                        exit_code=$?
                    fi

                    # 写入结果文件（JSON格式）
                    if command -v jq >/dev/null 2>&1; then
                        # 有jq，使用JSON格式
                        jq -n \
                            --arg id "$order_id" \
                            --arg command "$actual_command" \
                            --arg output "$output" \
                            --argjson exit_code "$exit_code" \
                            --arg timestamp "$(date -Iseconds)" \
                            '{
                                id: $id,
                                command: $command,
                                output: $output,
                                exit_code: $exit_code,
                                timestamp: $timestamp
                            }' > "$result_file"
                    else
                        # 没有jq，使用简单格式：EXIT_CODE\nOUTPUT
                        echo "$exit_code" > "$result_file"
                        echo "$output" >> "$result_file"
                    fi

                    echo "AI_RUN: 命令完成，退出码: $exit_code，结果写入: $result_file" >> "$PIPE_OUT"
                    continue
                fi
                
                # 执行命令并捕获输出
                echo "EXEC: $command" >> "$PIPE_OUT"
                if ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_HOST" "$command" >> "$PIPE_OUT" 2>&1; then
                    echo "== exit=0 ==" >> "$PIPE_OUT"
                else
                    echo "== exit=1 ==" >> "$PIPE_OUT"
                fi
                echo "---" >> "$PIPE_OUT"
            fi
        fi
        
        # 短暂休眠避免CPU占用过高
        sleep 0.5
    done
    
    echo "SSH连接断开，5秒后重连..."
    sleep 5
done