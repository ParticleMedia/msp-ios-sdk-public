#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/testflight/deploy.sh
# ============================================================================
# Tests CLI argument parsing and the ExportOptions.plist template integrity.
# Does NOT invoke the actual build pipeline — that requires Xcode and credentials.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

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

# ============================================================================
# Test Cases
# ============================================================================

test_deploy_help_flag() {
    local output
    output=$("$ROOT_DIR/Scripts/testflight/deploy.sh" --help 2>&1) || true

    if [[ "$output" == *"--dry-run"* ]] && [[ "$output" == *"--build-number"* ]]; then
        pass "--help shows usage with --dry-run and --build-number"
    else
        fail "--help output should contain --dry-run and --build-number"
    fi
}

test_deploy_unknown_flag() {
    local exit_code=0
    "$ROOT_DIR/Scripts/testflight/deploy.sh" --unknown-flag 2>/dev/null || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        pass "Unknown flag causes non-zero exit"
    else
        fail "Unknown flag should cause non-zero exit"
    fi
}

test_deploy_build_number_requires_value() {
    local exit_code=0
    "$ROOT_DIR/Scripts/testflight/deploy.sh" --build-number 2>/dev/null || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        pass "--build-number without value causes non-zero exit"
    else
        fail "--build-number without value should fail"
    fi
}

test_export_options_plist_exists() {
    local plist="$ROOT_DIR/Scripts/testflight/templates/ExportOptions.plist"

    if [[ -f "$plist" ]]; then
        pass "ExportOptions.plist exists"
    else
        fail "ExportOptions.plist not found at $plist"
    fi
}

test_export_options_plist_method() {
    local plist="$ROOT_DIR/Scripts/testflight/templates/ExportOptions.plist"
    local content
    content=$(cat "$plist")

    if [[ "$content" == *"<string>app-store</string>"* ]]; then
        pass "ExportOptions.plist has method=app-store"
    else
        fail "ExportOptions.plist should contain method=app-store"
    fi
}

test_export_options_plist_team_id() {
    local plist="$ROOT_DIR/Scripts/testflight/templates/ExportOptions.plist"
    local content
    content=$(cat "$plist")

    if [[ "$content" == *"<string>4PEHUZX8QH</string>"* ]]; then
        pass "ExportOptions.plist has correct teamID"
    else
        fail "ExportOptions.plist should contain teamID=4PEHUZX8QH"
    fi
}

test_export_options_plist_signing_style() {
    local plist="$ROOT_DIR/Scripts/testflight/templates/ExportOptions.plist"
    local content
    content=$(cat "$plist")

    if [[ "$content" == *"<string>automatic</string>"* ]]; then
        pass "ExportOptions.plist has signingStyle=automatic"
    else
        fail "ExportOptions.plist should contain signingStyle=automatic"
    fi
}

test_export_options_plist_valid_xml() {
    local plist="$ROOT_DIR/Scripts/testflight/templates/ExportOptions.plist"

    if command -v plutil >/dev/null 2>&1; then
        if plutil -lint "$plist" >/dev/null 2>&1; then
            pass "ExportOptions.plist is valid plist XML"
        else
            fail "ExportOptions.plist is not valid plist XML"
        fi
    elif command -v xmllint >/dev/null 2>&1; then
        if xmllint --noout "$plist" 2>/dev/null; then
            pass "ExportOptions.plist is valid XML"
        else
            fail "ExportOptions.plist is not valid XML"
        fi
    else
        pass "ExportOptions.plist XML validation skipped (no plutil/xmllint)"
    fi
}

test_config_yaml_exists() {
    local config="$ROOT_DIR/Scripts/testflight/config.yaml"

    if [[ -f "$config" ]]; then
        pass "config.yaml exists"
    else
        fail "config.yaml not found at $config"
    fi
}

test_config_yaml_has_build_number() {
    local config="$ROOT_DIR/Scripts/testflight/config.yaml"
    local value
    value=$(grep "^build_number:" "$config" | awk '{print $2}')

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        pass "config.yaml has numeric build_number: $value"
    else
        fail "config.yaml build_number should be numeric, got: ${value:-<empty>}"
    fi
}

test_deploy_script_is_executable() {
    if [[ -x "$ROOT_DIR/Scripts/testflight/deploy.sh" ]]; then
        pass "deploy.sh is executable"
    else
        fail "deploy.sh should be executable"
    fi
}

test_all_lib_modules_have_guards() {
    local lib_dir="$ROOT_DIR/Scripts/testflight/lib"
    local all_guarded=true

    for module in "$lib_dir"/*.sh; do
        local basename
        basename=$(basename "$module")
        if ! grep -q '_SOURCED' "$module"; then
            fail "Module $basename missing sourcing guard"
            all_guarded=false
        fi
    done

    if [[ "$all_guarded" == "true" ]]; then
        pass "All lib modules have sourcing guards"
    fi
}

test_all_lib_modules_have_shebang() {
    local lib_dir="$ROOT_DIR/Scripts/testflight/lib"
    local all_ok=true

    for module in "$lib_dir"/*.sh; do
        local first_line
        first_line=$(head -1 "$module")
        if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
            fail "Module $(basename "$module") missing #!/usr/bin/env bash shebang"
            all_ok=false
        fi
    done

    if [[ "$all_ok" == "true" ]]; then
        pass "All lib modules have correct shebang"
    fi
}

test_deploy_sources_version_sh() {
    local deploy="$ROOT_DIR/Scripts/testflight/deploy.sh"

    if grep -q 'source.*Scripts/release/utils/version\.sh' "$deploy"; then
        pass "deploy.sh sources version.sh for SSOT access"
    else
        fail "deploy.sh should source Scripts/release/utils/version.sh"
    fi
}

test_deploy_reads_ssot() {
    local deploy="$ROOT_DIR/Scripts/testflight/deploy.sh"

    if grep -q 'read_sdk_version_from_config' "$deploy"; then
        pass "deploy.sh reads SDK version from SSOT"
    else
        fail "deploy.sh should call read_sdk_version_from_config"
    fi
}

test_deploy_exports_tf_sdk_version() {
    local deploy="$ROOT_DIR/Scripts/testflight/deploy.sh"

    if grep -q 'export TF_SDK_VERSION' "$deploy"; then
        pass "deploy.sh exports TF_SDK_VERSION"
    else
        fail "deploy.sh should export TF_SDK_VERSION"
    fi
}

test_archive_uses_marketing_version() {
    local archive="$ROOT_DIR/Scripts/testflight/lib/archive.sh"

    if grep -q 'MARKETING_VERSION=.*TF_SDK_VERSION' "$archive"; then
        pass "archive.sh injects MARKETING_VERSION from TF_SDK_VERSION"
    else
        fail "archive.sh should set MARKETING_VERSION from TF_SDK_VERSION"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running testflight deploy integration tests..."
echo "============================================"

test_deploy_help_flag
test_deploy_unknown_flag
test_deploy_build_number_requires_value
test_export_options_plist_exists
test_export_options_plist_method
test_export_options_plist_team_id
test_export_options_plist_signing_style
test_export_options_plist_valid_xml
test_config_yaml_exists
test_config_yaml_has_build_number
test_deploy_script_is_executable
test_all_lib_modules_have_guards
test_all_lib_modules_have_shebang
test_deploy_sources_version_sh
test_deploy_reads_ssot
test_deploy_exports_tf_sdk_version
test_archive_uses_marketing_version

echo "============================================"
echo "TestFlight deploy tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
