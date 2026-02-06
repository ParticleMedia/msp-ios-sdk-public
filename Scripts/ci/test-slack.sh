#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Slack Integration Test Script
# Tests the Slack notification system across different environments

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
TEST_PODS="MSPCore, NovaCore, FacebookAdapter"

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test logging functions (use UI system)
test_log() {
    log_step "🧪 $1"
}

test_success() {
    log_success "$1"
    ((TESTS_PASSED++)) || true
}

test_failure() {
    log_error "$1"
    ((TESTS_FAILED++)) || true
}

test_warning() {
    log_warn "$1"
}

# Test 1: Check if webhook URL is set
test_webhook_url() {
    test_log "Test 1: Checking if SLACK_WEBHOOK_URL is set"
    ((TOTAL_TESTS++)) || true
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        test_success "SLACK_WEBHOOK_URL is set"
        return 0
    else
        test_failure "SLACK_WEBHOOK_URL is not set"
        test_warning "Set SLACK_WEBHOOK_URL environment variable to test notifications"
        return 1
    fi
}

# Test 2: Test basic notification
test_basic_notification() {
    test_log "Test 2: Testing basic Slack notification"
    ((TOTAL_TESTS++)) || true
    
    if test_slack_notification; then
        test_success "Basic notification sent successfully"
        return 0
    else
        test_failure "Basic notification failed"
        return 1
    fi
}

# Test 3: Test environment detection
test_environment_detection() {
    test_log "Test 3: Testing environment detection"
    ((TOTAL_TESTS++)) || true
    
    local env=$(get_environment)
    local env_info=$(get_environment_info)
    
    if [[ -n "$env" && -n "$env_info" ]]; then
        test_success "Environment detection working: $env - $env_info"
        return 0
    else
        test_failure "Environment detection failed"
        return 1
    fi
}

# Test 4: Test release start notification
test_release_start() {
    test_log "Test 4: Testing release start notification"
    ((TOTAL_TESTS++)) || true
    
    if notify_release_start "Test Release" "$TEST_VERSION" "$TEST_PODS"; then
        test_success "Release start notification sent"
        return 0
    else
        test_failure "Release start notification failed"
        return 1
    fi
}

# Test 5: Test pod release notifications
test_pod_release_notifications() {
    test_log "Test 5: Testing pod release notifications"
    ((TOTAL_TESTS++)) || true
    
    local success_count=0
    local total_pods=3
    local pods=("MSPCore" "NovaCore" "FacebookAdapter")
    
    # Test success notification
    if notify_pod_release "MSPCore" "$TEST_VERSION" "success" "Test success message"; then
        ((success_count++))
    fi
    
    # Test failure notification
    if notify_pod_release "NovaCore" "$TEST_VERSION" "failure" "Test failure message"; then
        ((success_count++))
    fi
    
    # Test warning notification
    if notify_pod_release "FacebookAdapter" "$TEST_VERSION" "warning" "Test warning message"; then
        ((success_count++))
    fi
    
    if [[ $success_count -eq $total_pods ]]; then
        test_success "All pod release notifications sent ($success_count/$total_pods)"
        return 0
    else
        test_failure "Some pod release notifications failed ($success_count/$total_pods)"
        return 1
    fi
}

# Test 6: Test release success notification
test_release_success() {
    test_log "Test 6: Testing release success notification"
    ((TOTAL_TESTS++)) || true
    
    if notify_release_success "Test Release" "$TEST_VERSION" "$TEST_PODS" "5 minutes"; then
        test_success "Release success notification sent"
        return 0
    else
        test_failure "Release success notification failed"
        return 1
    fi
}

# Test 7: Test release failure notification
test_release_failure() {
    test_log "Test 7: Testing release failure notification"
    ((TOTAL_TESTS++)) || true
    
    if notify_release_failure "Test Release" "$TEST_VERSION" "Test error message" "Test step"; then
        test_success "Release failure notification sent"
        return 0
    else
        test_failure "Release failure notification failed"
        return 1
    fi
}

# Test 8: Test release warning notification
test_release_warning() {
    test_log "Test 8: Testing release warning notification"
    ((TOTAL_TESTS++)) || true
    
    if notify_release_warning "Test Release" "$TEST_VERSION" "Test warning message" "Test step"; then
        test_success "Release warning notification sent"
        return 0
    else
        test_failure "Release warning notification failed"
        return 1
    fi
}

# Test 9: Test release summary notification
test_release_summary() {
    test_log "Test 9: Testing release summary notification"
    ((TOTAL_TESTS++)) || true
    
    if notify_release_summary "Test Release" "$TEST_VERSION" "3" "2" "1" "10 minutes"; then
        test_success "Release summary notification sent"
        return 0
    else
        test_failure "Release summary notification failed"
        return 1
    fi
}

# Test 10: Test webhook connectivity
test_webhook_connectivity() {
    test_log "Test 10: Testing webhook connectivity"
    ((TOTAL_TESTS++)) || true
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        test_failure "SLACK_WEBHOOK_URL not set, skipping connectivity test"
        return 1
    fi
    
    local response=$(curl -s -X POST -H 'Content-type: application/json' \
        --data '{"text":"Connectivity test from MSP iOS SDK"}' \
        "$SLACK_WEBHOOK_URL" 2>/dev/null)
    
    if [[ "$response" == "ok" ]]; then
        test_success "Webhook connectivity test passed"
        return 0
    else
        test_failure "Webhook connectivity test failed: $response"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🧪 MSP iOS SDK Slack Integration Test Suite"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Check prerequisites
    if ! test_webhook_url; then
        echo ""
        test_warning "Some tests will be skipped due to missing SLACK_WEBHOOK_URL"
        echo ""
    fi
    
    # Run tests
    test_environment_detection
    test_webhook_connectivity
    test_basic_notification
    test_release_start
    test_pod_release_notifications
    test_release_success
    test_release_failure
    test_release_warning
    test_release_summary
    
    # Print results
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📊 Test Results Summary"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        test_success "All tests passed! 🎉"
        echo ""
        echo "Your Slack integration is working correctly."
        echo "You can now use the release scripts with notifications."
        return 0
    else
        test_failure "Some tests failed. Please check the output above."
        echo ""
        echo "Common issues:"
        echo "1. SLACK_WEBHOOK_URL not set or invalid"
        echo "2. Webhook URL doesn't have permission to post to the channel"
        echo "3. Network connectivity issues"
        echo "4. Invalid JSON payload format"
        return 1
    fi
}

# Show help
show_help() {
    echo "MSP iOS SDK Slack Integration Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --version, -v       Show version information"
    echo "  --webhook-url URL   Set webhook URL for testing"
    echo "  --channel CHANNEL   Set channel for testing"
    echo ""
    echo "Environment Variables:"
    echo "  SLACK_WEBHOOK_URL   Slack webhook URL (required)"
    echo "  SLACK_CHANNEL       Slack channel (optional, defaults to #releases)"
    echo "  SLACK_USERNAME      Bot username (optional)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --webhook-url https://hooks.slack.com/services/..."
    echo "  $0 --webhook-url https://hooks.slack.com/services/... --channel #test"
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
                echo "Slack Integration Test Script v1.0.0"
                exit 0
                ;;
            --webhook-url)
                export SLACK_WEBHOOK_URL="$2"
                shift 2
                ;;
            --channel)
                export SLACK_CHANNEL="$2"
                shift 2
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
