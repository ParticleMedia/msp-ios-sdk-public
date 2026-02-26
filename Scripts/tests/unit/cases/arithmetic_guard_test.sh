#!/usr/bin/env bash
set -euo pipefail

# @description ((x++)) || true 防护测试
# @test 确保 set -euo pipefail 下 ((0++)) 不会杀掉脚本

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

# ============================================================================
# 行为验证测试
# ============================================================================

# Test: ((0++)) || true 不会在 set -euo pipefail 下崩溃
test_zero_increment_safe() {
    local x=0
    ((x++)) || true
    assert_equals "1" "$x" "((0++)) || true should increment x from 0 to 1"
}

# Test: ((x++)) || true 对非零值正常工作
test_nonzero_increment_safe() {
    local x=5
    ((x++)) || true
    assert_equals "6" "$x" "((5++)) || true should increment x to 6"
}

# ============================================================================
# 全目录扫描测试
# ============================================================================

# Test: Scripts/release/ 无未防护的 ((x++))
test_no_unguarded_in_release() {
    local unguarded
    unguarded=$(grep -rn '(([a-z_]*++))$' "$REPO_ROOT/Scripts/release/" 2>/dev/null || echo "")
    assert_equals "" "$unguarded" "No unguarded ((x++)) in Scripts/release/"
}

# Test: Scripts/lib/ 无未防护的 ((x++))
test_no_unguarded_in_lib() {
    local unguarded
    unguarded=$(grep -rn '(([a-z_]*++))$' "$REPO_ROOT/Scripts/lib/" 2>/dev/null || echo "")
    assert_equals "" "$unguarded" "No unguarded ((x++)) in Scripts/lib/"
}

# Test: Scripts/ci/ 无未防护的 ((x++))
test_no_unguarded_in_ci() {
    local unguarded
    unguarded=$(grep -rn '(([a-z_]*++))$' "$REPO_ROOT/Scripts/ci/" 2>/dev/null || echo "")
    assert_equals "" "$unguarded" "No unguarded ((x++)) in Scripts/ci/"
}

# Test: 无双重 || true 防护
test_no_double_guard() {
    local bad_pattern
    bad_pattern=$(grep -rn '(([a-z_]*++)) || true || true' "$REPO_ROOT/Scripts/" 2>/dev/null || echo "")
    assert_equals "" "$bad_pattern" "No double || true guards"
}

# ============================================================================
# 运行测试
# ============================================================================

info "Running arithmetic guard tests..."

test_zero_increment_safe
test_nonzero_increment_safe
test_no_unguarded_in_release
test_no_unguarded_in_lib
test_no_unguarded_in_ci
test_no_double_guard

echo ""
info "All arithmetic guard tests passed!"
