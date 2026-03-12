#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

# Release Notes Test Script
# Tests the release notes generation functionality

set -euo pipefail

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib/release-common.sh"

# Source shared libraries
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

# Test configuration
TEST_VERSION="1.0.0-test"
TEST_RELEASE_TYPE="CocoaPods"

# Test logging functions (use UI system)
test_log() {
    log::step "CI" "🧪 $1"
}

test_success() {
    log::success "CI" "$1"
}

test_failure() {
    log::error "CI" "$1"
}

# Test 1: Generate release notes from git
test_git_release_notes() {
    test_log "Test 1: Generating release notes from git commits"
    
    local notes=$(generate_release_notes_from_git "$TEST_VERSION" "" "$TEST_RELEASE_TYPE")
    
    if [[ -n "$notes" ]]; then
        test_success "Git release notes generated successfully"
        echo "Generated notes:"
        echo "───────────────────────────────────────────────────────────────────"
        echo -e "$notes"
        echo "───────────────────────────────────────────────────────────────────"
        return 0
    else
        test_failure "Failed to generate git release notes"
        return 1
    fi
}

# Test 2: Generate release notes from template
test_template_release_notes() {
    test_log "Test 2: Generating release notes from template"
    
    local notes=$(generate_release_notes_from_template "$TEST_VERSION" "$TEST_RELEASE_TYPE")
    
    if [[ -n "$notes" ]]; then
        test_success "Template release notes generated successfully"
        echo "Generated notes:"
        echo "───────────────────────────────────────────────────────────────────"
        echo -e "$notes"
        echo "───────────────────────────────────────────────────────────────────"
        return 0
    else
        test_failure "Failed to generate template release notes"
        return 1
    fi
}

# Test 3: Generate release notes from custom template
test_custom_template_release_notes() {
    test_log "Test 3: Generating release notes from custom template"
    
    local template_file="Scripts/templates/release-notes-template.md"
    local notes=$(generate_release_notes_from_template "$TEST_VERSION" "$TEST_RELEASE_TYPE" "$template_file")
    
    if [[ -n "$notes" ]]; then
        test_success "Custom template release notes generated successfully"
        echo "Generated notes:"
        echo "───────────────────────────────────────────────────────────────────"
        echo -e "$notes"
        echo "───────────────────────────────────────────────────────────────────"
        return 0
    else
        test_failure "Failed to generate custom template release notes"
        return 1
    fi
}

# Test 4: Test get_release_notes function
test_get_release_notes() {
    test_log "Test 4: Testing get_release_notes function with different sources"
    
    # Test auto mode
    local auto_notes=$(get_release_notes "$TEST_VERSION" "$TEST_RELEASE_TYPE" "auto")
    if [[ -n "$auto_notes" ]]; then
        test_success "Auto mode release notes generated"
    else
        test_failure "Auto mode release notes failed"
    fi
    
    # Test git mode
    local git_notes=$(get_release_notes "$TEST_VERSION" "$TEST_RELEASE_TYPE" "git")
    if [[ -n "$git_notes" ]]; then
        test_success "Git mode release notes generated"
    else
        test_failure "Git mode release notes failed"
    fi
    
    # Test template mode
    local template_notes=$(get_release_notes "$TEST_VERSION" "$TEST_RELEASE_TYPE" "template")
    if [[ -n "$template_notes" ]]; then
        test_success "Template mode release notes generated"
    else
        test_failure "Template mode release notes failed"
    fi
}

# Test 5: Test Slack notification with release notes
test_slack_with_release_notes() {
    test_log "Test 5: Testing Slack notification with release notes"
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        test_log "Skipping Slack test - SLACK_WEBHOOK_URL not set"
        return 0
    fi
    
    local release_notes="## Test Release 1.0.0\n\n- Bug fixes and improvements\n- Performance optimizations\n- Enhanced stability"
    
    if notify_release_start "Test Release" "$TEST_VERSION" "MSPCore, NovaCore" "$release_notes"; then
        test_success "Slack notification with release notes sent successfully"
        return 0
    else
        test_failure "Slack notification with release notes failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🧪 Release Notes Test Suite"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    local total_tests=5
    
    # Run tests
    if test_git_release_notes; then
        ((tests_passed++)) || true
    else
        ((tests_failed++)) || true
    fi
    
    echo ""
    if test_template_release_notes; then
        ((tests_passed++)) || true
    else
        ((tests_failed++)) || true
    fi
    
    echo ""
    if test_custom_template_release_notes; then
        ((tests_passed++)) || true
    else
        ((tests_failed++)) || true
    fi
    
    echo ""
    if test_get_release_notes; then
        ((tests_passed++)) || true
    else
        ((tests_failed++)) || true
    fi
    
    echo ""
    if test_slack_with_release_notes; then
        ((tests_passed++)) || true
    else
        ((tests_failed++)) || true
    fi
    
    # Print results
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📊 Test Results Summary"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Total Tests: $total_tests"
    echo "Passed: $tests_passed"
    echo "Failed: $tests_failed"
    echo ""
    
    if [[ $tests_failed -eq 0 ]]; then
        test_success "All tests passed! 🎉"
        echo ""
        echo "Release notes functionality is working correctly."
        return 0
    else
        test_failure "Some tests failed. Please check the output above."
        return 1
    fi
}

# Show help
show_help() {
    echo "Release Notes Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --version, -v       Show version information"
    echo ""
    echo "This script tests the release notes generation functionality including:"
    echo "  - Git-based release notes generation"
    echo "  - Template-based release notes generation"
    echo "  - Custom template support"
    echo "  - Slack integration with release notes"
    echo ""
    echo "Environment Variables:"
    echo "  SLACK_WEBHOOK_URL   Slack webhook URL (optional, for Slack tests)"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Release Notes Test Script v1.0.0"
                exit 0
                ;;
            *)
                echo "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_arguments "$@"
    run_all_tests
}

# Run main function with all arguments
main "$@"
