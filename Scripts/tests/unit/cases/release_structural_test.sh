#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Release Script Structural Integrity
# ============================================================================
# Verifies fixes for 3.1.8 release bugs:
#   Bug 1: Tag created before version propagation
#   Bug 2: spm_publish_tags defined after main "$@"
#   Bug 3: push_release_branch hangs + PR never created
# Also verifies Slack notification credential validity.

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

MODULAR="$ROOT_DIR/Scripts/release/orchestrator/modular.sh"
SPM_PUBLISH="$ROOT_DIR/Scripts/release/publish/spm/publish.sh"
SLACK_CONF="$ROOT_DIR/Scripts/config/slack.conf"
NOTIFY_CORE="$ROOT_DIR/Scripts/notify/notify_core.sh"

# ============================================================================
# Bug 1: Version propagation must happen before pods/publish.sh
# ============================================================================

test_version_propagation_before_publish() {
    # version propagation (update_novacore_config_plist_version) must appear
    # BEFORE the cocoapods publish call (bash "$COCOAPODS_SCRIPT")
    local prop_line pub_line
    prop_line=$(grep -n 'update_novacore_config_plist_version' "$MODULAR" | head -1 | cut -d: -f1)
    pub_line=$(grep -n 'bash "\$COCOAPODS_SCRIPT"' "$MODULAR" | head -1 | cut -d: -f1)

    if [[ -n "$prop_line" && -n "$pub_line" ]] && [[ "$prop_line" -lt "$pub_line" ]]; then
        pass "Bug1: NovaCore Config.plist propagation before pods/publish.sh (L${prop_line} < L${pub_line})"
    else
        fail "Bug1: update_novacore_config_plist_version (L${prop_line:-?}) should be before COCOAPODS_SCRIPT (L${pub_line:-?})"
    fi
}

test_mspcore_propagation_before_publish() {
    local prop_line pub_line
    prop_line=$(grep -n 'update_config_plist_version' "$MODULAR" | head -1 | cut -d: -f1)
    pub_line=$(grep -n 'bash "\$COCOAPODS_SCRIPT"' "$MODULAR" | head -1 | cut -d: -f1)

    if [[ -n "$prop_line" && -n "$pub_line" ]] && [[ "$prop_line" -lt "$pub_line" ]]; then
        pass "Bug1: MSPCore Config.plist propagation before pods/publish.sh (L${prop_line} < L${pub_line})"
    else
        fail "Bug1: update_config_plist_version (L${prop_line:-?}) should be before COCOAPODS_SCRIPT (L${pub_line:-?})"
    fi
}

test_demoapp_propagation_before_publish() {
    local prop_line pub_line
    prop_line=$(grep -n 'update_demo_app_version' "$MODULAR" | head -1 | cut -d: -f1)
    pub_line=$(grep -n 'bash "\$COCOAPODS_SCRIPT"' "$MODULAR" | head -1 | cut -d: -f1)

    if [[ -n "$prop_line" && -n "$pub_line" ]] && [[ "$prop_line" -lt "$pub_line" ]]; then
        pass "Bug1: DemoApp version propagation before pods/publish.sh (L${prop_line} < L${pub_line})"
    else
        fail "Bug1: update_demo_app_version (L${prop_line:-?}) should be before COCOAPODS_SCRIPT (L${pub_line:-?})"
    fi
}

test_propagation_commits_after_each_update() {
    # Each propagation should be followed by a git commit
    local count
    count=$(grep -c 'chore(release): update.*to \${VERSION}' "$MODULAR" || echo 0)
    if [[ "$count" -ge 3 ]]; then
        pass "Bug1: All 3 version propagation steps have git commits ($count found)"
    else
        fail "Bug1: Expected 3 version propagation commits, found $count"
    fi
}

# ============================================================================
# Bug 2: spm_publish_tags must be defined before main "$@"
# ============================================================================

test_spm_publish_tags_before_main() {
    local func_line main_line
    func_line=$(grep -n '^spm_publish_tags()' "$SPM_PUBLISH" | head -1 | cut -d: -f1)
    main_line=$(grep -n '^main "\$@"' "$SPM_PUBLISH" | head -1 | cut -d: -f1)

    if [[ -n "$func_line" && -n "$main_line" ]] && [[ "$func_line" -lt "$main_line" ]]; then
        pass "Bug2: spm_publish_tags() defined before main \"\$@\" (L${func_line} < L${main_line})"
    else
        fail "Bug2: spm_publish_tags() (L${func_line:-?}) should be before main \"\$@\" (L${main_line:-?})"
    fi
}

test_spm_publish_tags_is_complete_function() {
    # Verify the function has the expected content (not a stub)
    if grep -q 'git tag -a "\$tag_name"' "$SPM_PUBLISH" &&
       grep -q 'git push origin --tags' "$SPM_PUBLISH"; then
        pass "Bug2: spm_publish_tags() contains tag creation and push logic"
    else
        fail "Bug2: spm_publish_tags() should contain git tag and git push logic"
    fi
}

# ============================================================================
# Bug 3: push_release_branch timeout + retry + soft-fail
# ============================================================================

test_push_has_timeout() {
    if grep -q 'timeout 120 git push origin "\$RELEASE_BRANCH"' "$MODULAR"; then
        pass "Bug3: push_release_branch uses timeout 120"
    else
        fail "Bug3: push_release_branch should use timeout 120 for git push"
    fi
}

test_push_has_retry() {
    if grep -q 'max_push_attempts=3' "$MODULAR" &&
       grep -q 'push_attempt' "$MODULAR" &&
       grep -q 'push_success' "$MODULAR"; then
        pass "Bug3: push_release_branch has 3-attempt retry loop"
    else
        fail "Bug3: push_release_branch should have retry loop with max_push_attempts=3"
    fi
}

