#!/usr/bin/env bash
# Unit tests for XCFramework version ordering in release_orchestration.sh
# Verifies structural ordering of release steps — version updates BEFORE builds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

MODULE_FILE="$ROOT_DIR/Scripts/release/publish/pods/lib/release_orchestration.sh"

# Helper: get the first line number matching a pattern (non-comment lines only)
get_line() {
    local pattern="$1"
    grep -n "$pattern" "$MODULE_FILE" | grep -vE ':[[:space:]]*#' | head -1 | cut -d: -f1
}

# Helper: get the first line number matching a pattern (including comments)
get_line_any() {
    local pattern="$1"
    grep -n "$pattern" "$MODULE_FILE" | head -1 | cut -d: -f1
}

# ============================================================================
# Test 1: Old adapter version update block has been removed
# ============================================================================
test_old_adapter_version_block_removed() {
    if grep -q "load_adapter_sdk_version_config" "$MODULE_FILE"; then
        test_fail "load_adapter_sdk_version_config should be removed from release_orchestration.sh"
    else
        test_pass "Old adapter version update block removed"
    fi
}

# ============================================================================
# Test 2: NovaCore Config.plist update happens BEFORE NovaCore XCFramework build
# ============================================================================
test_novacore_version_before_build() {
    local version_line build_line
    version_line=$(get_line 'update_and_commit_plist_version "novacore"')
    build_line=$(get_line "ensure_novacore_xcframework")

    if [[ -z "$version_line" ]]; then
        test_fail "update_and_commit_plist_version novacore call not found"
    fi
    if [[ -z "$build_line" ]]; then
        test_fail "ensure_novacore_xcframework call not found"
    fi

    if [[ "$version_line" -lt "$build_line" ]]; then
        test_pass "NovaCore version update (line $version_line) before XCFramework build (line $build_line)"
    else
        test_fail "NovaCore version update (line $version_line) should be BEFORE XCFramework build (line $build_line)"
    fi
}

# ============================================================================
# Test 3: MSPNovaAdapter rebuild happens after ensure_novacore_xcframework
# ============================================================================
test_mspnovaadapter_rebuild_after_novacore() {
    local novacore_line nova_rebuild_line
    novacore_line=$(get_line "ensure_novacore_xcframework")
    nova_rebuild_line=$(get_line_any "Rebuilding MSPNovaAdapter XCFramework")

    if [[ -z "$novacore_line" ]]; then
        test_fail "ensure_novacore_xcframework call not found"
    fi
    if [[ -z "$nova_rebuild_line" ]]; then
        test_fail "MSPNovaAdapter rebuild block not found"
    fi

    if [[ "$nova_rebuild_line" -gt "$novacore_line" ]]; then
        test_pass "MSPNovaAdapter rebuild (line $nova_rebuild_line) after NovaCore (line $novacore_line)"
    else
        test_fail "MSPNovaAdapter rebuild should come AFTER ensure_novacore_xcframework"
    fi
}

# ============================================================================
# Test 4: MSPCore Config.plist update → rebuild → zip (correct order)
# ============================================================================
test_mspcore_rebuild_after_config_plist_update() {
    local config_line rebuild_line zip_line
    config_line=$(get_line 'update_and_commit_plist_version "mspcore"')
    rebuild_line=$(get_line_any "Rebuilding MSPCore.xcframework with updated SDKVersion")
    zip_line=$(get_line 'ensure_zip_file_exists_for_pod "MSPCore"')

    if [[ -z "$config_line" ]] || [[ -z "$rebuild_line" ]] || [[ -z "$zip_line" ]]; then
        test_fail "Missing lines: config=$config_line rebuild=$rebuild_line zip=$zip_line"
    fi

    if [[ "$config_line" -lt "$rebuild_line" ]] && [[ "$rebuild_line" -lt "$zip_line" ]]; then
        test_pass "Order: Config.plist (line $config_line) -> rebuild (line $rebuild_line) -> zip (line $zip_line)"
    else
        test_fail "Expected config < rebuild < zip, got: $config_line, $rebuild_line, $zip_line"
    fi
}

# ============================================================================
# Test 5: Adapters extraction happens before Step 0
# ============================================================================
test_adapters_extracted_early() {
    local func_start_line step_minus1_line step_0_line
    func_start_line=$(grep -n "^release_adapters()" "$MODULE_FILE" | head -1 | cut -d: -f1)
    step_minus1_line=$(get_line_any "Step -1: Extract adapters list")
    step_0_line=$(get_line_any "Step 0: Ensure NovaCore")

    if [[ -z "$func_start_line" ]] || [[ -z "$step_minus1_line" ]] || [[ -z "$step_0_line" ]]; then
        test_fail "Missing lines: func=$func_start_line step-1=$step_minus1_line step0=$step_0_line"
    fi

    if [[ "$step_minus1_line" -gt "$func_start_line" ]] && [[ "$step_minus1_line" -lt "$step_0_line" ]]; then
        test_pass "Adapters extraction (line $step_minus1_line) between function start and Step 0"
    else
        test_fail "Adapters extraction should be after function start and before Step 0"
    fi
}

# ============================================================================
# Test 6: DRY_RUN guards MSPNovaAdapter rebuild
# ============================================================================
test_dry_run_guards_novaadapter_rebuild() {
    local block
    block=$(awk '/Rebuild MSPNovaAdapter XCFramework now that NovaCore/,/Pre-flight check: GitHub CLI/' "$MODULE_FILE")

    if echo "$block" | grep -q 'DRY_RUN.*!=.*true'; then
        test_pass "MSPNovaAdapter rebuild is guarded by DRY_RUN check"
    else
        test_fail "MSPNovaAdapter rebuild should be guarded by DRY_RUN != true"
    fi
}

