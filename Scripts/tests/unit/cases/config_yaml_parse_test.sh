#!/usr/bin/env bash
set -euo pipefail

# @description config_loader.sh YAML 解析测试
# @test parse_yaml, load_config 基础功能

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

# ============================================================================
# 测试: parse_yaml 基本功能
# ============================================================================

test_parse_yaml_basic_key_value() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 创建简单的 YAML 文件
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
version: "1.0.0"
base_branch: main
default_profile: local-dev
EOF

    # Source config_loader.sh
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 测试 parse_yaml
    local result
    result=$(parse_yaml "${TEST_TMPDIR}/Scripts/config/release.yaml" "CFG_")

    # 验证解析结果
    assert_contains "$result" 'CFG_version="1.0.0"' "应该解析 version"
    assert_contains "$result" 'CFG_base_branch="main"' "应该解析 base_branch"
    assert_contains "$result" 'CFG_default_profile="local-dev"' "应该解析 default_profile"

    info "parse_yaml 基本 key-value 解析正确"
}

test_parse_yaml_nested_keys() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 创建嵌套结构的 YAML
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
profiles:
  local-dev:
    dry_run: true
    logging:
      level: info
      format: pretty
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    local result
    result=$(parse_yaml "${TEST_TMPDIR}/Scripts/config/release.yaml" "CFG_")

    # 验证嵌套解析 (hyphens 转换为 underscores)
    assert_contains "$result" 'CFG_profiles_local_dev_dry_run="true"' "应该解析嵌套的 dry_run"
    assert_contains "$result" 'CFG_profiles_local_dev_logging_level="info"' "应该解析嵌套的 logging.level"

    info "parse_yaml 嵌套 key 解析正确"
}

test_parse_yaml_boolean_values() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
enabled: true
disabled: false
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    local result
    result=$(parse_yaml "${TEST_TMPDIR}/Scripts/config/release.yaml" "CFG_")

    assert_contains "$result" 'CFG_enabled="true"' "应该解析 boolean true"
    assert_contains "$result" 'CFG_disabled="false"' "应该解析 boolean false"

    info "parse_yaml boolean 值解析正确"
}

test_parse_yaml_comments_ignored() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
# 这是注释
schema_version: 2
version: "1.0.0"  # 行尾注释
# 另一个注释
name: test
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    local result
    result=$(parse_yaml "${TEST_TMPDIR}/Scripts/config/release.yaml" "CFG_")

    assert_contains "$result" 'CFG_version="1.0.0"' "应该解析 version"
    assert_contains "$result" 'CFG_name="test"' "应该解析 name"
    assert_not_contains "$result" "这是注释" "不应该包含注释内容"

    info "parse_yaml 注释正确忽略"
}

test_parse_yaml_file_not_found() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 测试不存在的文件
    local exit_code=0
    parse_yaml "/nonexistent/file.yaml" "CFG_" || exit_code=$?

    assert_equals "1" "$exit_code" "不存在的文件应该返回错误"

    info "parse_yaml 文件不存在处理正确"
}

# ============================================================================
# 测试: parse_yaml hyphens 转 underscores
# ============================================================================

test_parse_yaml_hyphen_to_underscore() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
profiles:
  local-dev:
    dry-run: true
  quick-test:
    log-level: warn
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    local result
    result=$(parse_yaml "${TEST_TMPDIR}/Scripts/config/release.yaml" "CFG_")

    # Hyphens 应该转换为 underscores
    assert_contains "$result" "local_dev" "local-dev 应该转换为 local_dev"
    assert_contains "$result" "dry_run" "dry-run 应该转换为 dry_run"
    assert_contains "$result" "quick_test" "quick-test 应该转换为 quick_test"

    info "parse_yaml hyphen 到 underscore 转换正确"
}

# ============================================================================
# 测试: load_config 基本功能
# ============================================================================

test_load_config_sets_variables() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 创建完整的配置文件
    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
default_profile: local-dev

profiles:
  local-dev:
    dry_run: true
    logging:
      level: info
      format: pretty
    safety:
      allow_existing_tag: true
      allow_existing_release: true
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 加载配置
    load_config "local-dev"

    # 验证变量被设置
    assert_equals "true" "${DRY_RUN:-}" "DRY_RUN 应该是 true"
    assert_equals "info" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该是 info"
    assert_equals "true" "${MSP_ALLOW_EXISTING_TAG:-}" "MSP_ALLOW_EXISTING_TAG 应该是 true"

    info "load_config 正确设置变量"
}

test_load_config_missing_file_uses_defaults() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    # 确保配置文件不存在
    rm -f "${TEST_TMPDIR}/Scripts/config/release.yaml"

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    # 加载配置 (文件不存在)
    load_config "local-dev"

    # 应该使用默认值
    assert_equals "true" "${DRY_RUN:-}" "DRY_RUN 应该使用默认值 true"
    assert_equals "info" "${MSP_LOG_LEVEL:-}" "MSP_LOG_LEVEL 应该使用默认值 info"

    info "load_config 配置文件缺失时使用默认值"
}

# ============================================================================
# 测试: parse_yaml 数组支持
# ============================================================================

test_parse_yaml_array_items() {
    setup_test_env
    # Note: Do NOT cd to temp dir - config_loader.sh uses git rev-parse

    cat > "${TEST_TMPDIR}/Scripts/config/release.yaml" <<'EOF'
schema_version: 2
pods:
  modules:
    - MSPCore
    - MSPiOSCore
    - MSPSharedLibraries
EOF

    # shellcheck source=/dev/null
    source "${REPO_ROOT}/Scripts/lib/config_loader.sh"

    local result
    result=$(parse_yaml "${TEST_TMPDIR}/Scripts/config/release.yaml" "CFG_")

    # 验证数组项被解析
    assert_contains "$result" 'CFG_pods_modules__item_0="MSPCore"' "应该解析第一个数组项"
    assert_contains "$result" 'CFG_pods_modules__item_1="MSPiOSCore"' "应该解析第二个数组项"
    assert_contains "$result" 'CFG_pods_modules__item_2="MSPSharedLibraries"' "应该解析第三个数组项"

    info "parse_yaml 数组解析正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 config YAML 解析测试..."

test_parse_yaml_basic_key_value
test_parse_yaml_nested_keys
test_parse_yaml_boolean_values
test_parse_yaml_comments_ignored
test_parse_yaml_file_not_found
test_parse_yaml_hyphen_to_underscore
test_load_config_sets_variables
test_load_config_missing_file_uses_defaults
test_parse_yaml_array_items

info "config YAML 解析测试全部通过！"