test_push_has_sleep_interval() {
    # Verify sleep between retries in push_release_branch context
    local push_block
    push_block=$(awk '/push_release_branch\(\)/,/^}/' "$MODULAR")

    if echo "$push_block" | grep -q 'sleep 3'; then
        pass "Bug3: push_release_branch retry has 3s sleep interval"
    else
        fail "Bug3: push_release_branch retry should have sleep 3"
    fi
}

test_push_failure_is_soft_fail() {
    # The step 4 block should NOT have 'return 14'
    local step4_block
    step4_block=$(awk '/Step 4: Push release branch/,/step_done|step_fail/' "$MODULAR")

    if echo "$step4_block" | grep -q 'return 14'; then
        fail "Bug3: push_release_branch failure should not return 14 (hard-fail)"
    else
        pass "Bug3: push_release_branch failure is soft-fail (no return 14)"
    fi
}

test_push_failure_continues_to_pr() {
    # After push failure, should continue (log warning, not return)
    if grep -q 'Push failed but continuing to PR creation' "$MODULAR"; then
        pass "Bug3: push failure logs continuation to PR creation"
    else
        fail "Bug3: push failure should log continuation message"
    fi
}

# ============================================================================
# Slack: Credential validity
# ============================================================================

test_slack_not_in_test_mode() {
    if [[ ! -f "$SLACK_CONF" ]]; then
        pass "Slack: slack.conf not found (gitignored, skipping)"
        return
    fi

    local env_value
    env_value=$(grep '^MSP_SLACK_ALERT_ENV=' "$SLACK_CONF" | cut -d= -f2 || echo "")

    if [[ "$env_value" == "prod" ]]; then
        pass "Slack: MSP_SLACK_ALERT_ENV is prod"
    elif [[ "$env_value" == "test" ]]; then
        fail "Slack: MSP_SLACK_ALERT_ENV is still 'test' — notifications go to test channel"
    else
        pass "Slack: MSP_SLACK_ALERT_ENV is '${env_value:-unset}' (defaults to prod)"
    fi
}

test_slack_no_dm_override_in_prod() {
    if [[ ! -f "$SLACK_CONF" ]]; then
        pass "Slack: slack.conf not found (gitignored, skipping)"
        return
    fi

    if grep -q '^MSP_SLACK_DM_OVERRIDE=' "$SLACK_CONF"; then
        fail "Slack: MSP_SLACK_DM_OVERRIDE is active — all DMs go to single user"
    else
        pass "Slack: No MSP_SLACK_DM_OVERRIDE (DMs route via email_map)"
    fi
}

test_slack_webhook_reachable() {
    if [[ ! -f "$SLACK_CONF" ]]; then
        pass "Slack: slack.conf not found (gitignored, skipping)"
        return
    fi

    local webhook
    webhook=$(grep '^SLACK_WEBHOOK_URL=' "$SLACK_CONF" | cut -d= -f2 || echo "")

    if [[ -z "$webhook" ]]; then
        fail "Slack: SLACK_WEBHOOK_URL not set in slack.conf"
        return
    fi

    # Quick connectivity check (POST with empty body gets a non-404 response if valid)
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-type: application/json" \
        --data '{"text":""}' \
        "$webhook" 2>/dev/null || echo "000")

    if [[ "$http_code" == "404" ]]; then
        fail "Slack: SLACK_WEBHOOK_URL returns 404 (webhook deleted or disabled)"
    elif [[ "$http_code" == "000" ]]; then
        fail "Slack: SLACK_WEBHOOK_URL unreachable (network error)"
    else
        pass "Slack: SLACK_WEBHOOK_URL reachable (HTTP $http_code)"
    fi
}

test_slack_bot_token_valid() {
    if [[ ! -f "$SLACK_CONF" ]]; then
        pass "Slack: slack.conf not found (gitignored, skipping)"
        return
    fi

    local token
    token=$(grep '^SLACK_BOT_TOKEN=' "$SLACK_CONF" | cut -d= -f2 || echo "")

    if [[ -z "$token" ]]; then
        fail "Slack: SLACK_BOT_TOKEN not set in slack.conf"
        return
    fi

    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-type: application/json" \
        https://slack.com/api/auth.test 2>/dev/null || echo '{"ok":false}')

    if echo "$response" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('ok') else 1)" 2>/dev/null; then
        pass "Slack: SLACK_BOT_TOKEN is valid"
    else
        local error
        error=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null || echo "unknown")
        fail "Slack: SLACK_BOT_TOKEN is invalid ($error)"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running release structural integrity tests..."
echo "========================================"

echo ""
echo "--- Bug 1: Version propagation before tagging ---"
test_version_propagation_before_publish
test_mspcore_propagation_before_publish
test_demoapp_propagation_before_publish
test_propagation_commits_after_each_update

echo ""
echo "--- Bug 2: spm_publish_tags function ordering ---"
test_spm_publish_tags_before_main
test_spm_publish_tags_is_complete_function

echo ""
echo "--- Bug 3: push_release_branch reliability ---"
test_push_has_timeout
test_push_has_retry
test_push_has_sleep_interval
test_push_failure_is_soft_fail
test_push_failure_continues_to_pr

echo ""
echo "--- Slack credential validation ---"
test_slack_not_in_test_mode
test_slack_no_dm_override_in_prod
test_slack_webhook_reachable
test_slack_bot_token_valid

echo ""
echo "========================================"
echo "Release structural tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
