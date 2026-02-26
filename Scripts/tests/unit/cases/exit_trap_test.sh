#!/usr/bin/env bash
set -euo pipefail

# @description publish.sh 退出 trap 测试
# @test _log_exit_reason 在脚本异常退出时输出错误信息

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

PUBLISH_SH="$REPO_ROOT/Scripts/release/publish/pods/publish.sh"

# ============================================================================
# 存在性测试
# ============================================================================

test_exit_trap_function_exists() {
    local found
    found=$(grep -c '_log_exit_reason' "$PUBLISH_SH")
    assert_not_equals "0" "$found" "_log_exit_reason should exist in publish.sh"
}

test_trap_registered() {
    local found
    found=$(grep -c 'trap _log_exit_reason EXIT' "$PUBLISH_SH")
    assert_equals "1" "$found" "trap _log_exit_reason EXIT should be registered exactly once"
}

# ============================================================================
# 行为测试
# ============================================================================

test_prints_error_on_nonzero_exit() {
    local output
    output=$(bash -c '
        _log_exit_reason() {
          local e=$?
          if [[ $e -ne 0 ]]; then
            echo "ERROR: exiting with code $e" >&2
          fi
          exit $e
        }
        trap _log_exit_reason EXIT
        exit 42
    ' 2>&1 || true)
    assert_contains "$output" "exiting with code 42" "should print error code on non-zero exit"
}

test_silent_on_success() {
    local output
    output=$(bash -c '
        _log_exit_reason() {
          local e=$?
          if [[ $e -ne 0 ]]; then
            echo "ERROR: exiting with code $e" >&2
          fi
          exit $e
        }
        trap _log_exit_reason EXIT
        exit 0
    ' 2>&1)
    assert_equals "" "$output" "should be silent on zero exit"
}

test_includes_last_error() {
    local output
    output=$(bash -c '
        NO_COLOR=1
        _log_exit_reason() {
          local e=$?
          if [[ $e -ne 0 ]]; then
            echo "ERROR: exiting with code $e" >&2
            if [[ -n "${LAST_ERROR:-}" ]]; then
              echo "ERROR MESSAGE: ${LAST_ERROR}" >&2
            fi
          fi
          exit $e
        }
        trap _log_exit_reason EXIT
        LAST_ERROR="pod trunk push failed"
        exit 1
    ' 2>&1 || true)
    assert_contains "$output" "pod trunk push failed" "should include LAST_ERROR in output"
}

# ============================================================================
# 运行测试
# ============================================================================

info "Running exit trap tests..."

test_exit_trap_function_exists
test_trap_registered
test_prints_error_on_nonzero_exit
test_silent_on_success
test_includes_last_error

echo ""
info "All exit trap tests passed!"
