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

    start_timer

    # Build xcodebuild arguments
    local -a xc_args=(
        -workspace "$ROOT_DIR/$TF_WORKSPACE"
        -scheme "$TF_SCHEME"
        -configuration "$TF_CONFIGURATION"
        -archivePath "$ROOT_DIR/$TF_ARCHIVE_PATH"
        -destination "generic/platform=iOS"
        -allowProvisioningUpdates
    )

    # ASC API key auth (only when credentials are available; dry-run may skip)
    if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
        xc_args+=(
            -authenticationKeyPath "$ASC_KEY_PATH"
            -authenticationKeyID "$ASC_KEY_ID"
            -authenticationKeyIssuerID "$ASC_ISSUER_ID"
        )
    else
        log::warn "TF-ARCHIVE" "ASC credentials not set — using local Keychain for signing"
    fi

    xc_args+=(
        CURRENT_PROJECT_VERSION="$TF_NEXT_BUILD_NUMBER"
        MARKETING_VERSION="${TF_SDK_VERSION:-0.0.1}"
        DEVELOPMENT_TEAM="$TF_TEAM_ID"
        CODE_SIGN_STYLE=Automatic
    )

    xcodebuild archive "${xc_args[@]}" \
        | tee "$ROOT_DIR/$TF_LOG_PATH/archive.log"

    local exit_code=${PIPESTATUS[0]}
    local duration
    duration=$(end_timer)

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
