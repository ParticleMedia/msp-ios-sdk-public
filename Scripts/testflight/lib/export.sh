#!/usr/bin/env bash
# ============================================================================
# TestFlight Export — xcodebuild -exportArchive for App Store
# ============================================================================
# Exports a signed .xcarchive to an IPA using the ExportOptions.plist template.
#
# Exports:
#   tf_export - Export the archive to IPA
# ============================================================================

# Module guard
[[ -n "${_TF_EXPORT_SOURCED:-}" ]] && return 0
_TF_EXPORT_SOURCED=1

tf_export() {
    log::info "TF-EXPORT" "Exporting IPA from archive..."

    local export_options="$ROOT_DIR/Scripts/testflight/templates/ExportOptions.plist"

    if [[ ! -f "$export_options" ]]; then
        log::error "TF-EXPORT" "ExportOptions.plist not found: $export_options"
        return "${EXIT_BUILD_ERROR}"
    fi

    # Ensure export directory exists and is clean
    ensure_directory "$ROOT_DIR/$TF_EXPORT_PATH"
    safe_remove "$ROOT_DIR/$TF_EXPORT_PATH"
    ensure_directory "$ROOT_DIR/$TF_EXPORT_PATH"

    start_timer

    # Build xcodebuild arguments
    local -a xc_args=(
        -archivePath "$ROOT_DIR/$TF_ARCHIVE_PATH"
        -exportPath "$ROOT_DIR/$TF_EXPORT_PATH"
        -exportOptionsPlist "$export_options"
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
        log::warn "TF-EXPORT" "ASC credentials not set — using local Keychain for signing"
    fi

    xcodebuild -exportArchive "${xc_args[@]}" \
        | tee "$ROOT_DIR/$TF_LOG_PATH/export.log"

    local exit_code=${PIPESTATUS[0]}
    local duration
    duration=$(end_timer)

    if [[ $exit_code -ne 0 ]]; then
        log::error "TF-EXPORT" "Export failed (exit $exit_code) — see $TF_LOG_PATH/export.log"
        return "${EXIT_BUILD_ERROR}"
    fi

    # Verify IPA was created
    local ipa_file
    ipa_file=$(find "$ROOT_DIR/$TF_EXPORT_PATH" -name "*.ipa" -maxdepth 1 | head -1)

    if [[ -z "$ipa_file" ]]; then
        log::error "TF-EXPORT" "No IPA file found in $TF_EXPORT_PATH after export"
        return "${EXIT_BUILD_ERROR}"
    fi

    TF_IPA_PATH="$ipa_file"
    export TF_IPA_PATH

    local ipa_size
    ipa_size=$(get_file_size "$ipa_file")
    log::success "TF-EXPORT" "IPA exported ($ipa_size): $(basename "$ipa_file") ($(format_duration "$duration"))"
    return 0
}
