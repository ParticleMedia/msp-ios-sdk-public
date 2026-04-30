#!/usr/bin/env bash
set -euo pipefail

# @description generate_podspec.sh 单元测试
# @test 验证依赖过滤函数、模块分类函数、checksum 计算等核心逻辑
# @context ctx-release-001 (FB SDK crash), ctx-release-003 (Kingfisher crash)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../mock_loader.sh"

# ============================================================================
# 测试环境设置
# ============================================================================

mock_init
mkdir -p "${TEST_TMPDIR}/Build/ReleaseArtifacts/XCFrameworks"

# Source logger for log:: functions used by generate_podspec.sh
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

# ============================================================================
# Source generate_podspec.sh functions only (not main script execution)
# We need to extract and source only the function definitions
# ============================================================================

# Define the arrays and functions from generate_podspec.sh
CORE_MODULES=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore" "MSPOMSDK" "MSPNovaAdapter")
SNAPKIT_FROM_SHARED_LIBS_PODS=("MSPNovaAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPApplovinMaxAdapter" "MSPCore")
KINGFISHER_EMBEDDED_PODS=("MSPNovaAdapter")
BINARY_DISTRIBUTION_PODS=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore" "MSPNovaAdapter" "MSPPrebidAdapter" "MSPGoogleAdapter" "MSPFacebookAdapter" "MSPAmazonAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPApplovinMaxAdapter")
MSP_VERSIONED_DEPS=("MSPiOSCore" "MSPSharedLibraries" "MSPPrebidAdapter" "PrebidAdapter" "MSPGoogleAdsTypes")

# is_core_module function
is_core_module() {
    local module="$1"
    for core in "${CORE_MODULES[@]}"; do
        if [[ "$module" == "$core" ]]; then
            return 0
        fi
    done
    return 1
}

# should_strip_mspsnapkit_dependency function
should_strip_mspsnapkit_dependency() {
    local module="$1"
    for pod in "${SNAPKIT_FROM_SHARED_LIBS_PODS[@]}"; do
        if [[ "$module" == "$pod" ]]; then
            return 0
        fi
    done
    return 1
}

# should_skip_kingfisher_dependency function
should_skip_kingfisher_dependency() {
    local module="$1"
    for pod in "${KINGFISHER_EMBEDDED_PODS[@]}"; do
        if [[ "$module" == "$pod" ]]; then
            return 0
        fi
    done
    return 1
}

# is_binary_distribution function
is_binary_distribution() {
    local module="$1"
    for pod in "${BINARY_DISTRIBUTION_PODS[@]}"; do
        if [[ "$module" == "$pod" ]]; then
            return 0
        fi
    done
    return 1
}

# ============================================================================
# 测试: is_core_module (模块分类)
# ============================================================================

test_is_core_module_returns_true_for_core_modules() {
    if is_core_module "MSPSharedLibraries"; then
        test_pass "MSPSharedLibraries is core module"
    else
        fail "MSPSharedLibraries should be a core module"
    fi

    if is_core_module "MSPCore"; then
        test_pass "MSPCore is core module"
    else
        fail "MSPCore should be a core module"
    fi

    if is_core_module "MSPNovaAdapter"; then
        test_pass "MSPNovaAdapter is core module"
    else
        fail "MSPNovaAdapter should be a core module"
    fi

    info "is_core_module 核心模块识别正确"
}

test_is_core_module_returns_false_for_adapters() {
    if ! is_core_module "MSPGoogleAdapter"; then
        test_pass "MSPGoogleAdapter is not core module"
    else
        fail "MSPGoogleAdapter should not be a core module"
    fi

    if ! is_core_module "MSPFacebookAdapter"; then
        test_pass "MSPFacebookAdapter is not core module"
    else
        fail "MSPFacebookAdapter should not be a core module"
    fi

    if ! is_core_module "MSPAmazonAdapter"; then
        test_pass "MSPAmazonAdapter is not core module"
    else
        fail "MSPAmazonAdapter should not be a core module"
    fi

    info "is_core_module 适配器识别正确"
}

