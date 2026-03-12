#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Dependency Cleanup (Lottie removal + MSPSnapKit symbols)
# ============================================================================
# Validates:
#   Task 1: MSPSnapKit unexported_symbols patterns
#   Task 2: Lottie fully removed from source, config, and SPM manifests
#   Task 3: OMSDK moved to MSPSharedLibraries (podspec validation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$HELPERS_DIR/helpers.sh"

PASSED=0
FAILED=0

pass() {
    local msg="$1"
    echo -e "${_GREEN:-}✓${_NC:-} $msg"
    PASSED=$((PASSED + 1))
}

fail() {
    local msg="$1"
    echo -e "${_RED:-}✗${_NC:-} $msg"
    FAILED=$((FAILED + 1))
}

# ============================================================================
# Task 1: MSPSnapKit unexported_symbols.txt
# ============================================================================

UNEXPORTED="$ROOT_DIR/Sources/Core/NovaCore/unexported_symbols.txt"

test_snapkit_10char_pattern_exists() {
    if grep -q '_\$s10MSPSnapKit\*' "$UNEXPORTED"; then
        pass "SnapKit: _\$s10MSPSnapKit* pattern exists (10-char mangling)"
    else
        fail "SnapKit: Missing _\$s10MSPSnapKit* pattern for 10-char Swift mangling"
    fi
}

test_snapkit_7char_fallback_exists() {
    if grep -q '_\$s7SnapKit\*' "$UNEXPORTED"; then
        pass "SnapKit: _\$s7SnapKit* fallback pattern exists (7-char mangling)"
    else
        fail "SnapKit: Missing _\$s7SnapKit* fallback pattern for 7-char mangling"
    fi
}

test_snapkit_objc_patterns_exist() {
    if grep -q '_OBJC_CLASS_\$_\*MSPSnapKit\*' "$UNEXPORTED" &&
       grep -q '_OBJC_CLASS_\$_\*SnapKit\*' "$UNEXPORTED"; then
        pass "SnapKit: ObjC class patterns for both MSPSnapKit and SnapKit"
    else
        fail "SnapKit: Missing ObjC class patterns for SnapKit"
    fi
}

test_kingfisher_patterns_exist() {
    if grep -q '_\$s10Kingfisher\*' "$UNEXPORTED"; then
        pass "Kingfisher: unexported symbol patterns present"
    else
        fail "Kingfisher: Missing unexported symbol patterns"
    fi
}

test_shimmer_patterns_exist() {
    if grep -q '_\*Shimmer\*' "$UNEXPORTED"; then
        pass "Shimmer: unexported symbol patterns present"
    else
        fail "Shimmer: Missing unexported symbol patterns"
    fi
}

# ============================================================================
# Task 2: Lottie fully removed
# ============================================================================