# ============================================================================
# Test 7: build-core.sh used for MSPCore rebuild
# ============================================================================
test_mspcore_uses_build_core_script() {
    local block
    block=$(awk '/Rebuilding MSPCore.xcframework with updated SDKVersion/,/ensure_zip_file_exists_for_pod/' "$MODULE_FILE")

    if echo "$block" | grep -q 'build-core.sh'; then
        test_pass "MSPCore rebuild uses build-core.sh"
    else
        test_fail "MSPCore rebuild should use build-core.sh"
    fi
}

# ============================================================================
# Test 8: Only one adapters array initialization (no duplicates)
# ============================================================================
test_no_duplicate_adapters_extraction() {
    local count
    count=$(grep -c "local adapters=()" "$MODULE_FILE" || true)

    if [[ "$count" -eq 1 ]]; then
        test_pass "Only one adapters array initialization found (no duplicates)"
    else
        test_fail "Expected 1 adapters=() initialization, found $count"
    fi
}

# ============================================================================
# Test 9: Step 0.9 reads SSOT and uses update_and_commit_plist_version
# ============================================================================
test_step_09_calls_ssot_functions() {
    local block
    block=$(awk '/Step 0.9:/,/Step 0: Ensure NovaCore/' "$MODULE_FILE")

    if echo "$block" | grep -q 'read_sdk_version_from_config'; then
        test_pass "Step 0.9 calls read_sdk_version_from_config"
    else
        test_fail "Step 0.9 should call read_sdk_version_from_config"
    fi

    if echo "$block" | grep -q 'update_and_commit_plist_version.*novacore'; then
        test_pass "Step 0.9 calls update_and_commit_plist_version novacore"
    else
        test_fail "Step 0.9 should call update_and_commit_plist_version novacore"
    fi

    # set_sdk_version_in_config should NOT be in Step 0.9 (moved to modular.sh)
    if ! echo "$block" | grep -q 'set_sdk_version_in_config'; then
        test_pass "Step 0.9 does NOT call set_sdk_version_in_config (moved to modular.sh)"
    else
        test_fail "Step 0.9 should NOT call set_sdk_version_in_config (now in modular.sh)"
    fi
}

# ============================================================================
# Test 10: Step 0.9 appears before Step 0 (version sync before build)
# ============================================================================
test_step_09_before_step_0() {
    local step_09_line step_0_line
    step_09_line=$(get_line_any "Step 0.9: Sync SDK version SSOT")
    step_0_line=$(get_line_any "Step 0: Ensure NovaCore")

    if [[ -z "$step_09_line" ]]; then
        test_fail "Step 0.9 header not found"
    fi
    if [[ -z "$step_0_line" ]]; then
        test_fail "Step 0 header not found"
    fi

    if [[ "$step_09_line" -lt "$step_0_line" ]]; then
        test_pass "Step 0.9 (line $step_09_line) before Step 0 (line $step_0_line)"
    else
        test_fail "Step 0.9 should come BEFORE Step 0"
    fi
}

# ============================================================================
# Test 11: release_msp_core normal path uses ensure_mspcore_version_committed
#          (not inline commit that only stages MSPCore Config.plist)
# ============================================================================
test_normal_path_uses_unified_commit() {
    # The release_msp_core function should call ensure_version_files_committed
    # after publish_pod_to_cocoapods as a safety net
    local block
    block=$(awk '/publish_pod_to_cocoapods "MSPCore"/,/smart_wait_for_pod_availability/' "$MODULE_FILE")

    if echo "$block" | grep -q 'ensure_version_files_committed'; then
        test_pass "Normal publish path uses ensure_version_files_committed (safety net)"
    else
        test_fail "Normal publish path should call ensure_version_files_committed after publish"
    fi
}

# ============================================================================
# Test 12: Step 0.9 and release_msp_core both use update_and_commit_plist_version (DRY)
# ============================================================================
test_uses_dry_update_and_commit() {
    local step09_block mspcore_block
    step09_block=$(awk '/Step 0.9:/,/Step 0: Ensure NovaCore/' "$MODULE_FILE")
    mspcore_block=$(awk '/Update MSPCore version in Config.plist/,/Rebuild MSPCore/' "$MODULE_FILE")

    local step09_ok=false mspcore_ok=false

    if echo "$step09_block" | grep -q 'update_and_commit_plist_version.*novacore'; then
        step09_ok=true
    fi
    if echo "$mspcore_block" | grep -q 'update_and_commit_plist_version.*mspcore'; then
        mspcore_ok=true
    fi

    if [[ "$step09_ok" == "true" ]] && [[ "$mspcore_ok" == "true" ]]; then
        test_pass "Both Step 0.9 (novacore) and release_msp_core (mspcore) use update_and_commit_plist_version"
    else
        test_fail "Both sites should use update_and_commit_plist_version (step09=$step09_ok, mspcore=$mspcore_ok)"
    fi
}

# Run tests
echo "Running XCFramework version ordering tests..."
echo "========================================"

test_old_adapter_version_block_removed
test_novacore_version_before_build
test_mspnovaadapter_rebuild_after_novacore
test_mspcore_rebuild_after_config_plist_update
test_adapters_extracted_early
test_dry_run_guards_novaadapter_rebuild
test_mspcore_uses_build_core_script
test_no_duplicate_adapters_extraction
test_step_09_calls_ssot_functions
test_step_09_before_step_0
test_normal_path_uses_unified_commit
test_uses_dry_update_and_commit

echo "========================================"
echo "All tests passed!"
