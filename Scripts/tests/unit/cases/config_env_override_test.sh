#!/usr/bin/env bash
set -euo pipefail

# @description config_loader.sh 环境变量覆盖测试
# @test DRY_RUN 和其他环境变量应该覆盖配置文件的值

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
}

create_base_config() {
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
default_profile: local-dev

profiles:
  local-dev:
    dry_run: true
    validation:
      preflight: basic
    logging:
      level: info
      format: pretty
    safety:
      allow_existing_tag: true
      allow_existing_release: true
EOF
}

# ============================================================================
# 测试: DRY_RUN 环境变量覆盖
# ============================================================================

test_env_override_dry_run() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    # 配置文件设置 dry_run: true，但环境变量覆盖为 false
    export DRY_RUN="false"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    # 环境变量应该优先
    assert_equals "false" "${DRY_RUN:-}" "DRY_RUN 环境变量应该覆盖配置文件"

    unset DRY_RUN
    info "DRY_RUN 环境变量覆盖正确"
}

test_env_override_dry_run_true() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 创建 production profile (dry_run: false)
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
default_profile: production

profiles:
  production:
    dry_run: false
    validation:
      preflight: full
EOF

    # 环境变量强制开启 dry_run
    export DRY_RUN="true"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "production"

    assert_equals "true" "${DRY_RUN:-}" "DRY_RUN=true 应该覆盖 production profile"

    unset DRY_RUN
    info "DRY_RUN=true 覆盖 production profile 正确"
}

# ============================================================================
# 测试: MSP_LOG_LEVEL_OVERRIDE 环境变量覆盖
# ============================================================================

test_env_override_log_level() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    # 使用 MSP_LOG_LEVEL_OVERRIDE 覆盖
    export MSP_LOG_LEVEL_OVERRIDE="debug"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    assert_equals "debug" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL_OVERRIDE 应该覆盖配置文件值"

    unset MSP_LOG_LEVEL_OVERRIDE
    info "MSP_LOG_LEVEL_OVERRIDE 覆盖正确"
}

# ============================================================================
# 测试: Safety 相关环境变量覆盖
# ============================================================================

test_env_override_allow_existing_tag() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    # 使用 MSP_ALLOW_EXISTING_TAG_OVERRIDE 覆盖
    export MSP_ALLOW_EXISTING_TAG_OVERRIDE="false"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    assert_equals "false" "${MSP_ALLOW_EXISTING_TAG:-}" "MSP_ALLOW_EXISTING_TAG_OVERRIDE 应该覆盖配置文件值"

    unset MSP_ALLOW_EXISTING_TAG_OVERRIDE
    info "MSP_ALLOW_EXISTING_TAG_OVERRIDE 覆盖正确"
}

# ============================================================================
# 测试: Performance 相关环境变量覆盖
# ============================================================================

test_env_override_parallel_builds() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    export MSP_PARALLEL_BUILDS_OVERRIDE="false"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    assert_equals "false" "${MSP_PARALLEL_BUILDS:-}" "MSP_PARALLEL_BUILDS_OVERRIDE 应该覆盖配置文件值"

    unset MSP_PARALLEL_BUILDS_OVERRIDE
    info "MSP_PARALLEL_BUILDS_OVERRIDE 覆盖正确"
}

test_env_override_cdn_wait_time() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    export MSP_CDN_WAIT_TIME_OVERRIDE="300"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    assert_equals "300" "${MSP_CDN_WAIT_TIME:-}" "MSP_CDN_WAIT_TIME_OVERRIDE 应该覆盖配置文件值"

    unset MSP_CDN_WAIT_TIME_OVERRIDE
    info "MSP_CDN_WAIT_TIME_OVERRIDE 覆盖正确"
}

# ============================================================================
# 测试: Verify 相关环境变量覆盖
# ============================================================================

test_env_override_sandbox_dir() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    export MSP_SANDBOX_DIR_OVERRIDE="/custom/sandbox/path"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    assert_equals "/custom/sandbox/path" "${MSP_SANDBOX_DIR:-}" "MSP_SANDBOX_DIR_OVERRIDE 应该覆盖配置文件值"

    unset MSP_SANDBOX_DIR_OVERRIDE
    info "MSP_SANDBOX_DIR_OVERRIDE 覆盖正确"
}

# ============================================================================
# 测试: 多个环境变量同时覆盖
# ============================================================================

test_multiple_env_overrides() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    export DRY_RUN="false"
    export MSP_LOG_LEVEL_OVERRIDE="error"
    export MSP_CDN_WAIT_TIME_OVERRIDE="999"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    assert_equals "false" "${DRY_RUN:-}" "DRY_RUN 应该覆盖为 false"
    assert_equals "error" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL_OVERRIDE 应该覆盖为 error"
    assert_equals "999" "${MSP_CDN_WAIT_TIME:-}" "MSP_CDN_WAIT_TIME_OVERRIDE 应该覆盖为 999"

    unset DRY_RUN MSP_LOG_LEVEL_OVERRIDE MSP_CDN_WAIT_TIME_OVERRIDE
    info "多个环境变量同时覆盖正确"
}

# ============================================================================
# 测试: 环境变量在配置文件缺失时提供值
# ============================================================================

test_env_provides_value_when_config_missing() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 确保配置文件不存在
    rm -f "${TEST_TMPDIR}/Scripts/config/release.yaml"

    # 设置环境变量
    export DRY_RUN="false"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    # 环境变量应该提供值
    assert_equals "false" "${DRY_RUN:-}" "配置文件缺失时 DRY_RUN 应该覆盖 DRY_RUN"

    unset DRY_RUN
    info "配置文件缺失时环境变量正确提供值"
}

# ============================================================================
# 测试: 空字符串环境变量的处理
# ============================================================================

test_empty_env_var_uses_config_value() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse
    create_base_config

    # 设置空字符串环境变量
    export DRY_RUN=""

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"
    load_config "local-dev"

    # 空字符串 DRY_RUN 应该被忽略，使用配置文件的值
    local actual="${DRY_RUN:-}"
    assert_equals "true" "$actual" "空字符串 DRY_RUN 应该被忽略，使用配置文件值"

    unset DRY_RUN
    info "空字符串环境变量正确使用配置文件值"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 config 环境变量覆盖测试..."

test_env_override_dry_run
test_env_override_dry_run_true
test_env_override_log_level
test_env_override_allow_existing_tag
test_env_override_parallel_builds
test_env_override_cdn_wait_time
test_env_override_sandbox_dir
test_multiple_env_overrides
test_env_provides_value_when_config_missing
test_empty_env_var_uses_config_value

info "config 环境变量覆盖测试全部通过！"
