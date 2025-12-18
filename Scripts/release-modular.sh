#!/bin/bash

# Modular Release Orchestrator
# Orchestrates the complete release process: create branch → CocoaPods → SPM → push

set -e

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/release-common.sh"

# Default values
VERSION=""
BASE_BRANCH=""  # Will be set to current branch dynamically
RELEASE_BRANCH=""
DRY_RUN="false"
SKIP_COCOAPODS="false"
SKIP_SPM="false"
SKIP_PUSH="false"
SKIP_CODE_SIGN="false"
VERBOSE="false"
RELEASE_NOTES=""

# Release tracking variables
RELEASE_START_TIME=""
RELEASE_END_TIME=""
COCOAPODS_SUCCESS=()
COCOAPODS_FAILED=()
SPM_SUCCESS=()
SPM_FAILED=()
GITHUB_RELEASES_SUCCESS=()
GITHUB_RELEASES_FAILED=()
OVERALL_SUCCESS="true"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular Release Orchestrator v1.0.0"
                exit 0
                ;;
            --base-branch)
                BASE_BRANCH="$2"
                shift 2
                ;;
            --release-branch)
                RELEASE_BRANCH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-cocoapods)
                SKIP_COCOAPODS="true"
                shift
                ;;
            --skip-spm)
                SKIP_SPM="true"
                shift
                ;;
            --skip-push)
                SKIP_PUSH="true"
                shift
                ;;
            --skip-code-sign)
                SKIP_CODE_SIGN="true"
                shift
                ;;
            --enable-code-sign)
                SKIP_CODE_SIGN="false"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --release-notes)
                RELEASE_NOTES="$2"
                shift 2
                ;;
            *)
                if [[ -z "$VERSION" ]]; then
                    VERSION="$1"
                else
                    log_error "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS] <VERSION>"
    echo ""
    echo "Arguments:"
    echo "  VERSION                 Version to release (e.g., 0.0.2-migration-spm)"
    echo ""
    echo "Options:"
    echo "  --base-branch BRANCH    Base branch to create release from (default: current branch)"
    echo "  --release-branch BRANCH Release branch name (default: release/VERSION)"
    echo "  --dry-run               Show what would be done without executing"
    echo "  --skip-cocoapods        Skip CocoaPods release"
    echo "  --skip-spm              Skip SPM release"
    echo "  --skip-push             Skip pushing release branch"
    echo "  --skip-code-sign        Skip code signing (default: false)"
    echo "  --enable-code-sign      Enable code signing"
    echo "  --verbose               Enable verbose output"
    echo "  --release-notes NOTES   Custom release notes for notifications"
    echo "  --help, -h              Show this help message"
    echo "  --version, -v           Show version information"
    echo ""
    echo "Complete Release Workflow:"
    echo "  1. Create release branch from base branch"
    echo "  2. Release CocoaPods (MSPSharedLibraries → Adapters → MSPCore)"
    echo "  3. Release SPM (NovaCore → NovaAdapter)"
    echo "  4. Push release branch to remote"
    echo ""
    echo "Examples:"
    echo "  $0 0.0.2-migration-spm"
    echo "  $0 --dry-run 0.0.2-migration-spm"
    echo "  $0 --skip-spm 0.0.2-migration-spm"
}

# Validate inputs
validate_inputs() {
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        show_help
        exit 1
    fi
    
    # Set base branch to current branch if not provided
    if [[ -z "$BASE_BRANCH" ]]; then
        BASE_BRANCH="$(git branch --show-current)"
        if [[ -z "$BASE_BRANCH" ]]; then
            log_error "Could not determine current branch. Please specify --base-branch"
            exit 1
        fi
    fi
    
    # Set release branch if not provided
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="release/$VERSION"
    fi
    
    log_info "Release orchestrator configuration:"
    log_info "  Version: $VERSION"
    log_info "  Base Branch: $BASE_BRANCH"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Dry Run: $DRY_RUN"
    log_info "  Skip CocoaPods: $SKIP_COCOAPODS"
    log_info "  Skip SPM: $SKIP_SPM"
    log_info "  Skip Push: $SKIP_PUSH"
}

# Step 0: Pre-release setup (build frameworks)
pre_release_setup() {
    log_release "Step 0: Pre-release setup (building frameworks)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would run build scripts to ensure frameworks are up-to-date"
        return 0
    fi
    
    # Build all frameworks using the unified build script
    log_step "Building all frameworks using unified build script"
    
    local build_args="--frameworks MSPiOSCore,NovaCore"
    if [[ "$SKIP_CODE_SIGN" == "true" ]]; then
        build_args="$build_args --skip-code-sign"
    fi
    
    if ! "$SCRIPT_DIR/build.sh" $build_args; then
        log_error "Failed to build frameworks"
        exit 1
    fi
    
    log_success "Pre-release setup completed successfully"
}

