#!/bin/bash

# ai-run 测试脚本
# 测试ai-run函数的各种功能

set -e

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 日志函数
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# 测试函数
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"

    log_test "测试: $test_name"
    log_info "执行: $command"

    if eval "$command"; then
        actual_exit_code=$?
    else
        actual_exit_code=$?
    fi

    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name (期望退出码: $expected_exit_code, 实际: $actual_exit_code)"
        return 1
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "ai-run 功能测试"
    echo "=========================================="
    echo

    # 检查必要文件
    if [[ ! -f "./ai-run.sh" ]]; then
        echo "错误: ai-run.sh 不存在"
        exit 1
    fi

    # 加载ai-run函数
    source ./ai-run.sh

    # 检查SSH小管家是否运行
    log_info "检查SSH小管家状态..."
    if ! check_ssh_daemon; then
        echo
        log_info "请先启动SSH小管家:"
        echo "  ./ssh-start.sh <hostname>"
        echo
        exit 1
    fi

    # 运行测试
    echo
    log_info "开始测试..."
    echo

    # 测试1: 基础命令
    run_test "基础命令 - whoami" 'ai_run "whoami"' 0

    # 测试2: 列出目录
    run_test "目录列表 - ls -la /tmp" 'ai_run "ls -la /tmp"' 0

    # 测试3: 带超时的测试
    run_test "超时测试 - sleep 1 (5秒超时)" 'ai_run "sleep 1" 5' 0

    # 测试4: 失败命令测试
    run_test "失败命令 - false" 'ai_run "false"; [[ $? -eq 1 ]]' 0

    # 测试5: 复杂命令
    run_test "复杂命令 - 查看系统信息" 'ai_run "uname -a && df -h | head -5"' 0

    # 测试6: 命令包含引号
    run_test "引号处理 - echo with quotes" 'ai_run "echo \"hello world\""' 0

    # 测试7: 环境变量测试
    run_test "环境变量 - SSH_SESSION" 'SSH_SESSION=0 ai_run "echo \$SSH_SESSION"' 0

    # 测试8: 调试模式
    echo
    log_info "调试模式测试:"
    DEBUG=1 ai_run "echo 'debug test'" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log_pass "调试模式测试"
    else
        log_fail "调试模式测试"
    fi

    # 显示测试结果
    echo
    echo "=========================================="
    echo "测试结果:"
    echo "  通过: $TESTS_PASSED"
    echo "  失败: $TESTS_FAILED"
    echo "  总计: $((TESTS_PASSED + TESTS_FAILED))"
    echo "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}所有测试通过！${NC}"
        exit 0
    else
        echo -e "${RED}有 $TESTS_FAILED 个测试失败${NC}"
        exit 1
    fi
}

# 帮助信息
show_help() {
    cat << EOF
test-ai-run.sh - ai-run 功能测试脚本

用法:
    ./test-ai-run.sh

功能:
    - 测试ai-run函数的各种使用场景
    - 验证错误处理和超时机制
    - 检查与SSH小管家的集成

前提条件:
    - SSH小管家必须正在运行
    - ai-run.sh 必须存在

EOF
}

# 处理命令行参数
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# 执行主函数
main "$@"