#!/usr/bin/env bash
set -euo pipefail

# @description logger.sh Phase/Step logging 测试 (FR-062~065)
# @test log_phase_start, log_phase_end, log_step, log_summary

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
export MSP_LOG_LEVEL=0  # DEBUG
export NO_ANSI="true"

# Source logger.sh
# First unset the guard variable to ensure fresh source (needed when run via test runner)
unset MSP_LOGGER_LOADED
# shellcheck source=/dev/null
source "${REPO_ROOT}/Scripts/release/utils/logger.sh"

clear_log() {
    rm -f "${TEST_TMPDIR}/logs/test.log"
    touch "${TEST_TMPDIR}/logs/test.log"
    _reset_phase_tracking
}

# ============================================================================
# 测试: Phase 常量
# ============================================================================

test_phase_constants() {
    assert_equals "1" "$PHASE_PREFLIGHT" "PHASE_PREFLIGHT 应该是 1"
    assert_equals "2" "$PHASE_BUILD" "PHASE_BUILD 应该是 2"
    assert_equals "3" "$PHASE_PUBLISH" "PHASE_PUBLISH 应该是 3"
    assert_equals "4" "$PHASE_VERIFY" "PHASE_VERIFY 应该是 4"
    assert_equals "4" "$PHASE_TOTAL" "PHASE_TOTAL 应该是 4"

    info "Phase 常量定义正确"
}

test_get_phase_name() {
    local name
    name=$(_get_phase_name 1)
    assert_equals "Preflight" "$name" "Phase 1 应该是 Preflight"

    name=$(_get_phase_name 2)
    assert_equals "Build" "$name" "Phase 2 应该是 Build"

    name=$(_get_phase_name 3)
    assert_equals "Publish" "$name" "Phase 3 应该是 Publish"

    name=$(_get_phase_name 4)
    assert_equals "Verify" "$name" "Phase 4 应该是 Verify"

    info "Phase 名称获取正确"
}

test_get_phase_step_count() {
    local count
    count=$(_get_phase_step_count 1)
    assert_equals "5" "$count" "Preflight 应该有 5 步"

    count=$(_get_phase_step_count 2)
    assert_equals "5" "$count" "Build 应该有 5 步"

    count=$(_get_phase_step_count 3)
    assert_equals "14" "$count" "Publish 应该有 14 步"

    count=$(_get_phase_step_count 4)
    assert_equals "6" "$count" "Verify 应该有 6 步"

    info "Phase 步骤数量正确"
}

# ============================================================================
# 测试: log_phase_start (FR-064)
# ============================================================================

test_log_phase_start_outputs_separator() {
    clear_log

    log_phase_start 1

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    # FR-064: Phase 开始应该有分隔线
    assert_contains "$log_content" "═══" "Phase 开始应该有分隔线"
    assert_contains "$log_content" "Phase 1/4" "应该显示 Phase 1/4"
    assert_contains "$log_content" "Preflight" "应该显示 Phase 名称"

    info "log_phase_start 输出分隔线正确"
}

test_log_phase_start_sets_current_phase() {
    clear_log

    log_phase_start 2

    assert_equals "2" "$_CURRENT_PHASE" "_CURRENT_PHASE 应该被设置为 2"
    assert_equals "0" "$_CURRENT_STEP" "_CURRENT_STEP 应该被重置为 0"

    info "log_phase_start 设置当前 Phase 正确"
}

test_log_phase_start_starts_metrics() {
    clear_log

    log_phase_start 1
    sleep 0.05
    log_phase_end "success"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "Completed: phase_1_preflight" "应该记录 Phase 计时"

    info "log_phase_start 启动计时正确"
}

# ============================================================================
# 测试: log_phase_end (FR-064)
# ============================================================================

test_log_phase_end_success() {
    clear_log

    log_phase_start 1
    log_phase_end "success"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "COMPLETED" "应该显示 COMPLETED"
    assert_contains "$log_content" "───" "应该有结束分隔线"

    info "log_phase_end success 状态正确"
}

test_log_phase_end_failed() {
    clear_log

    log_phase_start 2
    log_phase_end "failed"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "FAILED" "应该显示 FAILED"

    info "log_phase_end failed 状态正确"
}

test_log_phase_end_skipped() {
    clear_log

    log_phase_start 4
    log_phase_end "skipped"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "SKIPPED" "应该显示 SKIPPED"

    info "log_phase_end skipped 状态正确"
}

test_log_phase_end_records_duration() {
    clear_log

    log_phase_start 1
    sleep 0.05
    log_phase_end "success"

    local duration
    duration=$(_get_phase_duration 1)

    # Duration should be >= 40ms (we slept for 50ms)
    if [[ $duration -ge 40 ]]; then
        : # Pass
    else
        fail "Phase duration 应该 >= 40ms, 实际: ${duration}ms"
    fi

    info "log_phase_end 记录耗时正确"
}

# ============================================================================
# 测试: log_step (FR-063)
# ============================================================================

test_log_step_format() {
    clear_log

    _CURRENT_PHASE=1
    log_step "INFO" "Running git status check"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    # FR-063: 格式应该是 [Phase X/4] [Step YY/ZZ] [LEVEL] message
    assert_contains "$log_content" "[Phase 1/4]" "应该包含 Phase 信息"
    assert_contains "$log_content" "[Step 01/05]" "应该包含 Step 信息"
    assert_contains "$log_content" "[INFO]" "应该包含日志级别"
    assert_contains "$log_content" "Running git status check" "应该包含消息"

    info "log_step 格式正确 (FR-063)"
}

