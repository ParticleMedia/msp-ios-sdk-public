#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Jenkins Slack Integration Example
# This script shows how to integrate Slack notifications into Jenkins pipelines

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/release-common.sh"

# Jenkins-specific configuration
export SLACK_CHANNEL="${SLACK_CHANNEL:-#jenkins-releases}"
export SLACK_USERNAME="${SLACK_USERNAME:-Jenkins MSP iOS SDK Bot}"

# Function to run CocoaPods release with Jenkins integration
jenkins_cocoapods_release() {
    local version="$1"
    local release_branch="$2"
    
    log_info "Starting Jenkins CocoaPods release for version $version"
    
    # Set Jenkins environment variables
    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"
    
    # Run the CocoaPods release script
    if ./Scripts/release-cocoapods-modular.sh --release-branch "$release_branch" "$version"; then
        log_success "Jenkins CocoaPods release completed successfully"
        return 0
    else
        log_error "Jenkins CocoaPods release failed"
        return 1
    fi
}

# Function to run SPM release with Jenkins integration
jenkins_spm_release() {
    local version="$1"
    local release_branch="$2"
    
    log_info "Starting Jenkins SPM release for version $version"
    
    # Set Jenkins environment variables
    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-unknown}"
    
    # Run the SPM release script
    if ./Scripts/release-spm-modular.sh --release-branch "$release_branch" "$version"; then
        log_success "Jenkins SPM release completed successfully"
        return 0
    else
        log_error "Jenkins SPM release failed"
        return 1
    fi
}

# Function to test Slack integration in Jenkins
jenkins_test_slack() {
    log_info "Testing Slack integration in Jenkins environment"
    
    # Set Jenkins environment variables
    export JENKINS_URL="${JENKINS_URL:-}"
    export BUILD_NUMBER="${BUILD_NUMBER:-test-$(date +%s)}"
    
    # Test the notification
    test_slack_notification
}

# Main function
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
        *)
            echo "Usage: $0 {cocoapods|spm|test-slack} [args...]"
            echo ""
            echo "Commands:"
            echo "  cocoapods <version> <release_branch>  - Run CocoaPods release"
            echo "  spm <version> <release_branch>        - Run SPM release"
            echo "  test-slack                            - Test Slack integration"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
