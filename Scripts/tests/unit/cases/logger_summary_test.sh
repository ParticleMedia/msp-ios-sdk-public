#!/usr/bin/env bash
set -euo pipefail

# @description logger.sh 性能指标和 Summary 输出测试
# @test metrics::start, metrics::end, metrics::record, metrics::report

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
}

clear_metrics() {
    rm -f "${TEST_TMPDIR}/logs/metrics.json"
    rm -f "${_METRICS_TMP_FILE:-}"
}

# ============================================================================
# 测试: metrics::start 和 metrics::end
# ============================================================================

test_metrics_start_end_basic() {
    clear_log
    clear_metrics

    metrics::start "test_operation"
    sleep 0.1
    metrics::end "test_operation"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "Started timing: test_operation" "应该记录开始计时"
    assert_contains "$log_content" "Completed: test_operation" "应该记录完成计时"

    info "metrics::start/end 基本功能正确"
}

test_metrics_end_without_start() {
    clear_log
    clear_metrics

    metrics::end "nonexistent_operation" || true

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "No start time found" "应该警告找不到开始时间"

    info "metrics::end 无开始时间警告正确"
}

test_metrics_multiple_operations() {
    clear_log
    clear_metrics

    metrics::start "operation_a"
    metrics::start "operation_b"

    sleep 0.05
    metrics::end "operation_a"

    sleep 0.05
    metrics::end "operation_b"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "Completed: operation_a" "应该完成 operation_a"
    assert_contains "$log_content" "Completed: operation_b" "应该完成 operation_b"

    info "多个并行操作计时正确"
}

# ============================================================================
# 测试: metrics::record
# ============================================================================

test_metrics_record_basic() {
    clear_log
    clear_metrics

    metrics::record "pods_published" 5 "count"
    metrics::record "build_size" 1024 "bytes"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "Recorded: pods_published = 5" "应该记录 pods_published"
    assert_contains "$log_content" "Recorded: build_size = 1024" "应该记录 build_size"

    info "metrics::record 基本功能正确"
}

test_metrics_record_writes_to_file() {
    clear_log
    clear_metrics

    metrics::record "test_metric" 42 "items"

    local metrics_content
    metrics_content=$(cat "${TEST_TMPDIR}/logs/metrics.json")

    assert_contains "$metrics_content" '"metric":"test_metric"' "Metrics 文件应该包含 metric 名称"
    assert_contains "$metrics_content" '"value":42' "Metrics 文件应该包含 value"
    assert_contains "$metrics_content" '"unit":"items"' "Metrics 文件应该包含 unit"

    info "metrics::record 写入文件正确"
}

# ============================================================================
# 测试: metrics::report
# ============================================================================

test_metrics_report_header() {
    clear_log
    clear_metrics

    metrics::start "preflight"
    sleep 0.05
    metrics::end "preflight"

    local report
    report=$(metrics::report)

    assert_contains "$report" "PERFORMANCE METRICS REPORT" "报告应该包含标题"
    assert_contains "$report" "Operation" "报告应该包含 Operation 列"
    assert_contains "$report" "Duration" "报告应该包含 Duration 列"

    info "metrics::report 报告头部正确"
}

test_metrics_report_shows_operations() {
    clear_log
    clear_metrics

    metrics::start "build_pods"
    sleep 0.05
    metrics::end "build_pods"

    metrics::start "publish_pods"
    sleep 0.05
    metrics::end "publish_pods"

    local report
    report=$(metrics::report)

    assert_contains "$report" "build_pods" "报告应该包含 build_pods"
    assert_contains "$report" "publish_pods" "报告应该包含 publish_pods"

    info "metrics::report 显示操作正确"
}

test_metrics_report_shows_total() {
    clear_log
    clear_metrics

    metrics::start "operation1"
    sleep 0.05
    metrics::end "operation1"

    local report
    report=$(metrics::report)

    assert_contains "$report" "TOTAL" "报告应该包含 TOTAL"

    info "metrics::report 显示总计正确"
}

test_metrics_report_empty() {
    clear_log
    clear_metrics

    local report
    report=$(metrics::report)

    assert_contains "$report" "No metrics collected" "空报告应该显示 'No metrics collected'"

    info "metrics::report 空报告正确"
}

# ============================================================================
# 测试: metrics::save
# ============================================================================

test_metrics_save_creates_json() {
    clear_log
    clear_metrics

    metrics::start "save_test"
    sleep 0.05
    metrics::end "save_test"

    metrics::save

    local metrics_content
    metrics_content=$(cat "${TEST_TMPDIR}/logs/metrics.json")

    assert_contains "$metrics_content" '"durations"' "保存的 JSON 应该包含 durations"
    assert_contains "$metrics_content" '"timestamp"' "保存的 JSON 应该包含 timestamp"

    info "metrics::save 创建 JSON 正确"
}

test_metrics_save_logs_success() {
    clear_log
    clear_metrics

    metrics::start "test_op"
    metrics::end "test_op"
    metrics::save

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "Metrics saved successfully" "应该记录保存成功"

    info "metrics::save 日志记录正确"
}

# ============================================================================
# 测试: 4 Phase 完整流程
# ============================================================================

test_four_phase_metrics_flow() {
    clear_log
    clear_metrics

    # Phase 1: Preflight
    log::info "PREFLIGHT" "Starting preflight checks"
    metrics::start "preflight"
    sleep 0.02
    metrics::end "preflight"
    log::success "PREFLIGHT" "Preflight completed"

    # Phase 2: Build
    log::info "BUILD" "Starting build"
    metrics::start "build"
    sleep 0.02
    metrics::end "build"
    log::success "BUILD" "Build completed"

    # Phase 3: Publish
    log::info "PUBLISH" "Starting publish"
    metrics::start "publish"
    sleep 0.02
    metrics::end "publish"
    log::success "PUBLISH" "Publish completed"

    # Phase 4: Verify
    log::info "VERIFY" "Starting verification"
    metrics::start "verify"
    sleep 0.02
    metrics::end "verify"
    log::success "VERIFY" "Verification completed"

    local report
    report=$(metrics::report)

    assert_contains "$report" "preflight" "报告应该包含 preflight"
    assert_contains "$report" "build" "报告应该包含 build"
    assert_contains "$report" "publish" "报告应该包含 publish"
    assert_contains "$report" "verify" "报告应该包含 verify"

    info "4 Phase 完整流程正确"
}

# ============================================================================
# 测试: 嵌套操作计时
# ============================================================================

test_nested_operations_timing() {
    clear_log
    clear_metrics

    metrics::start "outer_operation"
    metrics::start "inner_operation"
    sleep 0.02
    metrics::end "inner_operation"
    sleep 0.02
    metrics::end "outer_operation"

    local log_content
    log_content=$(cat "${TEST_TMPDIR}/logs/test.log")

    assert_contains "$log_content" "Completed: inner_operation" "内层操作应该完成"
    assert_contains "$log_content" "Completed: outer_operation" "外层操作应该完成"

    info "嵌套操作计时正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 logger Summary 和 Metrics 测试..."

test_metrics_start_end_basic
test_metrics_end_without_start
test_metrics_multiple_operations
test_metrics_record_basic
test_metrics_record_writes_to_file
test_metrics_report_header
test_metrics_report_shows_operations
test_metrics_report_shows_total
test_metrics_report_empty
test_metrics_save_creates_json
test_metrics_save_logs_success
test_four_phase_metrics_flow
test_nested_operations_timing

info "logger Summary 和 Metrics 测试全部通过！"