# Step 1: Create release branch
create_release_branch() {
    log_release "Step 1: Creating release branch"
    
    local create_branch_cmd="$SCRIPT_DIR/create-release-branch.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        create_branch_cmd="$create_branch_cmd --dry-run"
    fi
    create_branch_cmd="$create_branch_cmd --base-branch $BASE_BRANCH $VERSION"
    
    log_info "Executing: $create_branch_cmd"
    
    if ! eval "$create_branch_cmd"; then
        log_error "Failed to create release branch"
        exit 1
    fi
    
    log_success "Release branch created successfully"
}

# Step 2: Release CocoaPods
release_cocoapods() {
    if [[ "$SKIP_COCOAPODS" == "true" ]]; then
        log_info "Skipping CocoaPods release (--skip-cocoapods flag)"
        return 0
    fi
    
    log_release "Step 2: Releasing CocoaPods"
    
    # Checkout release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi
    
    local cocoapods_cmd="$SCRIPT_DIR/release-cocoapods-modular.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        cocoapods_cmd="$cocoapods_cmd --dry-run"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        cocoapods_cmd="$cocoapods_cmd --verbose"
    fi
    if [[ -n "$RELEASE_NOTES" ]]; then
        cocoapods_cmd="$cocoapods_cmd --release-notes \"$RELEASE_NOTES\""
    fi
    cocoapods_cmd="$cocoapods_cmd --release-branch $RELEASE_BRANCH $VERSION"
    
    log_info "Executing: $cocoapods_cmd"
    
    if eval "$cocoapods_cmd"; then
        log_success "CocoaPods released successfully"
        # In a real implementation, we would parse the output to track individual pod success/failure
        # For now, we'll assume all pods succeeded if the overall command succeeded
        if [[ "$DRY_RUN" != "true" ]]; then
            COCOAPODS_SUCCESS+=("MSPSharedLibraries" "MSPFacebookAdapter" "MSPGoogleAdapter" "NovaAdapter" "AmazonAdapter" "PrebidAdapter" "MolocoAdapter" "LiftoffAdapter" "MSPCore")
        fi
    else
        log_error "Failed to release CocoaPods"
        OVERALL_SUCCESS="false"
        # In a real implementation, we would parse the output to track which pods failed
        COCOAPODS_FAILED+=("CocoaPods release failed")
    fi
}

# Step 3: Release SPM
release_spm() {
    if [[ "$SKIP_SPM" == "true" ]]; then
        log_info "Skipping SPM release (--skip-spm flag)"
        return 0
    fi
    
    log_release "Step 3: Releasing SPM"
    
    # Ensure we're on release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi
    
    local spm_cmd="$SCRIPT_DIR/release-spm-modular.sh"
    if [[ "$DRY_RUN" == "true" ]]; then
        spm_cmd="$spm_cmd --dry-run"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        spm_cmd="$spm_cmd --verbose"
    fi
    if [[ -n "$RELEASE_NOTES" ]]; then
        spm_cmd="$spm_cmd --release-notes \"$RELEASE_NOTES\""
    fi
    spm_cmd="$spm_cmd --release-branch $RELEASE_BRANCH $VERSION"
    
    log_info "Executing: $spm_cmd"
    
    if eval "$spm_cmd"; then
        log_success "SPM released successfully"
        if [[ "$DRY_RUN" != "true" ]]; then
            SPM_SUCCESS+=("NovaCore" "NovaAdapter")
        fi
    else
        log_error "Failed to release SPM"
        OVERALL_SUCCESS="false"
        SPM_FAILED+=("SPM release failed")
    fi
}

# Step 4: Push release branch
push_release_branch() {
    if [[ "$SKIP_PUSH" == "true" ]]; then
        log_info "Skipping push (--skip-push flag)"
        return 0
    fi
    
    log_release "Step 4: Pushing release branch"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would push release branch $RELEASE_BRANCH to remote"
        return 0
    fi
    
    # Ensure we're on release branch (skip in dry-run mode)
    if [[ "$DRY_RUN" != "true" ]]; then
        git checkout "$RELEASE_BRANCH"
    fi
    
    # Push release branch
    if git push origin "$RELEASE_BRANCH"; then
        log_success "Release branch pushed successfully"
        GITHUB_RELEASES_SUCCESS+=("Release branch $RELEASE_BRANCH")
    else
        log_error "Failed to push release branch"
        OVERALL_SUCCESS="false"
        GITHUB_RELEASES_FAILED+=("Release branch $RELEASE_BRANCH")
    fi
}

