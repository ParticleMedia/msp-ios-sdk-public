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

# Jenkins Slack Integration Example
# This script shows how to integrate Slack notifications into Jenkins pipelines

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/Scripts/lib/release-common.sh"

# Jenkins-specific configuration
export SLACK_CHANNEL="${SLACK_CHANNEL:-#jenkins-releases}"
export SLACK_USERNAME="${SLACK_USERNAME:-Jenkins MSP iOS SDK Bot}"

jenkins_cocoapods_release() {
    local version="$1"
    local release_branch="$2"
    
    log::info "CI" "Starting Jenkins CocoaPods release for version $version"
    
    # Set Jenkins environment variables
    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"
    
    # Run the CocoaPods release script
    if ./Scripts/release-cocoapods-modular.sh --release-branch "$release_branch" "$version"; then
        log::success "CI" "Jenkins CocoaPods release completed successfully"
        return 0
    else
        log::error "CI" "Jenkins CocoaPods release failed"
        return 1
    fi
}

jenkins_spm_release() {
    local version="$1"
    local release_branch="$2"
    
    log::info "CI" "Starting Jenkins SPM release for version $version"
    
    # Set Jenkins environment variables
    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"
    
    # Run the SPM release script
    if ./Scripts/release-spm-modular.sh --release-branch "$release_branch" "$version"; then
        log::success "CI" "Jenkins SPM release completed successfully"
        return 0
    else
        log::error "CI" "Jenkins SPM release failed"
        return 1
    fi
}

jenkins_test_slack() {
    log::info "CI" "Testing Slack integration in Jenkins environment"
    
    # Set Jenkins environment variables
    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-test-$(date +%s)}"
    
    # Test the notification
    test_slack_notification
}

jenkins_testflight_success() {
    local branch="${1:-unknown}"
    local triggered_by="${2:-unknown}"
    local duration="${3:-unknown}"
    local build_number
    local sdk_version

    build_number="$(grep 'build_number:' "$REPO_ROOT/Scripts/testflight/config.yaml" | awk '{print $2}')"
    sdk_version="$(grep 'SDK_VERSION=' "$REPO_ROOT/Scripts/config/sdk_version.conf" | sed 's/.*="//;s/"//')"

    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"

    log::info "CI" "Sending Jenkins TestFlight success notification for build ${build_number}"
    notify_testflight_success "$build_number" "$sdk_version" "$branch" "$triggered_by" "$duration"
}

main() {
    local command="$1"
    shift
    
    case "$command" in
        "cocoapods")
            jenkins_cocoapods_release "$@"
            ;;
        "spm")
            jenkins_spm_release "$@"
            ;;
        "test-slack")
            jenkins_test_slack
            ;;
        "testflight-success")
            jenkins_testflight_success "$@"
            ;;
        *)
            echo "Usage: $0 {cocoapods|spm|test-slack|testflight-success} [args...]"
            echo ""
            echo "Commands:"
            echo "  cocoapods <version> <release_branch>  - Run CocoaPods release"
            echo "  spm <version> <release_branch>        - Run SPM release"
            echo "  test-slack                            - Test Slack integration"
            echo "  testflight-success <branch> <email> <duration>"
            exit 1
            ;;
    esac
}

main "$@"
