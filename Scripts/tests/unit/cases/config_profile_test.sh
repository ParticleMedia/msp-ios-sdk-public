#!/usr/bin/env bash
set -euo pipefail

# @description config_loader.sh Profile 切换测试
# @test load_config profile selection, default profile, profile not found

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# Pre-source the logger to ensure log::debug is available for config_loader.sh
# (config_loader.sh depends on common.sh which depends on logger.sh)
source "$REPO_ROOT/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Fallback: define log functions as no-ops if logger sourcing failed
if ! command -v log::debug &>/dev/null; then
    log::debug() { :; }
    log::info() { :; }
    log::warn() { :; }
    log::error() { :; }
    log::success() { :; }
fi

# ============================================================================
# 测试环境设置
# ============================================================================

setup_test_env() {
    mock_init

    # 创建目录结构
    mkdir -p "${TEST_TMPDIR}/Scripts/config"

    # Reset config loader state for test isolation
    unset _CONFIG_FIRST_LOAD_DONE _DRY_RUN_WAS_SET _SAVED_DRY_RUN DRY_RUN
    unset MSP_LOG_LEVEL MSP_VALIDATION_PREFLIGHT MSP_ALLOW_EXISTING_TAG

    # Use original config_loader.sh (it uses git rev-parse internally)
    # but override MSP_CONFIG_FILE to use temp directory for config files
    export MSP_CONFIG_FILE="${TEST_TMPDIR}/Scripts/config/release.yaml"
    export MSP_LOG_LEVEL="info"
}

create_multi_profile_config() {
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
default_profile: local-dev

profiles:
  local-dev:
    dry_run: true
    validation:
      preflight: basic
    logging:
      level: debug
      format: pretty
    safety:
      allow_existing_tag: true
      allow_existing_release: true

  quick-test:
    dry_run: true
    validation:
      preflight: none
    logging:
      level: warn
      format: pretty
    safety:
      allow_existing_tag: true
      allow_existing_release: true

  production:
    dry_run: false
    validation:
      preflight: full
    logging:
      level: info
      format: pretty
    safety:
      allow_existing_tag: false
      allow_existing_release: false
EOF
}

# ============================================================================
# 测试: Profile 选择
# ============================================================================

test_load_config_uses_specified_profile() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 加载 quick-test profile
    load_config "quick-test"

    # 验证使用了 quick-test profile 的值
    assert_equals "true" "${DRY_RUN:-}" "DRY_RUN 应该是 true (quick-test profile)"
    assert_equals "warn" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该是 warn"
    assert_equals "none" "${MSP_VALIDATION_PREFLIGHT:-}" "MSP_VALIDATION_PREFLIGHT 应该是 none"

    info "load_config 正确使用指定的 profile"
}

test_load_config_uses_default_profile_when_not_specified() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 不指定 profile，应该使用 default_profile
    load_config ""

    # 验证使用了 local-dev profile (default_profile)
    assert_equals "true" "${DRY_RUN:-}" "DRY_RUN 应该是 true (local-dev profile)"
    assert_equals "debug" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该是 debug"
    assert_equals "basic" "${MSP_VALIDATION_PREFLIGHT:-}" "MSP_VALIDATION_PREFLIGHT 应该是 basic"

    info "load_config 正确使用默认 profile"
}

test_load_config_production_profile() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 加载 production profile
    load_config "production"

    # 验证 production profile 的值
    assert_equals "false" "${DRY_RUN:-}" "DRY_RUN 应该是 false (production)"
    assert_equals "info" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该是 info"
    assert_equals "full" "${MSP_VALIDATION_PREFLIGHT:-}" "MSP_VALIDATION_PREFLIGHT 应该是 full"
    assert_equals "false" "${MSP_ALLOW_EXISTING_TAG:-}" "MSP_ALLOW_EXISTING_TAG 应该是 false"

    info "load_config production profile 加载正确"
}

test_load_config_nonexistent_profile_uses_defaults() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 加载不存在的 profile
    load_config "nonexistent-profile"

    # 应该使用默认值
    assert_equals "true" "${DRY_RUN:-}" "DRY_RUN 应该使用默认值 true"
    assert_equals "info" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该使用默认值 info"

    info "load_config 不存在的 profile 使用默认值"
}

# ============================================================================
# 测试: Profile 值覆盖
# ============================================================================

test_profile_values_override_defaults() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 创建只有部分值的 profile
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
default_profile: partial

profiles:
  partial:
    dry_run: false
    # 其他值不指定，应该使用默认值
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    load_config "partial"

    # dry_run 应该被覆盖
    assert_equals "false" "${DRY_RUN:-}" "DRY_RUN 应该被 profile 覆盖为 false"
    # log_level 应该使用默认值
    assert_equals "info" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该使用默认值 info"

    info "Profile 值正确覆盖默认值"
}

# ============================================================================
# 测试: Profile 嵌套结构
# ============================================================================

test_profile_nested_logging_values() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    load_config "local-dev"

    # 验证嵌套的 logging 配置
    assert_equals "debug" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该是 debug"
    assert_equals "pretty" "${MSP_LOG_FORMAT:-}" "MSP_LOG_FORMAT 应该是 pretty"

    info "Profile 嵌套 logging 值正确"
}

test_profile_nested_safety_values() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    load_config "production"

    # 验证嵌套的 safety 配置
    assert_equals "false" "${MSP_ALLOW_EXISTING_TAG:-}" "MSP_ALLOW_EXISTING_TAG 应该是 false"
    assert_equals "false" "${MSP_ALLOW_EXISTING_RELEASE:-}" "MSP_ALLOW_EXISTING_RELEASE 应该是 false"

    info "Profile 嵌套 safety 值正确"
}

# ============================================================================
# 测试: MSP_CURRENT_PROFILE 记录
# ============================================================================

test_current_profile_recorded() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_multi_profile_config

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    load_config "production"

    # 验证 MSP_CURRENT_PROFILE 被设置
    assert_equals "production" "${MSP_CURRENT_PROFILE:-}" "MSP_CURRENT_PROFILE 应该记录当前 profile"

    info "MSP_CURRENT_PROFILE 记录正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 config Profile 切换测试..."

test_load_config_uses_specified_profile
test_load_config_uses_default_profile_when_not_specified
test_load_config_production_profile
test_load_config_nonexistent_profile_uses_defaults
test_profile_values_override_defaults
test_profile_nested_logging_values
test_profile_nested_safety_values
test_current_profile_recorded

info "config Profile 切换测试全部通过！"
