#!/usr/bin/env bash
# ============================================================================
# TestFlight Archive — xcodebuild archive with ASC Automatic Signing
# ============================================================================
# Builds a signed .xcarchive using App Store Connect API key authentication.
# Build number is injected via CURRENT_PROJECT_VERSION build setting
# (Info.plist is never modified directly).
#
# Exports:
#   tf_archive - Build the .xcarchive
# ============================================================================

# Module guard
[[ -n "${_TF_ARCHIVE_SOURCED:-}" ]] && return 0
_TF_ARCHIVE_SOURCED=1

tf_archive() {
    log::info "TF-ARCHIVE" "Archiving $TF_SCHEME (build $TF_NEXT_BUILD_NUMBER)..."

    # Ensure output directories exist
    ensure_directory "$ROOT_DIR/$TF_LOG_PATH"
    ensure_directory "$(dirname "$ROOT_DIR/$TF_ARCHIVE_PATH")"

    # Clean previous archive
    safe_remove "$ROOT_DIR/$TF_ARCHIVE_PATH"

    # Inject version directly into Info.plist before archive.
    # xcodebuild command-line build settings (MARKETING_VERSION, CURRENT_PROJECT_VERSION)
    # are unreliable on certain CI/Xcode combinations, so we write literal values.
    local info_plist=""
    if [[ -f "$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist" ]]; then
        info_plist="$ROOT_DIR/Examples/MSPDemoApp/MSPDemoApp/Info.plist"
    elif [[ -f "$ROOT_DIR/MSPDemoApp/MSPDemoApp/Info.plist" ]]; then
        info_plist="$ROOT_DIR/MSPDemoApp/MSPDemoApp/Info.plist"
    else
        log::error "TF-ARCHIVE" "DemoApp Info.plist not found in supported layouts"
        return "${EXIT_BUILD_ERROR}"
    fi
    local mkt_version="${TF_SDK_VERSION:-0.0.1}"
    local bld_version="$TF_NEXT_BUILD_NUMBER"

    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $mkt_version" "$info_plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bld_version" "$info_plist"
    log::info "TF-ARCHIVE" "Injected version into Info.plist: $mkt_version ($bld_version)"
    # Advertise the plist path so deploy.sh's EXIT trap can restore it even on
    # SIGKILL or Jenkins abort (when the restore lines below are never reached).
    export _TF_INFO_PLIST="$info_plist"

    start_timer

    # Build xcodebuild flags (must come before build settings)
    local -a xc_flags=(
        -workspace "$ROOT_DIR/$TF_WORKSPACE"
        -scheme "$TF_SCHEME"
        -configuration "$TF_CONFIGURATION"
        -archivePath "$ROOT_DIR/$TF_ARCHIVE_PATH"
        -destination "generic/platform=iOS"
        -allowProvisioningUpdates
        -quiet
    )

    # ASC API key auth (only when credentials are available; dry-run may skip)
    if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
        xc_flags+=(
            -authenticationKeyPath "$ASC_KEY_PATH"
            -authenticationKeyID "$ASC_KEY_ID"
            -authenticationKeyIssuerID "$ASC_ISSUER_ID"
        )
    else
        log::warn "TF-ARCHIVE" "ASC credentials not set — using local Keychain for signing"
    fi

    # Build settings (after all flags)
    local -a xc_settings=(
        CURRENT_PROJECT_VERSION="$TF_NEXT_BUILD_NUMBER"
        MARKETING_VERSION="${TF_SDK_VERSION:-0.0.1}"
        DEVELOPMENT_TEAM="$TF_TEAM_ID"
        CODE_SIGN_STYLE=Automatic
        BUILD_TESTING=NO
    )

    log::info "TF-ARCHIVE" "MARKETING_VERSION=${TF_SDK_VERSION:-0.0.1} CURRENT_PROJECT_VERSION=$TF_NEXT_BUILD_NUMBER"

    # Use || to capture exit code without triggering set -e, so the Info.plist
    # restore below always runs even when xcodebuild fails (same pattern as upload.sh).
    local exit_code=0
    xcodebuild archive "${xc_flags[@]}" "${xc_settings[@]}" \
        2>&1 | tee "$ROOT_DIR/$TF_LOG_PATH/archive.log" \
        || exit_code=${PIPESTATUS[0]}
    local duration
    duration=$(end_timer)

    # Always restore Info.plist to build-setting variables regardless of outcome.
    # Restoring here (before error check) prevents a dirty Info.plist from being
    # left in the working tree when the archive fails.
    /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(MARKETING_VERSION)' "$info_plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(CURRENT_PROJECT_VERSION)' "$info_plist"
    unset _TF_INFO_PLIST

    if [[ $exit_code -ne 0 ]]; then
        log::error "TF-ARCHIVE" "Archive failed (exit $exit_code) — see $TF_LOG_PATH/archive.log"
        return "${EXIT_BUILD_ERROR}"
    fi

    # Verify archive was created
    if [[ ! -d "$ROOT_DIR/$TF_ARCHIVE_PATH" ]]; then
        log::error "TF-ARCHIVE" "Archive directory not found after build: $TF_ARCHIVE_PATH"
        return "${EXIT_BUILD_ERROR}"
    fi

    log::success "TF-ARCHIVE" "Archive complete ($(format_duration "$duration"))"
    return 0
}
