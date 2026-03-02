#!/usr/bin/env bash
# ============================================================================
# Unit Tests for update_demo_app_version() in Scripts/release/utils/version.sh
# ============================================================================
# Tests MARKETING_VERSION update logic in project.yml.template and update.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

# Stub logging functions
log::info()    { :; }
log::error()   { :; }
log::warn()    { :; }
log::success() { :; }
log::debug()   { :; }
log::step()    { :; }

# ============================================================================
# Test Setup
# ============================================================================

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

setup_test_env() {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create project.yml.template with MARKETING_VERSION
    mkdir -p "$tmpdir/Examples/MSPDemoApp"
    cat > "$tmpdir/Examples/MSPDemoApp/project.yml.template" <<'EOF'
name: MSPDemoApp
settings:
  base:
    CURRENT_PROJECT_VERSION: 1
    DEVELOPMENT_TEAM: 4PEHUZX8QH
    MARKETING_VERSION: 0.0.117
    PRODUCT_BUNDLE_IDENTIFIER: MSPDemoApp.MSPDemoApp
    SWIFT_VERSION: 5.0
EOF

    # Create update.sh with MARKETING_VERSION
    mkdir -p "$tmpdir/Scripts/workspace"
    cat > "$tmpdir/Scripts/workspace/update.sh" <<'EOF'
settings:
  base:
    DEVELOPMENT_TEAM: 4PEHUZX8QH
    PRODUCT_BUNDLE_IDENTIFIER: MSPDemoApp.MSPDemoApp
    SWIFT_VERSION: 5.0
    CURRENT_PROJECT_VERSION: 1
    MARKETING_VERSION: 0.0.117
    TARGETED_DEVICE_FAMILY: "1,2"
EOF

    echo "$tmpdir"
}

# Define the function under test directly to avoid sourcing the full version.sh
# (which has dependencies on path-helpers.sh, common.sh, etc.)
update_demo_app_version() {
    local version="$1"
    local root="${ROOT_DIR:-.}"
    local template="$root/Examples/MSPDemoApp/project.yml.template"
    local update_sh="$root/Scripts/workspace/update.sh"

    if [[ -f "$template" ]]; then
        sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: ${version}/" "$template"
        log::info "VERSION" "Updated MARKETING_VERSION in project.yml.template to $version"
    else
        log::warn "VERSION" "project.yml.template not found: $template"
    fi

    if [[ -f "$update_sh" ]]; then
        sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: ${version}/" "$update_sh"
        log::info "VERSION" "Updated MARKETING_VERSION in update.sh to $version"
    else
        log::warn "VERSION" "update.sh not found: $update_sh"
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_updates_template_version() {
    local tmpdir
    tmpdir=$(setup_test_env)
    ROOT_DIR="$tmpdir"

    update_demo_app_version "1.2.3"

    local result
    result=$(grep "MARKETING_VERSION:" "$tmpdir/Examples/MSPDemoApp/project.yml.template")

    if [[ "$result" == *"MARKETING_VERSION: 1.2.3"* ]]; then
        pass "project.yml.template MARKETING_VERSION updated to 1.2.3"
    else
        fail "project.yml.template not updated. Got: $result"
    fi

    rm -rf "$tmpdir"
}

test_updates_update_sh_version() {
    local tmpdir
    tmpdir=$(setup_test_env)
    ROOT_DIR="$tmpdir"

    update_demo_app_version "1.2.3"

    local result
    result=$(grep "MARKETING_VERSION:" "$tmpdir/Scripts/workspace/update.sh")

    if [[ "$result" == *"MARKETING_VERSION: 1.2.3"* ]]; then
        pass "update.sh MARKETING_VERSION updated to 1.2.3"
    else
        fail "update.sh not updated. Got: $result"
    fi

    rm -rf "$tmpdir"
}

test_preserves_other_lines() {
    local tmpdir
    tmpdir=$(setup_test_env)
    ROOT_DIR="$tmpdir"

    update_demo_app_version "2.0.0"

    # Check that other settings are untouched
    if grep -q "SWIFT_VERSION: 5.0" "$tmpdir/Examples/MSPDemoApp/project.yml.template" && \
       grep -q "DEVELOPMENT_TEAM: 4PEHUZX8QH" "$tmpdir/Examples/MSPDemoApp/project.yml.template" && \
       grep -q "CURRENT_PROJECT_VERSION: 1" "$tmpdir/Examples/MSPDemoApp/project.yml.template"; then
        pass "Other YAML settings preserved in project.yml.template"
    else
        fail "Other YAML settings were modified in project.yml.template"
    fi

    if grep -q "SWIFT_VERSION: 5.0" "$tmpdir/Scripts/workspace/update.sh" && \
       grep -q "TARGETED_DEVICE_FAMILY:" "$tmpdir/Scripts/workspace/update.sh"; then
        pass "Other YAML settings preserved in update.sh"
    else
        fail "Other YAML settings were modified in update.sh"
    fi

    rm -rf "$tmpdir"
}

test_handles_missing_template() {
    local tmpdir
    tmpdir=$(mktemp -d)
    ROOT_DIR="$tmpdir"

    # No files created — should not error
    local exit_code=0
    update_demo_app_version "1.0.0" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "Gracefully handles missing project.yml.template"
    else
        fail "Should not fail when template is missing, got exit code: $exit_code"
    fi

    rm -rf "$tmpdir"
}

test_handles_missing_update_sh() {
    local tmpdir
    tmpdir=$(mktemp -d)
    ROOT_DIR="$tmpdir"

    # Create only the template, not update.sh
    mkdir -p "$tmpdir/Examples/MSPDemoApp"
    echo "    MARKETING_VERSION: 0.0.1" > "$tmpdir/Examples/MSPDemoApp/project.yml.template"

    local exit_code=0
    update_demo_app_version "1.0.0" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "Gracefully handles missing update.sh"
    else
        fail "Should not fail when update.sh is missing, got exit code: $exit_code"
    fi

    # Template should still be updated
    if grep -q "MARKETING_VERSION: 1.0.0" "$tmpdir/Examples/MSPDemoApp/project.yml.template"; then
        pass "Template still updated even when update.sh missing"
    else
        fail "Template should be updated even when update.sh is missing"
    fi

    rm -rf "$tmpdir"
}

test_version_with_prerelease_suffix() {
    local tmpdir
    tmpdir=$(setup_test_env)
    ROOT_DIR="$tmpdir"

    update_demo_app_version "1.0.0-rc.1"

    local template_result
    template_result=$(grep "MARKETING_VERSION:" "$tmpdir/Examples/MSPDemoApp/project.yml.template")

    if [[ "$template_result" == *"MARKETING_VERSION: 1.0.0-rc.1"* ]]; then
        pass "Handles pre-release version suffix correctly"
    else
        fail "Pre-release version not handled. Got: $template_result"
    fi

    rm -rf "$tmpdir"
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running update_demo_app_version() unit tests..."
echo "============================================"

test_updates_template_version
test_updates_update_sh_version
test_preserves_other_lines
test_handles_missing_template
test_handles_missing_update_sh
test_version_with_prerelease_suffix

echo "============================================"
echo "DemoApp version tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
