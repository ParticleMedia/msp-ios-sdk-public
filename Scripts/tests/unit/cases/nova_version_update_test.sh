#!/usr/bin/env bash
set -euo pipefail

# @description NovaConstants.version 更新逻辑测试
# @test release_orchestration.sh 发布适配器时更新 NovaConstants.version

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

ORCH_SH="$REPO_ROOT/Scripts/release/publish/pods/lib/release_orchestration.sh"

# ============================================================================
# 代码存在性测试
# ============================================================================

test_nova_version_update_exists() {
    local found
    found=$(grep -c 'NovaConstants.version' "$ORCH_SH")
    assert_not_equals "0" "$found" "NovaConstants.version update logic should exist"
}

test_uses_correct_flags() {
    local found
    found=$(grep -c '\-\-function version.*\-\-pattern property' "$ORCH_SH")
    assert_not_equals "0" "$found" "should use --function version --pattern property flags"
}

test_targets_novacore_dir() {
    local found
    found=$(grep -c 'Sources/Core/NovaCore/NovaCore' "$ORCH_SH")
    assert_not_equals "0" "$found" "should target Sources/Core/NovaCore/NovaCore"
}

test_failure_is_nonfatal() {
    local found
    found=$(grep -c 'Failed to update NovaConstants.version (non-fatal)' "$ORCH_SH")
    assert_not_equals "0" "$found" "NovaConstants.version failure should be non-fatal"
}

test_adapter_version_tool_exists() {
    assert_file_exists "$REPO_ROOT/Scripts/tools/update_adapter_sdk_version.py" \
        "update_adapter_sdk_version.py tool should exist"
}

# ============================================================================
# 运行测试
# ============================================================================

info "Running NovaConstants.version update tests..."

test_nova_version_update_exists
test_uses_correct_flags
test_targets_novacore_dir
test_failure_is_nonfatal
test_adapter_version_tool_exists

echo ""
info "All NovaConstants.version update tests passed!"
