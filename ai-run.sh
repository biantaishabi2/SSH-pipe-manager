#!/bin/bash

# ai-run - 同步SSH命令执行器
# 用法: ai-run "远程命令" [可选：超时秒数]
# 功能: 一步完成"写→等→读→返回"的SSH调用

set -euo pipefail

# 默认超时时间（秒）
DEFAULT_TIMEOUT=30

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# 检查SSH小管家是否运行
check_ssh_daemon() {
    local session_id="${SSH_SESSION:-0}"
    local pipe_in="/tmp/ssh-${session_id}.in"

    if [[ ! -p "$pipe_in" ]]; then
        log_error "SSH小管家未运行，管道文件不存在: $pipe_in"
        log_info "请先启动: ./ssh-start.sh <hostname> [session_id]"
        return 1
    fi
}

# 清理临时文件
cleanup_temp_files() {
    local cmd_file="$1"
    local result_file="$2"

    # 延迟删除，确保结果被读取
    (sleep 1 && rm -f "$cmd_file" "$result_file" 2>/dev/null) &
}

# 主要的ai-run函数
ai_run() {
    local cmd="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local session_id="${SSH_SESSION:-0}"

    log_debug "执行命令: $cmd"
    log_debug "超时时间: ${timeout}秒"
    log_debug "会话ID: $session_id"

    # 检查命令是否为空
    if [[ -z "$cmd" ]]; then
        log_error "命令不能为空"
        return 1
    fi

    # 检查SSH小管家状态
    if ! check_ssh_daemon; then
        return 1
    fi

    # 生成唯一订单号（时间戳+随机数）
    local order_id="order-$(date +%s)-$$-${RANDOM}"
    log_debug "订单ID: $order_id"

    # 创建临时文件
    local temp_dir="/tmp"
    local cmd_file="${temp_dir}/${order_id}.cmd"
    local result_file="${temp_dir}/${order_id}.result"

    # 设置清理trap
    trap "cleanup_temp_files '$cmd_file' '$result_file'" EXIT

    # 创建命令JSON文件
    cat > "$cmd_file" << EOF
{
    "id": "$order_id",
    "command": "$cmd",
    "timestamp": "$(date -Iseconds)",
    "timeout": $timeout,
    "session_id": $session_id
}
EOF

    log_debug "创建命令文件: $cmd_file"

    # 发送命令到SSH小管家（通过管道发送特殊格式命令）
    local ssh_cmd="__AI_RUN__:${order_id}:${cmd_file}:${result_file}:${timeout}"
    echo "$ssh_cmd" > "/tmp/ssh-${session_id}.in"

    log_debug "发送命令到SSH管道"

    # 等待结果文件出现（带超时）
    local wait_count=0
    local max_wait=$((timeout * 2))  # 给额外时间等待文件创建

    while [[ $wait_count -lt $max_wait ]]; do
        if [[ -f "$result_file" && -s "$result_file" ]]; then
            break
        fi
        sleep 0.1
        ((wait_count++))
    done

    # 检查是否超时
    if [[ $wait_count -ge $max_wait ]]; then
        log_error "等待结果超时 (${timeout}秒)"
        return 124  # timeout退出码
    fi

    # 读取并解析结果
    if [[ -f "$result_file" ]]; then
        local exit_code
        local output

        # 尝试解析JSON格式结果
        if command -v jq >/dev/null 2>&1; then
            # 有jq，使用jq解析
            exit_code=$(jq -r '.exit_code // 1' "$result_file" 2>/dev/null || echo 1)
            output=$(jq -r '.output // ""' "$result_file" 2>/dev/null || echo "")
        else
            # 没有jq，简单解析（假设格式为: EXIT_CODE\nOUTPUT）
            exit_code=$(head -n1 "$result_file" 2>/dev/null || echo 1)
            output=$(tail -n +2 "$result_file" 2>/dev/null || echo "")
        fi

        # 输出结果
        if [[ -n "$output" ]]; then
            echo "$output"
        fi

        log_debug "命令执行完成，退出码: $exit_code"
        return "$exit_code"
    else
        log_error "结果文件未创建: $result_file"
        return 1
    fi
}

# 帮助信息
show_help() {
    cat << EOF
ai-run - 同步SSH命令执行器

用法:
    ai-run "远程命令" [超时秒数]

参数:
    远程命令     要在远程服务器执行的命令（必需）
    超时秒数     命令执行超时时间，默认30秒（可选）

环境变量:
    SSH_SESSION  SSH会话ID，默认为0
    DEBUG        设置为1启用调试输出

示例:
    ai-run "ls -la"
    ai-run "systemctl restart nginx && systemctl status nginx" 60
    SSH_SESSION=1 ai-run "hostname"
    DEBUG=1 ai-run "pwd"

依赖:
    - SSH小管家必须先启动: ./ssh-start.sh <hostname>
    - 可选: jq (用于JSON解析)

特点:
    - 同步阻塞执行，像本地命令一样
    - 自动生成唯一订单号
    - 自动清理临时文件
    - 支持超时控制
    - 返回远程命令的退出码

EOF
}

# 主入口
main() {
    # 检查参数
    if [[ $# -eq 0 ]]; then
        show_help
        return 1
    fi

    # 处理帮助选项
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        return 0
    fi

    # 执行主函数
    ai_run "$@"
}

# 如果直接执行脚本（不是source）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# 导出函数供其他脚本使用
export -f ai_run 2>/dev/null || true