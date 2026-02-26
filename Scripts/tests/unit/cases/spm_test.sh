#!/usr/bin/env bash
# ============================================================================
# Unit Tests for spm.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

# Source module under test
source "$ROOT_DIR/Scripts/lib/spm.sh"

# ============================================================================
# Test Setup/Teardown
# ============================================================================

TEMP_DIR=""
PASSED=0
FAILED=0

setup() {
    TEMP_DIR=$(mktemp -d)
}

teardown() {
    [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

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
# Test Cases
# ============================================================================

test_module_guard() {
    # Module should already be sourced
    if [[ -n "${_SPM_SOURCED:-}" ]]; then
        pass "Module guard variable is set"
    else
        fail "Module guard variable not set"
    fi
}

test_spm_check_manifest_exists_found() {
    setup

    # Create test Package.swift
    cat > "$TEMP_DIR/Package.swift" << 'EOF'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "TestPackage")
EOF

    if spm_check_manifest_exists "$TEMP_DIR"; then
        pass "spm_check_manifest_exists returns true when Package.swift exists"
    else
        fail "spm_check_manifest_exists should return true when Package.swift exists"
    fi

    teardown
}

test_spm_check_manifest_exists_not_found() {
    setup

    # Empty directory - no Package.swift
    if ! spm_check_manifest_exists "$TEMP_DIR"; then
        pass "spm_check_manifest_exists returns false when Package.swift missing"
    else
        fail "spm_check_manifest_exists should return false when Package.swift missing"
    fi

    teardown
}

test_spm_validate_manifest_valid() {
    setup

    # Create valid Package.swift
    cat > "$TEMP_DIR/Package.swift" << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestPackage",
    products: [
        .library(name: "TestLib", targets: ["TestLib"])
    ],
    targets: [
        .target(name: "TestLib")
    ]
)
EOF

    if spm_validate_manifest "$TEMP_DIR" 2>/dev/null; then
        pass "spm_validate_manifest returns 0 for valid Package.swift"
    else
        fail "spm_validate_manifest should return 0 for valid Package.swift"
    fi

    teardown
}

test_spm_validate_manifest_missing_import() {
    setup

    # Create Package.swift without import
    cat > "$TEMP_DIR/Package.swift" << 'EOF'
let package = Package(name: "TestPackage")
EOF

    if ! spm_validate_manifest "$TEMP_DIR" 2>/dev/null; then
        pass "spm_validate_manifest returns 1 for missing import"
    else
        fail "spm_validate_manifest should return 1 for missing import"
    fi

    teardown
}

test_spm_validate_manifest_not_found() {
    setup

    if ! spm_validate_manifest "$TEMP_DIR/nonexistent" 2>/dev/null; then
        pass "spm_validate_manifest returns 1 for missing file"
    else
        fail "spm_validate_manifest should return 1 for missing file"
    fi

    teardown
}

test_spm_extract_targets() {
    setup

    # Create Package.swift with targets
    cat > "$TEMP_DIR/Package.swift" << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestPackage",
    targets: [
        .target(name: "MSPCore"),
        .target(name: "MSPiOSCore"),
        .binaryTarget(name: "ThirdParty", path: "ThirdParty.xcframework")
    ]
)
EOF

    local targets
    targets=$(spm_extract_targets "$TEMP_DIR")

    if echo "$targets" | grep -q "MSPCore"; then
        pass "spm_extract_targets finds .target entries"
    else
        fail "spm_extract_targets should find .target entries"
    fi

    if echo "$targets" | grep -q "ThirdParty"; then
        pass "spm_extract_targets finds .binaryTarget entries"
    else
        fail "spm_extract_targets should find .binaryTarget entries"
    fi

    teardown
}

test_spm_patch_package_swift_url() {
    setup

    # Create Package.swift with binaryTarget
    cat > "$TEMP_DIR/Package.swift" << 'EOF'
.binaryTarget(
    name: "TestFramework",
    url: "https://old.example.com/test.zip", // TestFramework
    checksum: "abc123"
)
EOF

    if spm_patch_package_swift "$TEMP_DIR/Package.swift" "TestFramework" "url" "https://new.example.com/test.zip"; then
        if grep -q "https://new.example.com/test.zip" "$TEMP_DIR/Package.swift"; then
            pass "spm_patch_package_swift updates url correctly"
        else
            fail "spm_patch_package_swift did not update url in file"
        fi
    else
        fail "spm_patch_package_swift should return 0 on success"
    fi

    teardown
}

test_spm_patch_package_swift_checksum() {
    setup

    # Create Package.swift with binaryTarget
    cat > "$TEMP_DIR/Package.swift" << 'EOF'
.binaryTarget(
    name: "TestFramework",
    url: "https://example.com/test.zip",
    checksum: "oldchecksum123" // TestFramework
)
EOF

    if spm_patch_package_swift "$TEMP_DIR/Package.swift" "TestFramework" "checksum" "newchecksum456"; then
        if grep -q "newchecksum456" "$TEMP_DIR/Package.swift"; then
            pass "spm_patch_package_swift updates checksum correctly"
        else
            fail "spm_patch_package_swift did not update checksum in file"
        fi
    else
        fail "spm_patch_package_swift should return 0 on success"
    fi

    teardown
}

test_spm_patch_package_swift_invalid_type() {
    setup

    cat > "$TEMP_DIR/Package.swift" << 'EOF'
.binaryTarget(name: "Test")
EOF

    if ! spm_patch_package_swift "$TEMP_DIR/Package.swift" "Test" "invalid_type" "value" 2>/dev/null; then
        pass "spm_patch_package_swift returns 1 for invalid change type"
    else
        fail "spm_patch_package_swift should return 1 for invalid change type"
    fi

    teardown
}

test_spm_update_version() {
    setup

    cat > "$TEMP_DIR/Package.swift" << 'EOF'
import PackageDescription
let package = Package(
    name: "TestPackage",
    version: "1.0.0"
)
EOF

    if spm_update_version "$TEMP_DIR" "2.0.0"; then
        pass "spm_update_version returns 0 on success"
    else
        fail "spm_update_version should return 0"
    fi

    teardown
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running spm.sh unit tests..."
echo "============================================"

test_module_guard
test_spm_check_manifest_exists_found
test_spm_check_manifest_exists_not_found
test_spm_validate_manifest_valid
test_spm_validate_manifest_missing_import
test_spm_validate_manifest_not_found
test_spm_extract_targets
test_spm_patch_package_swift_url
test_spm_patch_package_swift_checksum
test_spm_patch_package_swift_invalid_type
test_spm_update_version

echo "============================================"
echo "SPM module tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
