#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Package.swift Integrity
# ============================================================================
# Validates:
#   - NovaCoreLinker dependencies are correct
#   - No orphan SPM dependencies (declared but unused)
#   - Package.swift.template and Package.swift consistency for key patterns

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

TEMPLATE="$ROOT_DIR/Package.swift.template"
GENERATED="$ROOT_DIR/Package.swift"

# ============================================================================
# Package.swift.template validation
# ============================================================================

test_template_no_lottie_dependency() {
    if [[ ! -f "$TEMPLATE" ]]; then
        pass "Template: not found (skipping)"
        return
    fi
    # Check dependencies section for lottie-ios package
    local dep_section
    dep_section=$(awk '/dependencies: \[/,/\]/' "$TEMPLATE")
    if echo "$dep_section" | grep -q 'lottie-ios'; then
        fail "Template: dependencies section still declares lottie-ios package"
    else
        pass "Template: No lottie-ios in dependencies section"
    fi
}

test_template_novacorelinker_no_lottie() {
    if [[ ! -f "$TEMPLATE" ]]; then
        pass "Template: not found (skipping)"
        return
    fi
    local linker_block
    linker_block=$(awk '/name: "NovaCoreLinker"/,/\)/' "$TEMPLATE")
    if echo "$linker_block" | grep -q 'Lottie'; then
        fail "Template: NovaCoreLinker still depends on Lottie"
    else
        pass "Template: NovaCoreLinker has no Lottie dependency"
    fi
}

test_template_novacorelinker_has_shimmer() {
    if [[ ! -f "$TEMPLATE" ]]; then
        pass "Template: not found (skipping)"
        return
    fi
    local linker_block
    linker_block=$(awk '/name: "NovaCoreLinker"/,/\)/' "$TEMPLATE")
    if echo "$linker_block" | grep -q '"Shimmer"'; then
        pass "Template: NovaCoreLinker depends on Shimmer"
    else
        fail "Template: NovaCoreLinker should depend on Shimmer"
    fi
}

test_template_novacorelinker_has_novacore() {
    if [[ ! -f "$TEMPLATE" ]]; then
        pass "Template: not found (skipping)"
        return
    fi
    local linker_block
    linker_block=$(awk '/name: "NovaCoreLinker"/,/\)/' "$TEMPLATE")
    if echo "$linker_block" | grep -q '"NovaCore"'; then
        pass "Template: NovaCoreLinker depends on NovaCore"
    else
        fail "Template: NovaCoreLinker should depend on NovaCore"
    fi
}

test_template_mspcorelinker_has_protobuf() {
    if [[ ! -f "$TEMPLATE" ]]; then
        pass "Template: not found (skipping)"
        return
    fi
    local linker_block
    linker_block=$(awk '/name: "MSPCoreLinker"/,/\)/' "$TEMPLATE")
    if echo "$linker_block" | grep -q 'SwiftProtobuf'; then
        pass "Template: MSPCoreLinker depends on SwiftProtobuf"
    else
        fail "Template: MSPCoreLinker should depend on SwiftProtobuf"
    fi
}

# ============================================================================
# No orphan dependencies
# ============================================================================

test_template_no_orphan_dependencies() {
    if [[ ! -f "$TEMPLATE" ]]; then
        pass "Template: not found (skipping)"
        return
    fi
    # Every .package() in dependencies should be referenced by at least one .product(name:, package:)
    # Extract package short names from .product(name: "X", package: "Y") usage
    local orphans=0

    # Extract declared package URLs and derive short names
    # e.g. "https://github.com/airbnb/lottie-ios.git" → "lottie-ios"
    local declared_packages
    declared_packages=$(grep -oE 'url: "https://[^"]*"' "$TEMPLATE" | sed 's|url: "https://.*/||;s|\.git"||' | sort -u)

    for pkg in $declared_packages; do
        # Check if this package is referenced by any .product(name:, package:) in targets
        if grep -q "package: \"$pkg\"" "$TEMPLATE"; then
            : # used
        else
            fail "Template: Orphan SPM dependency '$pkg' declared but not used by any target"
            orphans=$((orphans + 1))
        fi
    done

    if [[ $orphans -eq 0 ]]; then
        pass "Template: No orphan SPM dependencies"
    fi
}

# ============================================================================
# Generated Package.swift validation
# ============================================================================

test_generated_no_lottie_dependency() {
    if [[ ! -f "$GENERATED" ]]; then
        pass "Generated: Package.swift not found (skipping)"
        return
    fi
    local dep_section
    dep_section=$(awk '/dependencies: \[/,/\]/' "$GENERATED")
    if echo "$dep_section" | grep -q 'lottie-ios'; then
        fail "Generated: dependencies section still declares lottie-ios package"
    else
        pass "Generated: No lottie-ios in dependencies section"
    fi
}

test_generated_novacorelinker_no_lottie() {
    if [[ ! -f "$GENERATED" ]]; then
        pass "Generated: Package.swift not found (skipping)"
        return
    fi
    local linker_block
    linker_block=$(awk '/name: "NovaCoreLinker"/,/\)/' "$GENERATED")
    if echo "$linker_block" | grep -q 'Lottie'; then
        fail "Generated: NovaCoreLinker still depends on Lottie"
    else
        pass "Generated: NovaCoreLinker has no Lottie dependency"
    fi
}

# ============================================================================
# Template ↔ Generated consistency for key patterns
# ============================================================================

test_consistency_spm_dependency_count() {
    if [[ ! -f "$TEMPLATE" ]] || [[ ! -f "$GENERATED" ]]; then
        pass "Consistency: Missing file(s) (skipping)"
        return
    fi
    local template_deps generated_deps
    template_deps=$(grep -c '\.package(' "$TEMPLATE" || echo 0)
    generated_deps=$(grep -c '\.package(' "$GENERATED" || echo 0)

    # Generated may have fewer (stripped by Ruby), but should not have MORE
    if [[ "$generated_deps" -le "$template_deps" ]]; then
        pass "Consistency: Generated ($generated_deps) <= Template ($template_deps) SPM deps"
    else
        fail "Consistency: Generated has MORE SPM deps ($generated_deps) than template ($template_deps)"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running Package.swift integrity tests..."
echo "========================================"

echo ""
echo "--- Package.swift.template ---"
test_template_no_lottie_dependency
test_template_novacorelinker_no_lottie
test_template_novacorelinker_has_shimmer
test_template_novacorelinker_has_novacore
test_template_mspcorelinker_has_protobuf
test_template_no_orphan_dependencies

echo ""
echo "--- Generated Package.swift ---"
test_generated_no_lottie_dependency
test_generated_novacorelinker_no_lottie

echo ""
echo "--- Template ↔ Generated consistency ---"
test_consistency_spm_dependency_count

echo ""
echo "========================================"
echo "Package.swift integrity tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