# Show comprehensive release summary
show_comprehensive_release_summary() {
    print_section "Release Process Summary"
    
    # Calculate duration
    local duration=""
    if [[ -n "$RELEASE_START_TIME" && -n "$RELEASE_END_TIME" ]]; then
        local start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELEASE_START_TIME" "+%s" 2>/dev/null || date -d "$RELEASE_START_TIME" "+%s" 2>/dev/null)
        local end_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELEASE_END_TIME" "+%s" 2>/dev/null || date -d "$RELEASE_END_TIME" "+%s" 2>/dev/null)
        if [[ -n "$start_epoch" && -n "$end_epoch" ]]; then
            local duration_seconds=$((end_epoch - start_epoch))
            local minutes=$((duration_seconds / 60))
            local seconds=$((duration_seconds % 60))
            duration="${minutes}m ${seconds}s"
        fi
    fi
    
    # Overall status
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log_success "🎉 Release $VERSION completed successfully!"
    else
        log_error "❌ Release $VERSION completed with errors"
    fi
    
    echo ""
    log_info "Release Details:"
    log_info "  Version: $VERSION"
    log_info "  Release Branch: $RELEASE_BRANCH"
    log_info "  Base Branch: $BASE_BRANCH"
    log_info "  Start Time: $RELEASE_START_TIME"
    log_info "  End Time: $RELEASE_END_TIME"
    if [[ -n "$duration" ]]; then
        log_info "  Duration: $duration"
    fi
    echo ""
    
    # CocoaPods Results
    if [[ "$SKIP_COCOAPODS" != "true" ]]; then
        print_subsection "CocoaPods Release Results"
        
        if [[ ${#COCOAPODS_SUCCESS[@]} -gt 0 ]]; then
            log_success "✅ Successfully Released:"
            for pod in "${COCOAPODS_SUCCESS[@]}"; do
                log_info "  - $pod"
            done
            echo ""
        fi
        
        if [[ ${#COCOAPODS_FAILED[@]} -gt 0 ]]; then
            log_error "❌ Failed to Release:"
            for pod in "${COCOAPODS_FAILED[@]}"; do
                log_info "  - $pod"
            done
            echo ""
        fi
    else
        log_info "CocoaPods release skipped (--skip-cocoapods flag)"
        echo ""
    fi
    
    # SPM Results
    if [[ "$SKIP_SPM" != "true" ]]; then
        print_subsection "SPM Release Results"
        
        if [[ ${#SPM_SUCCESS[@]} -gt 0 ]]; then
            log_success "✅ Successfully Released:"
            for package in "${SPM_SUCCESS[@]}"; do
                log_info "  - $package"
            done
            echo ""
        fi
        
        if [[ ${#SPM_FAILED[@]} -gt 0 ]]; then
            log_error "❌ Failed to Release:"
            for package in "${SPM_FAILED[@]}"; do
                log_info "  - $package"
            done
            echo ""
        fi
    else
        log_info "SPM release skipped (--skip-spm flag)"
        echo ""
    fi
    
    # GitHub Releases Results
    print_subsection "GitHub Releases Results"
    
    if [[ ${#GITHUB_RELEASES_SUCCESS[@]} -gt 0 ]]; then
        log_success "✅ Successfully Created:"
        for release in "${GITHUB_RELEASES_SUCCESS[@]}"; do
            log_info "  - $release"
        done
        echo ""
    fi
    
    if [[ ${#GITHUB_RELEASES_FAILED[@]} -gt 0 ]]; then
        log_error "❌ Failed to Create:"
        for release in "${GITHUB_RELEASES_FAILED[@]}"; do
            log_info "  - $release"
        done
        echo ""
    fi
    
    # Next Steps
    print_subsection "Next Steps"
    
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log_info "1. Verify the release on GitHub: https://github.com/ParticleMedia/msp-ios-sdk-public/releases/tag/$VERSION"
        log_info "2. Test CocoaPods installation: pod 'MSPCore', '~> $VERSION'"
        log_info "3. Test SPM installation: .package(url: \"https://github.com/ParticleMedia/msp-ios-sdk-public.git\", from: \"$VERSION\")"
        log_info "4. Create pull request to merge release branch if needed"
    else
        log_info "1. Review the failed components above"
        log_info "2. Fix any issues and retry the release"
        log_info "3. Check logs for detailed error information"
    fi
    echo ""
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Validate inputs
    validate_inputs
    
    # Ensure we're in the project root
    ensure_project_root
    
    print_section "Starting Complete Release Process for Version: $VERSION"
    
    # Record start time
    RELEASE_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Step 0: Pre-release setup (build frameworks)
    pre_release_setup
    
    # Step 1: Create release branch
    create_release_branch
    
    # Step 2: Release CocoaPods
    release_cocoapods
    
    # Step 3: Release SPM
    release_spm
    
    # Step 4: Push release branch
    push_release_branch
    
    # Record end time
    RELEASE_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Show comprehensive summary
    show_comprehensive_release_summary
}

# Show usage if no arguments provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Run main function with all arguments
main "$@"