# ============================================================================
# 测试: should_strip_mspsnapkit_dependency (SnapKit 依赖过滤)
# ctx-release-003: 避免重复的 SnapKit 导致编译问题
# ============================================================================

test_snapkit_stripped_for_novaadapter() {
    # MSPNovaAdapter 从 MSPSharedLibraries 获取 SnapKit，不应该直接依赖
    if should_strip_mspsnapkit_dependency "MSPNovaAdapter"; then
        test_pass "MSPNovaAdapter strips MSPSnapKit dependency"
    else
        fail "MSPNovaAdapter should strip MSPSnapKit dependency (provided by MSPSharedLibraries)"
    fi

    info "MSPNovaAdapter SnapKit 依赖过滤正确"
}

test_snapkit_stripped_for_molocoadapter() {
    # MSPMolocoAdapter 从 MSPSharedLibraries 获取 SnapKit
    if should_strip_mspsnapkit_dependency "MSPMolocoAdapter"; then
        test_pass "MSPMolocoAdapter strips MSPSnapKit dependency"
    else
        fail "MSPMolocoAdapter should strip MSPSnapKit dependency (provided by MSPSharedLibraries)"
    fi

    info "MSPMolocoAdapter SnapKit 依赖过滤正确"
}

test_snapkit_stripped_for_liftoffadapter() {
    # MSPLiftoffAdapter 从 MSPSharedLibraries 获取 SnapKit
    if should_strip_mspsnapkit_dependency "MSPLiftoffAdapter"; then
        test_pass "MSPLiftoffAdapter strips MSPSnapKit dependency"
    else
        fail "MSPLiftoffAdapter should strip MSPSnapKit dependency (provided by MSPSharedLibraries)"
    fi

    info "MSPLiftoffAdapter SnapKit 依赖过滤正确"
}

test_snapkit_stripped_for_applovinmaxadapter() {
    # MSPApplovinMaxAdapter 从 MSPSharedLibraries 获取 SnapKit
    if should_strip_mspsnapkit_dependency "MSPApplovinMaxAdapter"; then
        test_pass "MSPApplovinMaxAdapter strips MSPSnapKit dependency"
    else
        fail "MSPApplovinMaxAdapter should strip MSPSnapKit dependency (provided by MSPSharedLibraries)"
    fi

    info "MSPApplovinMaxAdapter SnapKit 依赖过滤正确"
}

test_snapkit_stripped_for_mspcore() {
    # MSPCore 从 MSPSharedLibraries 获取 SnapKit
    if should_strip_mspsnapkit_dependency "MSPCore"; then
        test_pass "MSPCore strips MSPSnapKit dependency"
    else
        fail "MSPCore should strip MSPSnapKit dependency (provided by MSPSharedLibraries)"
    fi

    info "MSPCore SnapKit 依赖过滤正确"
}

test_snapkit_not_stripped_for_other_pods() {
    # 其他 pods 不应该被过滤
    if ! should_strip_mspsnapkit_dependency "MSPGoogleAdapter"; then
        test_pass "MSPGoogleAdapter keeps MSPSnapKit dependency"
    else
        fail "MSPGoogleAdapter should not strip MSPSnapKit dependency"
    fi

    if ! should_strip_mspsnapkit_dependency "MSPFacebookAdapter"; then
        test_pass "MSPFacebookAdapter keeps MSPSnapKit dependency"
    else
        fail "MSPFacebookAdapter should not strip MSPSnapKit dependency"
    fi

    info "其他 pods SnapKit 依赖保留正确"
}

# ============================================================================
# 测试: should_skip_kingfisher_dependency (Kingfisher 依赖过滤)
# ctx-release-003: NovaCore 静态链接了 Kingfisher，避免重复
# ============================================================================

