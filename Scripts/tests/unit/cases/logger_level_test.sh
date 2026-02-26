#!/usr/bin/env bash
set -euo pipefail

# @description logger.sh 日志级别过滤测试
# @test MSP_LOG_LEVEL 控制日志输出过滤

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# ============================================================================
# 测试环境设置
# ============================================================================

mock_init
mkdir -p "${TEST_TMPDIR}/logs"

export MSP_LOG_FILE="${TEST_TMPDIR}/logs/test.log"
export MSP_METRICS_FILE="${TEST_TMPDIR}/logs/metrics.json"
export MSP_LOG_CONSOLE="false"
export MSP_LOG_FILE_ENABLED="true"
export MSP_LOG_JSON="false"
export NO_ANSI="true"

# 初始设置为 DEBUG 级别
export MSP_LOG_LEVEL=0

# Source logger.sh
# First unset the guard variable to ensure fresh source (needed when run via test runner)
unset MSP_LOGGER_LOADED
# shellcheck source=/dev/null
source "${REPO_ROOT}/Scripts/release/utils/logger.sh"

clear_log() {
    rm -f "${TEST_TMPDIR}/logs/test.log"
    touch "${TEST_TMPDIR}/logs/test.log"
}

# ============================================================================
# 测试: DEBUG 级别 (显示所有)
# ============================================================================

test_log_level_debug_shows_all() {
    clear_log
    export MSP_LOG_LEVEL=0  # DEBUG

    log::debug "TEST" "Debug message"
    log::info "TEST" "Info message"
    log::warn "TEST" "Warn message"
    log::error "TEST" "Error message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[DEBUG]" "DEBUG 级别应该显示 DEBUG 日志"
    assert_contains "$log_content" "[INFO]" "DEBUG 级别应该显示 INFO 日志"
    assert_contains "$log_content" "[WARN]" "DEBUG 级别应该显示 WARN 日志"
    assert_contains "$log_content" "[ERROR]" "DEBUG 级别应该显示 ERROR 日志"

    info "LOG_LEVEL=DEBUG 显示所有日志"
}

# ============================================================================
# 测试: INFO 级别 (隐藏 DEBUG)
# ============================================================================

test_log_level_info_hides_debug() {
    clear_log
    export MSP_LOG_LEVEL=1  # INFO

    log::debug "TEST" "Debug message"
    log::info "TEST" "Info message"
    log::warn "TEST" "Warn message"
    log::error "TEST" "Error message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_not_contains "$log_content" "Debug message" "INFO 级别应该隐藏 DEBUG 日志"
    assert_contains "$log_content" "[INFO]" "INFO 级别应该显示 INFO 日志"
    assert_contains "$log_content" "[WARN]" "INFO 级别应该显示 WARN 日志"
    assert_contains "$log_content" "[ERROR]" "INFO 级别应该显示 ERROR 日志"

    info "LOG_LEVEL=INFO 隐藏 DEBUG 日志"
}

# ============================================================================
# 测试: WARN 级别 (隐藏 DEBUG 和 INFO)
# ============================================================================

test_log_level_warn_hides_info() {
    clear_log
    export MSP_LOG_LEVEL=2  # WARN

    log::debug "TEST" "Debug message"
    log::info "TEST" "Info message"
    log::warn "TEST" "Warn message"
    log::error "TEST" "Error message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_not_contains "$log_content" "Debug message" "WARN 级别应该隐藏 DEBUG 日志"
    assert_not_contains "$log_content" "Info message" "WARN 级别应该隐藏 INFO 日志"
    assert_contains "$log_content" "[WARN]" "WARN 级别应该显示 WARN 日志"
    assert_contains "$log_content" "[ERROR]" "WARN 级别应该显示 ERROR 日志"

    info "LOG_LEVEL=WARN 隐藏 DEBUG 和 INFO 日志"
}

# ============================================================================
# 测试: ERROR 级别 (只显示 ERROR 和 FATAL)
# ============================================================================

