#!/usr/bin/env bash
# ============================================================================
# TestFlight Upload — fastlane pilot with ASC API Key
# ============================================================================
# Uploads the IPA to App Store Connect via fastlane pilot.
# Generates a temporary API key JSON file (cleaned up on exit).
#
# Exports:
#   tf_upload - Upload IPA to TestFlight
# ============================================================================

# Module guard
[[ -n "${_TF_UPLOAD_SOURCED:-}" ]] && return 0
_TF_UPLOAD_SOURCED=1

tf_upload() {
    log::info "TF-UPLOAD" "Uploading to TestFlight..."

    if [[ -z "${TF_IPA_PATH:-}" ]] || [[ ! -f "${TF_IPA_PATH}" ]]; then
        log::error "TF-UPLOAD" "IPA file not found: ${TF_IPA_PATH:-<not set>}"
        return "${EXIT_DEPLOY_ERROR}"
    fi

    # Generate temporary API key JSON for fastlane
    local api_key_json
    api_key_json=$(mktemp "${TMPDIR:-/tmp}/asc_api_key.XXXXXX.json")

    # Ensure cleanup on exit
    trap "rm -f '$api_key_json'" EXIT

    cat > "$api_key_json" <<EOF
{
    "key_id": "${ASC_KEY_ID}",
    "issuer_id": "${ASC_ISSUER_ID}",
    "key_filepath": "${ASC_KEY_PATH}",
    "in_house": false
}
EOF

    # Build changelog from template
    local changelog="${TF_CHANGELOG_TEMPLATE:-Build {build_number} - Internal testing}"
    changelog="${changelog//\{build_number\}/$TF_NEXT_BUILD_NUMBER}"

    start_timer

    local pilot_args=(
        "--api_key_path" "$api_key_json"
        "--ipa" "$TF_IPA_PATH"
        "--changelog" "$changelog"
    )

    # Skip waiting for build processing if configured
    if [[ "${TF_SKIP_WAITING:-true}" == "true" ]]; then
        pilot_args+=("--skip_waiting_for_build_processing")
    fi

    bundle exec fastlane pilot upload "${pilot_args[@]}" | tee "$ROOT_DIR/$TF_LOG_PATH/upload.log"

    local exit_code=${PIPESTATUS[0]}
    local duration
    duration=$(end_timer)

    # Clean up API key JSON
    rm -f "$api_key_json"

    if [[ $exit_code -ne 0 ]]; then
        log::error "TF-UPLOAD" "Upload failed (exit $exit_code) — see $TF_LOG_PATH/upload.log"
        return "${EXIT_DEPLOY_ERROR}"
    fi

    log::success "TF-UPLOAD" "Upload complete ($(format_duration "$duration"))"
    return 0
}
