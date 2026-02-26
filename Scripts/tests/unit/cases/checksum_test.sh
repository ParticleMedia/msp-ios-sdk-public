#!/usr/bin/env bash
set -euo pipefail

# @description checksum.sh 单元测试
# @test 验证 SHA256 计算、格式验证、文件校验等核心逻辑
# R030: Checksum calculation unification

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# ============================================================================
# 测试环境设置
# ============================================================================

mock_init
mkdir -p "${TEST_TMPDIR}/files"

# Source logger for log:: functions
export MSP_LOG_FILE="${TEST_TMPDIR}/logs/test.log"
export MSP_LOG_CONSOLE="false"
export MSP_LOG_FILE_ENABLED="true"
export MSP_LOG_LEVEL=0  # DEBUG
export NO_ANSI="true"
mkdir -p "${TEST_TMPDIR}/logs"

unset MSP_LOGGER_LOADED
source "${REPO_ROOT}/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Fallback log functions if logger not available
if ! command -v log::info &>/dev/null; then
    log::info() { :; }
    log::debug() { :; }
    log::warn() { :; }
    log::error() { :; }
    log::success() { :; }
fi

# Define test helper functions (used by tests for pass/fail logging)
test_pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# Source checksum module (unset guard first for fresh source)
unset _CHECKSUM_SOURCED
source "${REPO_ROOT}/Scripts/lib/checksum.sh"

# ============================================================================
# 测试: 模块防护
# ============================================================================