test_log_step_auto_increment() {
    clear_log

    _CURRENT_PHASE=2
    _CURRENT_STEP=0

    log_step "INFO" "Step 1"
    log_step "INFO" "Step 2"
    log_step "INFO" "Step 3"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[Step 01/05]" "第一步应该是 01"
    assert_contains "$log_content" "[Step 02/05]" "第二步应该是 02"
    assert_contains "$log_content" "[Step 03/05]" "第三步应该是 03"

    info "log_step 自动递增正确"
}

test_log_step_manual_step_number() {
    clear_log

    _CURRENT_PHASE=3
    log_step "INFO" "Manual step" 5

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[Step 05/14]" "手动指定步骤号应该是 05"

    info "log_step 手动步骤号正确"
}

test_log_step_convenience_functions() {
    clear_log

    _CURRENT_PHASE=1
    _CURRENT_STEP=0

    log_step_info "Info message"
    log_step_warn "Warn message"
    log_step_error "Error message"
    log_step_success "Success message"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "[INFO]" "log_step_info 应该输出 INFO"
    assert_contains "$log_content" "[WARN]" "log_step_warn 应该输出 WARN"
    assert_contains "$log_content" "[ERROR]" "log_step_error 应该输出 ERROR"
    assert_contains "$log_content" "[SUCCESS]" "log_step_success 应该输出 SUCCESS"

    info "log_step 便捷函数正确"
}

# ============================================================================
# 测试: log_summary (FR-065)
# ============================================================================

test_log_summary_shows_all_phases() {
    clear_log

    # Simulate completed release
    _set_phase_status 1 "success"
    _set_phase_status 2 "success"
    _set_phase_status 3 "success"
    _set_phase_status 4 "skipped"
    _set_phase_duration 1 1000
    _set_phase_duration 2 2000
    _set_phase_duration 3 3000
    _set_phase_duration 4 0

    local summary
    summary=$(log_summary "success")

    assert_contains "$summary" "RELEASE SUMMARY" "应该显示标题"
    assert_contains "$summary" "Phase 1/4" "应该显示 Phase 1"
    assert_contains "$summary" "Phase 2/4" "应该显示 Phase 2"
    assert_contains "$summary" "Phase 3/4" "应该显示 Phase 3"
    assert_contains "$summary" "Phase 4/4" "应该显示 Phase 4"
    assert_contains "$summary" "PASS" "成功的 Phase 应该显示 PASS"
    assert_contains "$summary" "SKIP" "跳过的 Phase 应该显示 SKIP"

    info "log_summary 显示所有 Phase 正确"
}

test_log_summary_shows_total_time() {
    clear_log

    _set_phase_status 1 "success"
    _set_phase_status 2 "success"
    _set_phase_duration 1 1000
    _set_phase_duration 2 2000

    local summary
    summary=$(log_summary "success")

    assert_contains "$summary" "TOTAL TIME" "应该显示总耗时"

    info "log_summary 显示总耗时正确"
}

test_log_summary_shows_final_status() {
    clear_log

    _set_phase_status 1 "success"
    _set_phase_status 2 "failed"
    _set_phase_duration 1 1000
    _set_phase_duration 2 500

    local summary
    summary=$(log_summary "failed")

    assert_contains "$summary" "RELEASE FAILED" "失败应该显示 RELEASE FAILED"

    info "log_summary 显示最终状态正确"
}

# ============================================================================
# 测试: 完整 Phase 流程
# ============================================================================

test_full_phase_workflow() {
    clear_log

    # Phase 1: Preflight
    log_phase_start 1
    log_step_info "Git status check"
    log_step_info "Branch validation"
    log_step_success "Preflight complete"
    log_phase_end "success"

    # Phase 2: Build
    log_phase_start 2
    log_step_info "Building XCFrameworks"
    log_step_success "Build complete"
    log_phase_end "success"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    # Verify Phase 1
    assert_contains "$log_content" "Phase 1/4: Preflight" "应该记录 Phase 1"
    assert_contains "$log_content" "[Phase 1/4] [Step" "应该有 Phase 1 的步骤"

    # Verify Phase 2
    assert_contains "$log_content" "Phase 2/4: Build" "应该记录 Phase 2"
    assert_contains "$log_content" "[Phase 2/4] [Step" "应该有 Phase 2 的步骤"

    # Verify Phase status
    local status1
    status1=$(_get_phase_status 1)
    assert_equals "success" "$status1" "Phase 1 状态应该是 success"

    local status2
    status2=$(_get_phase_status 2)
    assert_equals "success" "$status2" "Phase 2 状态应该是 success"

    info "完整 Phase 流程正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 logger Phase/Step 测试..."

test_phase_constants
test_get_phase_name
test_get_phase_step_count
test_log_phase_start_outputs_separator
test_log_phase_start_sets_current_phase
test_log_phase_start_starts_metrics
test_log_phase_end_success
test_log_phase_end_failed
test_log_phase_end_skipped
test_log_phase_end_records_duration
test_log_step_format
test_log_step_auto_increment
test_log_step_manual_step_number
test_log_step_convenience_functions
test_log_summary_shows_all_phases
test_log_summary_shows_total_time
test_log_summary_shows_final_status
test_full_phase_workflow

info "logger Phase/Step 测试全部通过！"