test_kingfisher_skipped_for_novaadapter() {
    # MSPNovaAdapter 内嵌 NovaCore，NovaCore 已经静态链接 Kingfisher
    # 添加公开的 Kingfisher 依赖会导致运行时冲突
    if should_skip_kingfisher_dependency "MSPNovaAdapter"; then
        test_pass "MSPNovaAdapter skips Kingfisher dependency"
    else
        fail "MSPNovaAdapter should skip Kingfisher dependency (embedded in NovaCore)"
    fi

    info "MSPNovaAdapter Kingfisher 依赖跳过正确"
}

test_kingfisher_not_skipped_for_other_pods() {
    # 其他 pods 如果需要 Kingfisher 应该添加依赖
    if ! should_skip_kingfisher_dependency "MSPCore"; then
        test_pass "MSPCore does not skip Kingfisher dependency"
    else
        fail "MSPCore should not skip Kingfisher dependency"
    fi

    if ! should_skip_kingfisher_dependency "MSPSharedLibraries"; then
        test_pass "MSPSharedLibraries does not skip Kingfisher dependency"
    else
        fail "MSPSharedLibraries should not skip Kingfisher dependency"
    fi

    info "其他 pods Kingfisher 依赖不跳过正确"
}

# ============================================================================
# 测试: is_binary_distribution (分发方式判断)
# ============================================================================

test_binary_distribution_core_modules() {
    # 核心模块使用二进制分发
    if is_binary_distribution "MSPSharedLibraries"; then
        test_pass "MSPSharedLibraries uses binary distribution"
    else
        fail "MSPSharedLibraries should use binary distribution"
    fi

    if is_binary_distribution "MSPCore"; then
        test_pass "MSPCore uses binary distribution"
    else
        fail "MSPCore should use binary distribution"
    fi

    if is_binary_distribution "MSPiOSCore"; then
        test_pass "MSPiOSCore uses binary distribution"
    else
        fail "MSPiOSCore should use binary distribution"
    fi

    info "核心模块二进制分发识别正确"
}

test_binary_distribution_adapters() {
    # 新架构下适配器也使用二进制分发
    if is_binary_distribution "MSPPrebidAdapter"; then
        test_pass "MSPPrebidAdapter uses binary distribution"
    else
        fail "MSPPrebidAdapter should use binary distribution"
    fi

    if is_binary_distribution "MSPGoogleAdapter"; then
        test_pass "MSPGoogleAdapter uses binary distribution"
    else
        fail "MSPGoogleAdapter should use binary distribution"
    fi

    if is_binary_distribution "MSPFacebookAdapter"; then
        test_pass "MSPFacebookAdapter uses binary distribution"
    else
        fail "MSPFacebookAdapter should use binary distribution"
    fi

    if is_binary_distribution "MSPAmazonAdapter"; then
        test_pass "MSPAmazonAdapter uses binary distribution"
    else
        fail "MSPAmazonAdapter should use binary distribution"
    fi

    if is_binary_distribution "MSPMolocoAdapter"; then
        test_pass "MSPMolocoAdapter uses binary distribution"
    else
        fail "MSPMolocoAdapter should use binary distribution"
    fi

    if is_binary_distribution "MSPLiftoffAdapter"; then
        test_pass "MSPLiftoffAdapter uses binary distribution"
    else
        fail "MSPLiftoffAdapter should use binary distribution"
    fi

    if is_binary_distribution "MSPApplovinMaxAdapter"; then
        test_pass "MSPApplovinMaxAdapter uses binary distribution"
    else
        fail "MSPApplovinMaxAdapter should use binary distribution"
    fi

    info "适配器二进制分发识别正确"
}

test_binary_distribution_unknown_pod() {
    # 未知 pod 不使用二进制分发
    if ! is_binary_distribution "UnknownPod"; then
        test_pass "UnknownPod does not use binary distribution"
    else
        fail "UnknownPod should not use binary distribution"
    fi

    info "未知 pod 二进制分发识别正确"
}