test_module_guard() {
    if [[ -n "${_CHECKSUM_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        fail "Module guard variable should be set after sourcing"
    fi
    info "模块防护变量正确"
}

# ============================================================================
# 测试: 函数存在性
# ============================================================================

test_functions_exist() {
    local funcs=(
        checksum_compute_sha256
        checksum_validate_format
        checksum_verify_file
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            fail "$fn function should exist"
        fi
    done
    info "所有函数存在性检查通过"
}

# ============================================================================
# 测试: checksum_validate_format
# ============================================================================

test_validate_format_valid() {
    local valid_hash="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
    if checksum_validate_format "$valid_hash"; then
        test_pass "Valid 64-char hex hash accepted"
    else
        fail "checksum_validate_format should accept valid hash"
    fi
    info "checksum_validate_format 有效哈希验证正确"
}

test_validate_format_invalid_short() {
    local invalid_hash="abc123"
    if ! checksum_validate_format "$invalid_hash"; then
        test_pass "Short hash rejected"
    else
        fail "checksum_validate_format should reject short hash"
    fi
    info "checksum_validate_format 短哈希拒绝正确"
}

test_validate_format_invalid_long() {
    local long_hash="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2extra"
    if ! checksum_validate_format "$long_hash"; then
        test_pass "Long hash rejected"
    else
        fail "Long hash should be rejected"
    fi
    info "checksum_validate_format 长哈希拒绝正确"
}

test_validate_format_uppercase() {
    local uppercase_hash="A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2"
    if ! checksum_validate_format "$uppercase_hash"; then
        test_pass "Uppercase hash rejected"
    else
        fail "checksum_validate_format should reject uppercase hash"
    fi
    info "checksum_validate_format 大写哈希拒绝正确"
}

test_validate_format_non_hex() {
    local non_hex_hash="g1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
    if ! checksum_validate_format "$non_hex_hash"; then
        test_pass "Non-hex hash rejected"
    else
        fail "Non-hex hash should be rejected"
    fi
    info "checksum_validate_format 非十六进制哈希拒绝正确"
}

test_validate_format_empty() {
    if ! checksum_validate_format ""; then
        test_pass "Empty string rejected"
    else
        fail "Empty string should be rejected"
    fi
    info "checksum_validate_format 空字符串拒绝正确"
}

# ============================================================================
# 测试: checksum_compute_sha256
# ============================================================================

test_compute_sha256_known_content() {
    # Create a test file with known content
    local test_file="${TEST_TMPDIR}/files/test.txt"
    echo -n "hello world" > "$test_file"

    # Known SHA256 for "hello world" (without newline)
    local expected_hash="b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"

    local actual_hash
    actual_hash=$(checksum_compute_sha256 "$test_file")

    assert_equals "$expected_hash" "$actual_hash" "SHA256 of 'hello world' should match known value"
    info "checksum_compute_sha256 已知内容计算正确"
}

test_compute_sha256_empty_file() {
    # Create an empty file
    local test_file="${TEST_TMPDIR}/files/empty.txt"
    touch "$test_file"

    # Known SHA256 for empty file
    local expected_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    local actual_hash
    actual_hash=$(checksum_compute_sha256 "$test_file")

    assert_equals "$expected_hash" "$actual_hash" "SHA256 of empty file should match known value"
    info "checksum_compute_sha256 空文件计算正确"
}

test_compute_sha256_valid_format() {
    local temp_file="${TEST_TMPDIR}/files/format_test.txt"
    echo "test content" > "$temp_file"

    local hash
    if hash=$(checksum_compute_sha256 "$temp_file"); then
        if checksum_validate_format "$hash"; then
            test_pass "checksum_compute_sha256 returns valid hash format"
        else
            fail "checksum_compute_sha256 should return valid format"
        fi
    else
        fail "checksum_compute_sha256 should succeed on valid file"
    fi
    info "checksum_compute_sha256 有效格式返回正确"
}

test_compute_sha256_missing_file() {
    if ! checksum_compute_sha256 "/nonexistent/file/path" 2>/dev/null; then
        test_pass "Nonexistent file returns error"
    else
        fail "checksum_compute_sha256 should fail on missing file"
    fi
    info "checksum_compute_sha256 不存在文件错误处理正确"
}

# ============================================================================
# 测试: checksum_verify_file
# ============================================================================

test_verify_file_matching_hash() {
    local test_file="${TEST_TMPDIR}/files/verify_match.txt"
    echo -n "test content" > "$test_file"

    # Compute actual hash
    local expected_hash
    expected_hash=$(checksum_compute_sha256 "$test_file")

    if checksum_verify_file "$test_file" "$expected_hash"; then
        test_pass "Matching hash verification passed"
    else
        fail "Matching hash verification should pass"
    fi
    info "checksum_verify_file 匹配哈希验证正确"
}

test_verify_file_mismatching_hash() {
    local test_file="${TEST_TMPDIR}/files/verify_mismatch.txt"
    echo -n "test content" > "$test_file"

    # Use wrong hash
    local wrong_hash="0000000000000000000000000000000000000000000000000000000000000000"

    if ! checksum_verify_file "$test_file" "$wrong_hash" 2>/dev/null; then
        test_pass "Mismatching hash verification failed as expected"
    else
        fail "Mismatching hash verification should fail"
    fi
    info "checksum_verify_file 不匹配哈希验证失败正确"
}

test_verify_file_invalid_expected_hash() {
    local test_file="${TEST_TMPDIR}/files/verify_invalid.txt"
    echo -n "test content" > "$test_file"

    # Invalid hash format
    local invalid_hash="not-a-valid-hash"

    if ! checksum_verify_file "$test_file" "$invalid_hash" 2>/dev/null; then
        test_pass "Invalid expected hash format rejected"
    else
        fail "Invalid expected hash format should be rejected"
    fi
    info "checksum_verify_file 无效哈希格式拒绝正确"
}

# ============================================================================
# 测试: 一致性验证
# ============================================================================

test_hash_consistency() {
    # Same file should produce same hash
    local test_file="${TEST_TMPDIR}/files/consistency.txt"
    echo -n "consistent content" > "$test_file"

    local hash1
    local hash2
    hash1=$(checksum_compute_sha256 "$test_file")
    hash2=$(checksum_compute_sha256 "$test_file")

    assert_equals "$hash1" "$hash2" "Same file should produce same hash"
    info "checksum 一致性验证正确"
}

test_different_content_different_hash() {
    local file1="${TEST_TMPDIR}/files/different1.txt"
    local file2="${TEST_TMPDIR}/files/different2.txt"

    echo -n "content 1" > "$file1"
    echo -n "content 2" > "$file2"

    local hash1
    local hash2
    hash1=$(checksum_compute_sha256 "$file1")
    hash2=$(checksum_compute_sha256 "$file2")

    if [[ "$hash1" != "$hash2" ]]; then
        test_pass "Different content produces different hash"
    else
        fail "Different content should produce different hash"
    fi
    info "checksum 不同内容不同哈希验证正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 checksum.sh 单元测试..."

# 模块测试
test_module_guard
test_functions_exist

# 格式验证测试
test_validate_format_valid
test_validate_format_invalid_short
test_validate_format_invalid_long
test_validate_format_uppercase
test_validate_format_non_hex
test_validate_format_empty

# SHA256 计算测试
test_compute_sha256_known_content
test_compute_sha256_empty_file
test_compute_sha256_valid_format
test_compute_sha256_missing_file

# 文件验证测试
test_verify_file_matching_hash
test_verify_file_mismatching_hash
test_verify_file_invalid_expected_hash

# 一致性测试
test_hash_consistency
test_different_content_different_hash

info "checksum.sh 单元测试全部通过！"