test_log_level_error_only() {
    clear_log
    export MSP_LOG_LEVEL=3  # ERROR

    log::debug "TEST" "Debug message"
    log::info "TEST" "Info message"
    log::warn "TEST" "Warn message"
    log::error "TEST" "Error message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_not_contains "$log_content" "Debug message" "ERROR 级别应该隐藏 DEBUG 日志"
    assert_not_contains "$log_content" "Info message" "ERROR 级别应该隐藏 INFO 日志"
    assert_not_contains "$log_content" "Warn message" "ERROR 级别应该隐藏 WARN 日志"
    assert_contains "$log_content" "[ERROR]" "ERROR 级别应该显示 ERROR 日志"

    info "LOG_LEVEL=ERROR 只显示 ERROR 日志"
}

# ============================================================================
# 测试: FATAL 级别 (只显示 FATAL)
# ============================================================================

test_log_level_fatal_only() {
    clear_log
    export MSP_LOG_LEVEL=4  # FATAL

    log::debug "TEST" "Debug message"
    log::info "TEST" "Info message"
    log::warn "TEST" "Warn message"
    log::error "TEST" "Error message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_not_contains "$log_content" "Debug message" "FATAL 级别应该隐藏 DEBUG 日志"
    assert_not_contains "$log_content" "Info message" "FATAL 级别应该隐藏 INFO 日志"
    assert_not_contains "$log_content" "Warn message" "FATAL 级别应该隐藏 WARN 日志"
    assert_not_contains "$log_content" "Error message" "FATAL 级别应该隐藏 ERROR 日志"

    info "LOG_LEVEL=FATAL 只显示 FATAL 日志"
}

# ============================================================================
# 测试: log::success 在不同级别的行为
# ============================================================================

test_log_success_behavior() {
    # log::success 使用 INFO 级别

    # 在 INFO 级别应该显示
    clear_log
    export MSP_LOG_LEVEL=1
    log::success "TEST" "Success message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")
    assert_contains "$log_content" "[SUCCESS]" "INFO 级别应该显示 SUCCESS 日志"

    # 在 WARN 级别应该隐藏
    clear_log
    export MSP_LOG_LEVEL=2
    log::success "TEST" "Success message"

    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")
    assert_not_contains "$log_content" "Success message" "WARN 级别应该隐藏 SUCCESS 日志"

    info "log::success 级别行为正确"
}

# ============================================================================
# 测试: 日志级别常量
# ============================================================================

test_log_level_constants_defined() {
    assert_equals "0" "${LOG_LEVEL_DEBUG:-}" "LOG_LEVEL_DEBUG 应该是 0"
    assert_equals "1" "${LOG_LEVEL_INFO:-}" "LOG_LEVEL_INFO 应该是 1"
    assert_equals "2" "${LOG_LEVEL_WARN:-}" "LOG_LEVEL_WARN 应该是 2"
    assert_equals "3" "${LOG_LEVEL_ERROR:-}" "LOG_LEVEL_ERROR 应该是 3"
    assert_equals "4" "${LOG_LEVEL_FATAL:-}" "LOG_LEVEL_FATAL 应该是 4"

    info "日志级别常量定义正确"
}

# ============================================================================
# 测试: 运行时切换日志级别
# ============================================================================

test_runtime_log_level_change() {
    clear_log
    export MSP_LOG_LEVEL=1  # INFO

    log::debug "TEST" "Debug before change"
    log::info "TEST" "Info before change"

    # 切换到 DEBUG 级别
    export MSP_LOG_LEVEL=0

    log::debug "TEST" "Debug after change"
    log::info "TEST" "Info after change"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_not_contains "$log_content" "Debug before change" "切换前 DEBUG 应该被隐藏"
    assert_contains "$log_content" "Info before change" "切换前 INFO 应该显示"
    assert_contains "$log_content" "Debug after change" "切换后 DEBUG 应该显示"
    assert_contains "$log_content" "Info after change" "切换后 INFO 应该显示"

    info "运行时日志级别切换正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 logger 日志级别过滤测试..."

test_log_level_debug_shows_all
test_log_level_info_hides_debug
test_log_level_warn_hides_info
test_log_level_error_only
test_log_level_fatal_only
test_log_success_behavior
test_log_level_constants_defined
test_runtime_log_level_change

info "logger 日志级别过滤测试全部通过！"