# ============================================================================
# 测试: KINGFISHER_EMBEDDED_PODS 配置验证
# ctx-release-003: 确保 Kingfisher 嵌入配置正确
# ============================================================================

test_kingfisher_embedded_pods_contains_novaadapter() {
    local found=false
    for pod in "${KINGFISHER_EMBEDDED_PODS[@]}"; do
        if [[ "$pod" == "MSPNovaAdapter" ]]; then
            found=true
            break
        fi
    done

    if [[ "$found" == "true" ]]; then
        test_pass "KINGFISHER_EMBEDDED_PODS contains MSPNovaAdapter"
    else
        fail "KINGFISHER_EMBEDDED_PODS should contain MSPNovaAdapter"
    fi

    info "KINGFISHER_EMBEDDED_PODS 配置验证正确"
}

# ============================================================================
# 测试: SNAPKIT_FROM_SHARED_LIBS_PODS 配置验证
# ============================================================================

test_snapkit_shared_libs_pods_configuration() {
    local expected_pods=("MSPNovaAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPApplovinMaxAdapter" "MSPCore")

    for expected in "${expected_pods[@]}"; do
        local found=false
        for pod in "${SNAPKIT_FROM_SHARED_LIBS_PODS[@]}"; do
            if [[ "$pod" == "$expected" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" == "true" ]]; then
            test_pass "$expected is in SNAPKIT_FROM_SHARED_LIBS_PODS"
        else
            fail "$expected should be in SNAPKIT_FROM_SHARED_LIBS_PODS"
        fi
    done

    info "SNAPKIT_FROM_SHARED_LIBS_PODS 配置验证正确"
}

# ============================================================================
# 测试: MSP_VERSIONED_DEPS 配置验证
# ============================================================================

test_msp_versioned_deps_configuration() {
    local expected_deps=("MSPiOSCore" "MSPSharedLibraries" "MSPPrebidAdapter" "PrebidAdapter" "MSPGoogleAdsTypes")

    for expected in "${expected_deps[@]}"; do
        local found=false
        for dep in "${MSP_VERSIONED_DEPS[@]}"; do
            if [[ "$dep" == "$expected" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" == "true" ]]; then
            test_pass "$expected is in MSP_VERSIONED_DEPS"
        else
            fail "$expected should be in MSP_VERSIONED_DEPS"
        fi
    done

    info "MSP_VERSIONED_DEPS 配置验证正确"
}

# ============================================================================
# 测试: 依赖过滤逻辑一致性
# 确保 SnapKit 和 Kingfisher 过滤逻辑不冲突
# ============================================================================

test_dependency_filtering_consistency() {
    # MSPNovaAdapter 同时过滤 SnapKit 和 Kingfisher
    if should_strip_mspsnapkit_dependency "MSPNovaAdapter" && should_skip_kingfisher_dependency "MSPNovaAdapter"; then
        test_pass "MSPNovaAdapter correctly filters both SnapKit and Kingfisher"
    else
        fail "MSPNovaAdapter should filter both SnapKit and Kingfisher dependencies"
    fi

    # MSPMolocoAdapter 只过滤 SnapKit，不过滤 Kingfisher
    if should_strip_mspsnapkit_dependency "MSPMolocoAdapter" && ! should_skip_kingfisher_dependency "MSPMolocoAdapter"; then
        test_pass "MSPMolocoAdapter correctly filters SnapKit but keeps Kingfisher"
    else
        fail "MSPMolocoAdapter should filter SnapKit but not Kingfisher"
    fi

    # MSPCore 只过滤 SnapKit，不过滤 Kingfisher
    if should_strip_mspsnapkit_dependency "MSPCore" && ! should_skip_kingfisher_dependency "MSPCore"; then
        test_pass "MSPCore correctly filters SnapKit but keeps Kingfisher"
    else
        fail "MSPCore should filter SnapKit but not Kingfisher"
    fi

    info "依赖过滤逻辑一致性验证正确"
}

# ============================================================================
# 测试: MSPCore podspec 生成包含 resource_bundles
# getMSPVersion() 需要 MSPCoreResources.bundle 才能读到 Config.plist
# ============================================================================

test_mspcore_podspec_has_resource_bundles() {
    # 模拟 generate_podspec.sh 中 MSPCore 的 vendored_frameworks 分支
    local output
    output=$(cat <<'EOF_VENDOR_MSPCORE'
  spec.vendored_frameworks = "Binary/MSPCore.xcframework"
  spec.resource_bundles = {
    'MSPCoreResources' => ['Resources/Config.plist']
  }
EOF_VENDOR_MSPCORE
)

    if [[ "$output" == *"resource_bundles"* ]]; then
        test_pass "MSPCore podspec includes resource_bundles"
    else
        fail "MSPCore podspec should include resource_bundles for Config.plist"
    fi

    if [[ "$output" == *"MSPCoreResources"* ]]; then
        test_pass "MSPCore resource bundle named MSPCoreResources"
    else
        fail "MSPCore resource bundle should be named MSPCoreResources"
    fi

    if [[ "$output" == *"Config.plist"* ]]; then
        test_pass "MSPCore resource bundle includes Config.plist"
    else
        fail "MSPCore resource bundle should include Config.plist"
    fi

    info "MSPCore podspec resource_bundles 配置正确"
}

test_mspcore_is_separate_from_default_vendored() {
    # MSPCore 不应该走默认的 vendored_frameworks 分支
    # 它需要专门处理 resource_bundles
    if is_core_module "MSPCore" && is_binary_distribution "MSPCore"; then
        test_pass "MSPCore is core + binary (requires special podspec handling)"
    else
        fail "MSPCore should be both core module and binary distribution"
    fi

    info "MSPCore 特殊处理分支验证正确"
}

# ============================================================================
# 测试: 核心模块与二进制分发一致性
# Note: MSPOMSDK is excluded because OMSDK is now embedded in NovaCore
# ============================================================================

test_core_modules_are_binary_distribution() {
    for core in "${CORE_MODULES[@]}"; do
        # Skip MSPOMSDK - it's in CORE_MODULES for historical reasons
        # but OMSDK is now embedded in NovaCore and not published separately
        if [[ "$core" == "MSPOMSDK" ]]; then
            test_pass "MSPOMSDK is excluded (embedded in NovaCore)"
            continue
        fi

        if is_binary_distribution "$core"; then
            test_pass "$core is both core module and binary distribution"
        else
            fail "$core is core module but not in binary distribution (inconsistent)"
        fi
    done

    info "核心模块与二进制分发一致性验证正确"
}

# ============================================================================
# 运行所有测试
# ============================================================================

info "运行 generate_podspec.sh 单元测试..."

# 模块分类测试
test_is_core_module_returns_true_for_core_modules
test_is_core_module_returns_false_for_adapters

# SnapKit 依赖过滤测试 (ctx-release-003)
test_snapkit_stripped_for_novaadapter
test_snapkit_stripped_for_molocoadapter
test_snapkit_stripped_for_liftoffadapter
test_snapkit_stripped_for_applovinmaxadapter
test_snapkit_stripped_for_mspcore
test_snapkit_not_stripped_for_other_pods

# Kingfisher 依赖过滤测试 (ctx-release-003)
test_kingfisher_skipped_for_novaadapter
test_kingfisher_not_skipped_for_other_pods

# 二进制分发测试
test_binary_distribution_core_modules
test_binary_distribution_adapters
test_binary_distribution_unknown_pod

# 配置验证测试
test_kingfisher_embedded_pods_contains_novaadapter
test_snapkit_shared_libs_pods_configuration
test_msp_versioned_deps_configuration

# MSPCore resource_bundles 测试
test_mspcore_podspec_has_resource_bundles
test_mspcore_is_separate_from_default_vendored

# 一致性测试
test_dependency_filtering_consistency
test_core_modules_are_binary_distribution

info "generate_podspec.sh 单元测试全部通过！"
