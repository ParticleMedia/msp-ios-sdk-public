#!/usr/bin/env bash
set -euo pipefail

# @description logger.sh 格式输出测试
# @test log::info, log::warn, log::error 格式，JSON 输出，模块标签

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# ============================================================================
# 测试环境设置 (只运行一次)
# ============================================================================

# 创建目录结构
mock_init
mkdir -p "${TEST_TMPDIR}/logs"

# 设置日志文件路径 (在 source logger.sh 之前)
export MSP_LOG_FILE="${TEST_TMPDIR}/logs/test.log"
export MSP_METRICS_FILE="${TEST_TMPDIR}/logs/metrics.json"
export MSP_LOG_CONSOLE="false"  # 禁用控制台输出，只写文件
export MSP_LOG_FILE_ENABLED="true"
export MSP_LOG_JSON="false"
export MSP_LOG_LEVEL=0  # DEBUG level - 显示所有日志
export NO_ANSI="true"  # 禁用 ANSI 颜色，方便测试

# Source logger.sh (只执行一次)
# First unset the guard variable to ensure fresh source (needed when run via test runner)
unset MSP_LOGGER_LOADED
# shellcheck source=/dev/null
source "${REPO_ROOT}/Scripts/release/utils/logger.sh"

# 清空日志文件的辅助函数
clear_log() {
    rm -f "${TEST_TMPDIR}/logs/test.log"
    touch "${TEST_TMPDIR}/logs/test.log"
}

# ============================================================================
# 测试: 基本日志格式
# ============================================================================

test_log_info_format() {
    clear_log

    log::info "PREFLIGHT" "Checking prerequisites"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[20" "日志应该包含时间戳"
    assert_contains "$log_content" "[INFO]" "日志应该包含 INFO 级别"
    assert_contains "$log_content" "[PREFLIGHT]" "日志应该包含模块名"
    assert_contains "$log_content" "Checking prerequisites" "日志应该包含消息"

    info "log::info 格式正确"
}

test_log_warn_format() {
    clear_log

    log::warn "BUILD" "Missing optional dependency"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[WARN]" "日志应该包含 WARN 级别"
    assert_contains "$log_content" "[BUILD]" "日志应该包含模块名"
    assert_contains "$log_content" "Missing optional dependency" "日志应该包含消息"

    info "log::warn 格式正确"
}

test_log_error_format() {
    clear_log

    log::error "PUBLISH" "Failed to upload artifact"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[ERROR]" "日志应该包含 ERROR 级别"
    assert_contains "$log_content" "[PUBLISH]" "日志应该包含模块名"
    assert_contains "$log_content" "Failed to upload artifact" "日志应该包含消息"

    info "log::error 格式正确"
}

test_log_debug_format() {
    clear_log

    log::debug "VERIFY" "Checking pod version"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[DEBUG]" "日志应该包含 DEBUG 级别"
    assert_contains "$log_content" "[VERIFY]" "日志应该包含模块名"
    assert_contains "$log_content" "Checking pod version" "日志应该包含消息"

    info "log::debug 格式正确"
}

test_log_success_format() {
    clear_log

    log::success "RELEASE" "All pods published"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[SUCCESS]" "日志应该包含 SUCCESS 级别"
    assert_contains "$log_content" "[RELEASE]" "日志应该包含模块名"
    assert_contains "$log_content" "All pods published" "日志应该包含消息"

    info "log::success 格式正确"
}

# ============================================================================
# 测试: JSON 格式输出
# ============================================================================

test_json_log_format() {
    clear_log

    # 启用 JSON 格式
    local old_json="${MSP_LOG_JSON}"
    export MSP_LOG_JSON="true"

    log::info "PREFLIGHT" "Starting checks"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" '"level":"INFO"' "JSON 日志应该包含 level 字段"
    assert_contains "$log_content" '"module":"PREFLIGHT"' "JSON 日志应该包含 module 字段"
    assert_contains "$log_content" '"message":' "JSON 日志应该包含 message 字段"
    assert_contains "$log_content" '"timestamp":' "JSON 日志应该包含 timestamp 字段"

    # 恢复
    export MSP_LOG_JSON="$old_json"

    info "JSON 日志格式正确"
}

test_json_log_escapes_quotes() {
    clear_log

    local old_json="${MSP_LOG_JSON}"
    export MSP_LOG_JSON="true"

    log::info "TEST" 'Message with "quotes"'

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    # JSON 中的引号被转义为 \"
    assert_contains "$log_content" '\"quotes\"' "JSON 日志应该转义引号"

    export MSP_LOG_JSON="$old_json"

    info "JSON 日志引号转义正确"
}

# ============================================================================
# 测试: 模块标签 (Phase 模块)
# ============================================================================

test_phase_modules() {
    clear_log

    log::info "PREFLIGHT" "Phase 1"
    log::info "BUILD" "Phase 2"
    log::info "PUBLISH" "Phase 3"
    log::info "VERIFY" "Phase 4"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[PREFLIGHT]" "应该支持 PREFLIGHT 模块"
    assert_contains "$log_content" "[BUILD]" "应该支持 BUILD 模块"
    assert_contains "$log_content" "[PUBLISH]" "应该支持 PUBLISH 模块"
    assert_contains "$log_content" "[VERIFY]" "应该支持 VERIFY 模块"

    info "4 Phase 模块标签正确"
}

# ============================================================================
# 测试: 向后兼容 API
# ============================================================================

test_legacy_log_functions() {
    clear_log

    log_info "Legacy info message"
    log_error "Legacy error message"
    log_warn "Legacy warn message"
    # Note: log_step now uses new format per FR-063
    log_step "Running step 1"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[INFO]" "log_info 应该输出 INFO 级别"
    assert_contains "$log_content" "[LEGACY]" "log_info 应该使用 LEGACY 模块"
    assert_contains "$log_content" "Legacy info message" "log_info 应该输出消息"
    assert_contains "$log_content" "[ERROR]" "log_error 应该输出 ERROR 级别"
    assert_contains "$log_content" "[WARN]" "log_warn 应该输出 WARN 级别"
    # FR-063: log_step now uses [Phase X/4] [Step YY/ZZ] format
    assert_contains "$log_content" "[Phase" "log_step 应该使用新的 Phase/Step 格式"
    assert_contains "$log_content" "[Step" "log_step 应该包含 Step 信息"
    assert_contains "$log_content" "Running step 1" "log_step 应该输出消息"

    info "向后兼容 API 正确"
}

# ============================================================================
# 测试: 日志包含调用者信息
# ============================================================================

test_log_includes_caller_info() {
    clear_log

    log::info "TEST" "Message from test"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "(" "日志应该包含调用者信息开始括号"
    assert_contains "$log_content" ")" "日志应该包含调用者信息结束括号"

    info "日志调用者信息正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 logger 格式输出测试..."

test_log_info_format
test_log_warn_format
test_log_error_format
test_log_debug_format
test_log_success_format
test_json_log_format
test_json_log_escapes_quotes
test_phase_modules
test_legacy_log_functions
test_log_includes_caller_info

info "logger 格式输出测试全部通过！"
