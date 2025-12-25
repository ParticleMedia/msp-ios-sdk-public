#!/usr/bin/env bash
# Test Slack DM notification system
# Usage: ./Scripts/tests/test-slack-dm.sh

set -euo pipefail

# ============================================================================
# Setup
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================
print_header() {
    echo
    echo "======================================"
    echo "$1"
    echo "======================================"
    echo
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# ============================================================================
# Main Test
# ============================================================================
print_header "Slack DM Notification Test"

# Source dependencies
print_step "Loading Slack notification modules..."

if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/logger.sh"
    print_success "logger.sh loaded"
else
    print_warning "logger.sh not found, using fallback logging"
fi

if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    source "$ROOT_DIR/Scripts/notify/slack.sh"
    print_success "slack.sh loaded"
else
    print_error "slack.sh not found"
    exit 1
fi

if [[ -f "$ROOT_DIR/Scripts/release/utils/notify.sh" ]]; then
    source "$ROOT_DIR/Scripts/release/utils/notify.sh"
    print_success "notify.sh loaded"
else
    print_error "notify.sh not found"
    exit 1
fi

# Enable debug logging
export MSP_LOG_LEVEL=0

# Check environment
print_header "Environment Check"

echo "Configuration Status:"
if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
    print_success "SLACK_BOT_TOKEN: SET (${SLACK_BOT_TOKEN:0:20}...)"
else
    print_error "SLACK_BOT_TOKEN: NOT SET"
    echo
    echo "Please configure SLACK_BOT_TOKEN in Scripts/config/slack.conf"
    echo "Example: SLACK_BOT_TOKEN=xoxb-your-token-here"
    exit 1
fi

if [[ -n "${MSP_SLACK_DM_OVERRIDE:-}" ]]; then
    print_success "MSP_SLACK_DM_OVERRIDE: ${MSP_SLACK_DM_OVERRIDE}"
else
    print_warning "MSP_SLACK_DM_OVERRIDE: NOT SET"
    print_warning "DM will be sent to resolved user (may not work in test)"
fi

echo "  MSP_SLACK_ALERT_ENV: ${MSP_SLACK_ALERT_ENV:-prod (default)}"

# Test 1: Basic function availability
print_header "Test 1: Function Availability"

functions=(
    "notify::_send_dm"
    "notify::dm"
    "notify::module_error"
    "notify::load_mapping"
)

all_available=true
for func in "${functions[@]}"; do
    if command -v "$func" &>/dev/null; then
        print_success "$func is available"
    else
        print_error "$func is NOT available"
        all_available=false
    fi
done

if [[ "$all_available" != "true" ]]; then
    print_error "Some functions are missing. Cannot proceed with tests."
    exit 1
fi

# Test 2: Send test DM
print_header "Test 2: Send Test DM"

print_step "Sending test error notification..."
echo

if notify::module_error "TestModule" "1.0.0-test" "This is a test error notification from Slack DM test script"; then
    print_success "notify::module_error completed successfully"
else
    print_error "notify::module_error returned failure status"
    echo
    echo "Check the logs above for details on what went wrong."
    exit 1
fi

# Test 3: Direct DM send
print_header "Test 3: Direct DM Send"

test_message="🧪 Direct DM Test

This is a direct test of the Slack DM system.
Timestamp: $(date)
Test ID: test-slack-dm-$$"

if [[ -n "${MSP_SLACK_DM_OVERRIDE:-}" ]]; then
    print_step "Sending direct DM to override user: ${MSP_SLACK_DM_OVERRIDE}..."
    echo

    if notify::dm "${MSP_SLACK_DM_OVERRIDE}" "$test_message"; then
        print_success "Direct DM sent successfully"
    else
        print_error "Direct DM send failed"
        exit 1
    fi
else
    print_warning "MSP_SLACK_DM_OVERRIDE not set, skipping direct DM test"
fi

# Summary
print_header "Test Summary"

print_success "All tests completed successfully!"
echo
echo "✓ Slack notification modules loaded"
echo "✓ Environment configured correctly"
echo "✓ Functions are available"
echo "✓ Test notifications sent"
echo
echo "Please check your Slack DMs to confirm message delivery."
echo