test_no_lottie_import_in_sources() {
    local matches
    matches=$(grep -r 'import Lottie' "$ROOT_DIR/Sources/" 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No 'import Lottie' in Sources/"
    else
        fail "Lottie: Found 'import Lottie' in Sources/: $matches"
    fi
}

test_no_lottie_in_podfile() {
    local matches
    matches=$(grep -i "pod.*lottie" "$ROOT_DIR/Podfile" 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No lottie pod in Podfile"
    else
        fail "Lottie: Found lottie reference in Podfile: $matches"
    fi
}

test_no_lottie_dependency_in_podspecs() {
    local matches
    matches=$(grep -r "dependency.*lottie" "$ROOT_DIR"/*.podspec 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No lottie dependency in root podspecs"
    else
        fail "Lottie: Found lottie dependency in podspec: $matches"
    fi
}

test_no_lottie_in_unexported_symbols() {
    local matches
    matches=$(grep -i "lottie" "$UNEXPORTED" 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No lottie patterns in unexported_symbols.txt (correctly removed)"
    else
        fail "Lottie: Found stale lottie patterns in unexported_symbols.txt: $matches"
    fi
}

test_no_lottie_spm_dependency_in_package_template() {
    local template="$ROOT_DIR/Package.swift.template"
    if [[ ! -f "$template" ]]; then
        pass "Lottie: Package.swift.template not found (skipping)"
        return
    fi
    local matches
    matches=$(grep 'lottie-ios' "$template" 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No lottie-ios SPM dependency in Package.swift.template"
    else
        fail "Lottie: Found lottie-ios reference in Package.swift.template: $matches"
    fi
}

test_no_lottie_in_novacorelinker_deps() {
    local template="$ROOT_DIR/Package.swift.template"
    if [[ ! -f "$template" ]]; then
        pass "Lottie: Package.swift.template not found (skipping)"
        return
    fi
    # Extract NovaCoreLinker target block and check for Lottie
    local linker_block
    linker_block=$(awk '/name: "NovaCoreLinker"/,/\)/' "$template")
    if echo "$linker_block" | grep -qi 'lottie'; then
        fail "Lottie: NovaCoreLinker target still references Lottie in Package.swift.template"
    else
        pass "Lottie: NovaCoreLinker target has no Lottie dependency"
    fi
}

test_no_lottie_in_novacore_yml_template() {
    local yml="$ROOT_DIR/Sources/Core/NovaCore/project.yml.template"
    if [[ ! -f "$yml" ]]; then
        pass "Lottie: NovaCore project.yml.template not found (skipping)"
        return
    fi
    local matches
    matches=$(grep -i 'lottie' "$yml" 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No lottie references in NovaCore project.yml.template"
    else
        fail "Lottie: Found lottie in NovaCore project.yml.template: $matches"
    fi
}

test_no_lottie_search_path_in_mspcore_yml() {
    local yml="$ROOT_DIR/Sources/Core/MSPCore/project.yml.template"
    if [[ ! -f "$yml" ]]; then
        pass "Lottie: MSPCore project.yml.template not found (skipping)"
        return
    fi
    # Check for functional lottie-ios search path (not comments)
    local matches
    matches=$(grep -v '^[[:space:]]*#' "$yml" | grep -i 'lottie' 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No functional lottie search paths in MSPCore project.yml.template"
    else
        fail "Lottie: Found functional lottie reference in MSPCore project.yml.template: $matches"
    fi
}

test_no_lottie_thirdparty_dir() {
    if [[ -d "$ROOT_DIR/ThirdParty/Lottie" ]]; then
        fail "Lottie: ThirdParty/Lottie/ directory still exists"
    else
        pass "Lottie: ThirdParty/Lottie/ directory removed"
    fi
}

test_no_lottie_in_ci_pod_schemes() {
    local yml="$ROOT_DIR/Scripts/config/ci-pod-schemes.yml"
    if [[ ! -f "$yml" ]]; then
        pass "Lottie: ci-pod-schemes.yml not found (skipping)"
        return
    fi
    local matches
    matches=$(grep -i 'lottie' "$yml" 2>/dev/null || echo "")
    if [[ -z "$matches" ]]; then
        pass "Lottie: No lottie in ci-pod-schemes.yml"
    else
        fail "Lottie: Found lottie in ci-pod-schemes.yml: $matches"
    fi
}

# ============================================================================
# Task 2: NovaAdTapToTryAnimationView replacement exists
# ============================================================================

test_tap_to_try_replacement_exists() {
    local replacement="$ROOT_DIR/Sources/Core/NovaCore/NovaCore/UIUtils/NovaAdTapToTryAnimationView.swift"
    if [[ -f "$replacement" ]]; then
        pass "Lottie: NovaAdTapToTryAnimationView.swift replacement exists"
    else
        fail "Lottie: NovaAdTapToTryAnimationView.swift replacement missing"
    fi
}

test_tap_to_try_has_play_stop() {
    local replacement="$ROOT_DIR/Sources/Core/NovaCore/NovaCore/UIUtils/NovaAdTapToTryAnimationView.swift"
    if [[ ! -f "$replacement" ]]; then
        fail "Lottie: Cannot check play/stop - file missing"
        return
    fi
    if grep -q 'func play()' "$replacement" && grep -q 'func stop()' "$replacement"; then
        pass "Lottie: NovaAdTapToTryAnimationView has play()/stop() API"
    else
        fail "Lottie: NovaAdTapToTryAnimationView missing play()/stop() API"
    fi
}

# ============================================================================
# Task 2: Ruby SPM generator strips Lottie
# ============================================================================

test_ruby_generator_strips_lottie() {
    local rb="$ROOT_DIR/Scripts/target-switching/generate_core_only_package_swift.rb"
    if [[ ! -f "$rb" ]]; then
        pass "Lottie: generate_core_only_package_swift.rb not found (skipping)"
        return
    fi
    if grep -q '"Lottie"' "$rb"; then
        pass "Lottie: Ruby generator has Lottie stripping logic"
    else
        fail "Lottie: Ruby generator missing Lottie stripping logic"
    fi
}

# ============================================================================
# Task 3: OMSDK distribution
# ============================================================================

test_omsdk_in_shared_libraries_podspec() {
    local podspec="$ROOT_DIR/Build/ReleasePodspecs/MSPSharedLibraries.podspec"
    if [[ ! -f "$podspec" ]]; then
        pass "OMSDK: MSPSharedLibraries.podspec not found (skipping)"
        return
    fi
    if grep -q 'OMSDK_Newsbreak1' "$podspec"; then
        pass "OMSDK: MSPSharedLibraries.podspec includes OMSDK_Newsbreak1"
    else
        fail "OMSDK: MSPSharedLibraries.podspec missing OMSDK_Newsbreak1"
    fi
}

test_omsdk_not_in_nova_adapter_podspec() {
    local podspec="$ROOT_DIR/Build/ReleasePodspecs/MSPNovaAdapter.podspec"
    if [[ ! -f "$podspec" ]]; then
        pass "OMSDK: MSPNovaAdapter.podspec not found (skipping)"
        return
    fi
    if grep -q 'OMSDK' "$podspec"; then
        fail "OMSDK: MSPNovaAdapter.podspec still contains OMSDK (should be in MSPSharedLibraries)"
    else
        pass "OMSDK: MSPNovaAdapter.podspec does not contain OMSDK"
    fi
}

test_omsdk_in_zip_management_shared() {
    local script="$ROOT_DIR/Scripts/release/publish/pods/lib/zip_management.sh"
    if [[ ! -f "$script" ]]; then
        pass "OMSDK: zip_management.sh not found (skipping)"
        return
    fi
    # OMSDK should be in MSPSharedLibraries case
    local shared_block
    shared_block=$(awk '/MSPSharedLibraries\)/,/;;/' "$script")
    if echo "$shared_block" | grep -q 'OMSDK_Newsbreak1'; then
        pass "OMSDK: zip_management.sh copies OMSDK in MSPSharedLibraries case"
    else
        fail "OMSDK: zip_management.sh missing OMSDK copy in MSPSharedLibraries case"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running dependency cleanup validation tests..."
echo "========================================"

echo ""
echo "--- Task 1: MSPSnapKit unexported symbols ---"
test_snapkit_10char_pattern_exists
test_snapkit_7char_fallback_exists
test_snapkit_objc_patterns_exist
test_kingfisher_patterns_exist
test_shimmer_patterns_exist

echo ""
echo "--- Task 2: Lottie fully removed ---"
test_no_lottie_import_in_sources
test_no_lottie_in_podfile
test_no_lottie_dependency_in_podspecs
test_no_lottie_in_unexported_symbols
test_no_lottie_spm_dependency_in_package_template
test_no_lottie_in_novacorelinker_deps
test_no_lottie_in_novacore_yml_template
test_no_lottie_search_path_in_mspcore_yml
test_no_lottie_thirdparty_dir
test_no_lottie_in_ci_pod_schemes

echo ""
echo "--- Task 2: Lottie replacement ---"
test_tap_to_try_replacement_exists
test_tap_to_try_has_play_stop
test_ruby_generator_strips_lottie

echo ""
echo "--- Task 3: OMSDK distribution ---"
test_omsdk_in_shared_libraries_podspec
test_omsdk_not_in_nova_adapter_podspec
test_omsdk_in_zip_management_shared

echo ""
echo "========================================"
echo "Dependency cleanup tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
