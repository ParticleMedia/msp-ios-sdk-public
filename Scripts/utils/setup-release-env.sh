#!/usr/bin/env bash
# ============================================================================
# MSP Release Environment Setup
# ============================================================================
# Purpose: Simplify environment variable configuration for MSP iOS SDK release
#
# Usage:
#   source Scripts/utils/setup-release-env.sh [profile]
#
# Profiles:
#   local      - Local release (default)
#   ci         - CI release
#   rerelease  - Republish existing version
#   resume     - Resume failed release
#   test       - Test mode (preflight tier)
#
# Examples:
#   source Scripts/utils/setup-release-env.sh          # local release
#   source Scripts/utils/setup-release-env.sh local    # local release
#   source Scripts/utils/setup-release-env.sh ci       # CI release
#   source Scripts/utils/setup-release-env.sh rerelease # rerelease
#   source Scripts/utils/setup-release-env.sh resume   # resume
# ============================================================================

# Prevent direct execution (must be sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: This script must be sourced, not executed"
    echo "   Usage: source ${0} [profile]"
    exit 1
fi

# Get profile from argument (default: local)
_MSP_PROFILE="${1:-local}"

# ============================================================================
# Profile: Local Release (default)
# ============================================================================
setup_local_profile() {
    echo "🔧 Setting up environment for: Local Release"

    # Core variables (3 required)
    export MSP_RELEASE_TIER=release
    export MSP_ALLOW_LOCAL_RELEASE=1
    export MSP_ALLOW_TRUNK_PUSH=1

    # Slack: use test mode by default for local development
    # - test: Sends to MSP_SLACK_TEST_WEBHOOK (safe for testing)
    # - prod: Sends to SLACK_WEBHOOK_URL (production channel)
    export MSP_SLACK_ALERT_ENV=test

    echo "✅ Local release environment configured"
    echo "   MSP_RELEASE_TIER: $MSP_RELEASE_TIER"
    echo "   MSP_ALLOW_LOCAL_RELEASE: $MSP_ALLOW_LOCAL_RELEASE"
    echo "   MSP_ALLOW_TRUNK_PUSH: $MSP_ALLOW_TRUNK_PUSH"
    echo "   MSP_SLACK_ALERT_ENV: $MSP_SLACK_ALERT_ENV (test webhook)"
    echo ""
    echo "ℹ️  Slack webhooks:"
    echo "   - Test:  MSP_SLACK_TEST_WEBHOOK (from Scripts/config/slack.conf)"
    echo "   - Prod:  SLACK_WEBHOOK_URL (from Scripts/config/slack.conf)"
    echo ""
    echo "💡 To use production Slack channel:"
    echo "   export MSP_SLACK_ALERT_ENV=prod"
}

# ============================================================================
# Profile: CI Release
# ============================================================================
setup_ci_profile() {
    echo "🔧 Setting up environment for: CI Release"

    # Core variables (2 required for CI)
    export MSP_RELEASE_TIER=release
    export MSP_ALLOW_TRUNK_PUSH=1

    # Slack: use prod mode (optional)
    export MSP_SLACK_ALERT_ENV=prod

    # Note: CI and GITHUB_ACTIONS are automatically set by CI environment
    # Note: MSP_ALLOW_LOCAL_RELEASE is not needed in CI

    echo "✅ CI release environment configured"
    echo "   MSP_RELEASE_TIER: $MSP_RELEASE_TIER"
    echo "   MSP_ALLOW_TRUNK_PUSH: $MSP_ALLOW_TRUNK_PUSH"
    echo "   MSP_SLACK_ALERT_ENV: $MSP_SLACK_ALERT_ENV"
    echo ""
    echo "ℹ️  SLACK_WEBHOOK_URL should be set via GitHub Secrets"
}

# ============================================================================
# Profile: Rerelease (republish existing version)
# ============================================================================
setup_rerelease_profile() {
    echo "🔧 Setting up environment for: Rerelease"

    # Start with local profile
    setup_local_profile

    # Add rerelease permission
    export MSP_ALLOW_EXISTING_TAG=1

    echo "⚠️  Rerelease mode enabled"
    echo "   MSP_ALLOW_EXISTING_TAG: $MSP_ALLOW_EXISTING_TAG"
}

# ============================================================================
# Profile: Test (preflight tier)
# ============================================================================
setup_test_profile() {
    echo "🔧 Setting up environment for: Test (Preflight)"

    # Use preflight tier (no trunk push)
    export MSP_RELEASE_TIER=preflight
    export MSP_ALLOW_LOCAL_RELEASE=1
    export MSP_ALLOW_TRUNK_PUSH=0

    # Slack: test mode
    export MSP_SLACK_ALERT_ENV=test

    echo "✅ Test environment configured"
    echo "   MSP_RELEASE_TIER: $MSP_RELEASE_TIER"
    echo "   MSP_ALLOW_LOCAL_RELEASE: $MSP_ALLOW_LOCAL_RELEASE"
    echo "   MSP_ALLOW_TRUNK_PUSH: $MSP_ALLOW_TRUNK_PUSH (no actual push)"
    echo "   MSP_SLACK_ALERT_ENV: $MSP_SLACK_ALERT_ENV"
}

# ============================================================================
# Profile: Resume (resume failed release)
# ============================================================================
setup_resume_profile() {
    echo "🔧 Setting up environment for: Resume"

    # Start with local profile
    setup_local_profile

    # Add resume-specific permissions
    export MSP_ALLOW_EXISTING_TAG=1

    echo "⚠️  Resume mode configured"
    echo "   MSP_ALLOW_EXISTING_TAG: $MSP_ALLOW_EXISTING_TAG (allow existing tags)"
    echo ""
    echo "💡 This profile is used to resume a failed release."
    echo "   Use: ./Scripts/resume-smart.sh (recommended)"
    echo "   Or:  ./Scripts/msp-release.sh resume"
}

# ============================================================================
# Main
# ============================================================================

case "$_MSP_PROFILE" in
    local)
        setup_local_profile
        ;;
    ci)
        setup_ci_profile
        ;;
    rerelease)
        setup_rerelease_profile
        ;;
    resume)
        setup_resume_profile
        ;;
    test)
        setup_test_profile
        ;;
    *)
        echo "❌ Unknown profile: $_MSP_PROFILE"
        echo ""
        echo "Available profiles:"
        echo "  local      - Local release (default)"
        echo "  ci         - CI release"
        echo "  rerelease  - Republish existing version"
        echo "  resume     - Resume failed release"
        echo "  test       - Test mode (preflight tier)"
        echo ""
        echo "Usage: source ${BASH_SOURCE[0]} [profile]"
        return 1
        ;;
esac

# Clean up
unset _MSP_PROFILE

