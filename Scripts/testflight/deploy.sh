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
# ============================================================================
# TestFlight Deploy — MSPDemoApp
# ============================================================================
# Orchestrates: validate → config → archive → export → upload → commit
#
# Usage:
#   ./Scripts/testflight/deploy.sh                    # Full deploy
#   ./Scripts/testflight/deploy.sh --dry-run           # Archive only, no upload
#   ./Scripts/testflight/deploy.sh --build-number 42   # Override build number
#   ./Scripts/testflight/deploy.sh --help
#
# Required environment variables:
#   ASC_KEY_ID       - App Store Connect API Key ID
#   ASC_ISSUER_ID    - App Store Connect Issuer ID
#   ASC_KEY_PATH     - Path to .p8 private key file
# ============================================================================

set -euo pipefail

# ---- Parse arguments ----
DRY_RUN_MODE=false
BUILD_NUMBER_OVERRIDE=""

print_usage() {
    cat <<'USAGE'
Usage: ./Scripts/testflight/deploy.sh [OPTIONS]

Options:
  --dry-run              Archive and export only, skip upload
  --build-number N       Use specific build number instead of auto-increment
  --help                 Show this help message

Environment variables:
  ASC_KEY_ID             App Store Connect API Key ID
  ASC_ISSUER_ID          App Store Connect Issuer ID
  ASC_KEY_PATH           Path to AuthKey .p8 file
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN_MODE=true
            shift
            ;;
        --build-number)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --build-number requires a value" >&2
                exit 1
            fi
            BUILD_NUMBER_OVERRIDE="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# ---- Bootstrap ----
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
export ROOT_DIR

# Source shared logging and utilities
# shellcheck source=Scripts/lib/common.sh
source "$ROOT_DIR/Scripts/lib/common.sh"
# shellcheck source=Scripts/release/utils/version.sh
source "$ROOT_DIR/Scripts/release/utils/version.sh"

# Load .env credentials if available (existing env vars take precedence)
_load_env_no_override() {
    local env_file="$1"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and blank lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Strip optional 'export ' prefix
        line="${line#export }"
        # Extract KEY=VALUE
        local key="${line%%=*}"
        local value="${line#*=}"
        # Remove surrounding quotes from value
        value="${value#\"}" ; value="${value%\"}"
        value="${value#\'}" ; value="${value%\'}"
        # Only set if not already defined
        if [[ -z "${!key+x}" ]]; then
            export "$key=$value"
        fi
    done < "$env_file"
}

_tf_env_file="$ROOT_DIR/Scripts/testflight/.env"
if [[ -f "$_tf_env_file" ]]; then
    _load_env_no_override "$_tf_env_file"
    log::info "TF-DEPLOY" "Loaded credentials from Scripts/testflight/.env"
fi
unset _tf_env_file

# Source TestFlight modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Keychain cleanup on EXIT ----
# Restores the original keychain search list and removes the CI keychain so
# that other Jenkins jobs on the same machine are not affected.
_CI_KEYCHAIN_NAME="${CI_KEYCHAIN_NAME:-msp-build.keychain}"
_CI_KEYCHAIN_RESTORE_FILE="${CI_KEYCHAIN_RESTORE_FILE:-$SCRIPT_DIR/.keychain_restore}"
_tf_cleanup_keychain() {
    # Restore Info.plist if archive.sh was interrupted mid-write (SIGKILL, Jenkins
    # abort). _TF_INFO_PLIST is exported by archive.sh before modifying the plist
    # and unset after the normal restore. If still set here, restore is needed.
    if [[ -n "${_TF_INFO_PLIST:-}" && -f "${_TF_INFO_PLIST}" ]]; then
        log::warn "TF-DEPLOY" "Restoring Info.plist after interrupted archive: $_TF_INFO_PLIST"
        /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(MARKETING_VERSION)' "$_TF_INFO_PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(CURRENT_PROJECT_VERSION)' "$_TF_INFO_PLIST" 2>/dev/null || true
    fi

    local restore_file="$_CI_KEYCHAIN_RESTORE_FILE"
    if [[ -f "$restore_file" ]]; then
        log::warn "TF-DEPLOY" "Restoring original keychain list..."
        # shellcheck disable=SC2046
        security list-keychains -d user -s $(cat "$restore_file") 2>/dev/null || true
        rm -f "$restore_file"
    fi
    log::warn "TF-DEPLOY" "Removing CI keychain: $_CI_KEYCHAIN_NAME"
    security delete-keychain "$_CI_KEYCHAIN_NAME" 2>/dev/null || true
}
trap '_tf_cleanup_keychain' EXIT
# shellcheck source=Scripts/testflight/lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=Scripts/testflight/lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=Scripts/testflight/lib/archive.sh
source "$SCRIPT_DIR/lib/archive.sh"
# shellcheck source=Scripts/testflight/lib/export.sh
source "$SCRIPT_DIR/lib/export.sh"
# shellcheck source=Scripts/testflight/lib/upload.sh
source "$SCRIPT_DIR/lib/upload.sh"

# ---- Main ----
main() {
    log::info "TF-DEPLOY" "============================================"
    log::info "TF-DEPLOY" "  MSPDemoApp TestFlight Deployment"
    log::info "TF-DEPLOY" "============================================"

    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log::warn "TF-DEPLOY" "DRY-RUN MODE — will archive & export but skip upload"
    fi

    # Step 1: Validate prerequisites
    tf_validate_prerequisites

    # Step 2: Load config
    tf_load_config

    # Step 3: Read SDK version from SSOT for MARKETING_VERSION
    TF_SDK_VERSION="$(read_sdk_version_from_config 2>/dev/null)" || {
        TF_SDK_VERSION="0.0.1"
        log::warn "TF-DEPLOY" "Could not read SDK version from SSOT, using fallback: $TF_SDK_VERSION"
    }
    export TF_SDK_VERSION

    # Step 3.5: Compute next build number (scoped to the target marketing version)
    tf_compute_next_build_number "$BUILD_NUMBER_OVERRIDE"

    # Print deployment summary
    log::info "TF-DEPLOY" "--------------------------------------------"
    log::info "TF-DEPLOY" "  Scheme:        $TF_SCHEME"
    log::info "TF-DEPLOY" "  Workspace:     $TF_WORKSPACE"
    log::info "TF-DEPLOY" "  Configuration: $TF_CONFIGURATION"
    log::info "TF-DEPLOY" "  Team ID:       $TF_TEAM_ID"
    log::info "TF-DEPLOY" "  Build Number:  $TF_NEXT_BUILD_NUMBER"
    log::info "TF-DEPLOY" "  SDK Version:   $TF_SDK_VERSION"
    log::info "TF-DEPLOY" "  Dry Run:       $DRY_RUN_MODE"
    log::info "TF-DEPLOY" "--------------------------------------------"

    # Step 4: Archive
    tf_archive

    # Step 5: Export
    tf_export

    # Step 6: Upload (skip in dry-run mode)
    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log::warn "TF-DEPLOY" "Skipping upload (dry-run mode)"
        log::info "TF-DEPLOY" "IPA available at: $TF_IPA_PATH"
    else
        tf_upload

        # Step 7: Commit build number (only after successful upload)
        tf_commit_build_number
    fi

    log::info "TF-DEPLOY" "============================================"
    log::success "TF-DEPLOY" "Deployment complete! (build $TF_NEXT_BUILD_NUMBER)"
    log::info "TF-DEPLOY" "============================================"
}

main "$@"
