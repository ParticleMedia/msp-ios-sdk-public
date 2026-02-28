#!/usr/bin/env bash
set -euo pipefail

# @description NovaCore Config.plist SDKVersion 更新逻辑测试
# @test release_orchestration.sh 发布适配器时更新 NovaCore Config.plist SDKVersion

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

ORCH_SH="$REPO_ROOT/Scripts/release/publish/pods/lib/release_orchestration.sh"

# ============================================================================
# 代码存在性测试
# ============================================================================

test_nova_version_update_exists() {
    local found
    found=$(grep -c 'update_novacore_config_plist_version' "$ORCH_SH")
    assert_not_equals "0" "$found" "NovaCore Config.plist version update logic should exist"
}

test_calls_version_update_function() {
    local found
    found=$(grep -c 'update_novacore_config_plist_version "\$sync_version"' "$ORCH_SH")
    assert_not_equals "0" "$found" "should call update_novacore_config_plist_version with sync_version"
}

test_targets_novacore_config_path() {
    local found
    found=$(grep -c 'NBResourceBundle.bundle/Config.plist' "$REPO_ROOT/Scripts/release/utils/version.sh")
    assert_not_equals "0" "$found" "should target NovaCore NBResourceBundle Config.plist"
}

test_uses_sdk_version_ssot() {
    local found
    found=$(grep -c 'set_sdk_version_in_config "\$VERSION"' "$ORCH_SH")
    assert_not_equals "0" "$found" "should update sdk version SSOT file before sync"
}

test_failure_is_nonfatal() {
    local found
    found=$(grep -c 'Failed to update Config.plist SDKVersion (non-fatal)' "$ORCH_SH")
    assert_not_equals "0" "$found" "NovaCore Config.plist version update failure should be non-fatal"
}

# ============================================================================
# 运行测试
# ============================================================================

info "Running NovaCore Config.plist version update tests..."

test_nova_version_update_exists
test_calls_version_update_function
test_targets_novacore_config_path
test_uses_sdk_version_ssot
test_failure_is_nonfatal

echo ""
info "All NovaCore Config.plist version update tests passed!"
