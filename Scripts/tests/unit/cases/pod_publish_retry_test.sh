#!/usr/bin/env bash
set -euo pipefail

# @description pod_publish.sh 重试逻辑测试
# @test is_permanent_trunk_error 永久/瞬态错误分类

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

# ============================================================================
# 测试环境设置
# ============================================================================

# 提取 is_permanent_trunk_error 函数（避免加载整个模块的依赖）
_extract_function() {
    local file="$1"
    local func="$2"
    awk "/^${func}\\(\\)/,/^}/" "$file"
}

eval "$(_extract_function "$REPO_ROOT/Scripts/release/publish/pods/lib/pod_publish.sh" "is_permanent_trunk_error")"

_make_log() {
    local tmpfile
    tmpfile=$(mktemp)
    echo "$1" > "$tmpfile"
    echo "$tmpfile"
}

# ============================================================================
# 永久错误测试（应返回 0 = 不重试）
# ============================================================================

test_permanent_already_exists() {
    local f; f=$(_make_log "ERROR: This version already exists on Trunk")
    assert_exit_code 0 is_permanent_trunk_error "$f"
    rm -f "$f"
}

test_permanent_validation_failed() {
    local f; f=$(_make_log "The spec did not pass validation")
    assert_exit_code 0 is_permanent_trunk_error "$f"
    rm -f "$f"
}

test_permanent_duplicate_entry() {
    local f; f=$(_make_log "Unable to accept duplicate entry for MSPCore (1.0.0)")
    assert_exit_code 0 is_permanent_trunk_error "$f"
    rm -f "$f"
}

# ============================================================================
# 瞬态错误测试（应返回 1 = 可重试）
# ============================================================================

test_transient_server_error() {
    local f; f=$(_make_log "An internal server error occurred")
    assert_exit_code 1 is_permanent_trunk_error "$f"
    rm -f "$f"
}

test_transient_timeout() {
    local f; f=$(_make_log "Net::ReadTimeout: timed out after 60 seconds")
    assert_exit_code 1 is_permanent_trunk_error "$f"
    rm -f "$f"
}

test_transient_cdn_failure() {
    local f; f=$(_make_log "CDN: trunk.cocoapods.org is temporarily unavailable")
    assert_exit_code 1 is_permanent_trunk_error "$f"
    rm -f "$f"
}

test_transient_empty_log() {
    local f; f=$(_make_log "")
    assert_exit_code 1 is_permanent_trunk_error "$f"
    rm -f "$f"
}

# ============================================================================
# 运行测试
# ============================================================================

info "Running pod publish retry tests..."

test_permanent_already_exists
test_permanent_validation_failed
test_permanent_duplicate_entry
test_transient_server_error
test_transient_timeout
test_transient_cdn_failure
test_transient_empty_log

echo ""
info "All pod publish retry tests passed!"
