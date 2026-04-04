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

tf_verify_uploaded_build_visible() {
    local target_build="$TF_NEXT_BUILD_NUMBER"
    local target_version="${TF_SDK_VERSION:-}"
    local max_attempts="${TF_ASC_VERIFY_ATTEMPTS:-12}"
    local interval_seconds="${TF_ASC_VERIFY_INTERVAL_SECONDS:-30}"
    local attempt=1

    log::info "TF-UPLOAD" "Verifying build visibility in App Store Connect: version=${target_version:-unknown} build=$target_build"

    while [[ $attempt -le $max_attempts ]]; do
        local latest_visible_build=""
        latest_visible_build="$(tf_query_asc_build_number "post-upload-verify" "$target_version")" || true

        if [[ -n "$latest_visible_build" && "$latest_visible_build" =~ ^[0-9]+$ ]]; then
            if (( latest_visible_build >= target_build )); then
                log::success "TF-UPLOAD" "ASC verification passed: latest visible build for version ${target_version:-unknown} is $latest_visible_build"
                return 0
            fi

            log::warn "TF-UPLOAD" "ASC verification attempt $attempt/$max_attempts: latest visible build for version ${target_version:-unknown} is $latest_visible_build, waiting for >= $target_build"
        else
            log::warn "TF-UPLOAD" "ASC verification attempt $attempt/$max_attempts failed — see ${TF_LAST_ASC_QUERY_LOG:-$TF_LOG_PATH/post-upload-verify.log}"
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            sleep "$interval_seconds"
        fi
        ((attempt++))
    done

    log::error "TF-UPLOAD" "Uploaded build $target_build did not become visible in ASC for version ${target_version:-unknown}"
    log::error "TF-UPLOAD" "Last ASC verification log: ${TF_LAST_ASC_QUERY_LOG:-$TF_LOG_PATH/post-upload-verify.log}"
    return "${EXIT_DEPLOY_ERROR}"
}

tf_upload() {
    log::info "TF-UPLOAD" "Uploading to TestFlight..."

    if [[ -z "${TF_IPA_PATH:-}" ]] || [[ ! -f "${TF_IPA_PATH}" ]]; then
        log::error "TF-UPLOAD" "IPA file not found: ${TF_IPA_PATH:-<not set>}"
        return "${EXIT_DEPLOY_ERROR}"
    fi

    # Generate temporary API key JSON for fastlane
    local api_key_json
    api_key_json=$(mktemp "${TMPDIR:-/tmp}/asc_api_key.XXXXXX")

    # fastlane spaceship requires "key" (raw .p8 content), not "key_filepath"
    python3 - "$ASC_KEY_PATH" "$ASC_KEY_ID" "$ASC_ISSUER_ID" <<'PYEOF' > "$api_key_json"
import json, sys
key_path, key_id, issuer_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(key_path, 'r') as f:
    key_content = f.read()
payload = {
    'key_id': key_id,
    'issuer_id': issuer_id,
    'key': key_content,
    'in_house': False,
}
print(json.dumps(payload, indent=4))
PYEOF

    # Build changelog from template
    local changelog="${TF_CHANGELOG_TEMPLATE:-Build {build_number} - Internal testing}"
    changelog="${changelog//\{build_number\}/$TF_NEXT_BUILD_NUMBER}"

    start_timer

    local upload_raw_log="$ROOT_DIR/$TF_LOG_PATH/upload.raw.log"
    local upload_log="$ROOT_DIR/$TF_LOG_PATH/upload.log"
    local transporter_extra_args="${TF_ITMSTRANSPORTER_EXTRA_ARGS:--v eXtreme}"
    local bundle_bin=""
    local -a clean_env_args=()

    local pilot_args=(
        "--api_key_path" "$api_key_json"
        "--ipa" "$TF_IPA_PATH"
        "--app_identifier" "$TF_BUNDLE_ID"
        "--app_version" "${TF_SDK_VERSION:-0.0.1}"
        "--build_number" "$TF_NEXT_BUILD_NUMBER"
        "--changelog" "$changelog"
        "--wait_processing_interval" "${TF_WAIT_PROCESSING_INTERVAL_SECONDS:-30}"
        "--wait_processing_timeout_duration" "${TF_WAIT_PROCESSING_TIMEOUT_SECONDS:-1800}"
    )

    # Do not use skip_waiting_for_build_processing here.
    # We want pilot to surface ASC processing failures instead of reporting
    # transport success only.
    if [[ "${TF_SKIP_WAITING:-true}" == "true" ]]; then
        log::warn "TF-UPLOAD" "TF_SKIP_WAITING=true is ignored in CI verification mode; waiting for ASC processing instead"
    fi

    log::info "TF-UPLOAD" "Waiting for ASC processing: interval=${TF_WAIT_PROCESSING_INTERVAL_SECONDS:-30}s timeout=${TF_WAIT_PROCESSING_TIMEOUT_SECONDS:-1800}s"
    log::info "TF-UPLOAD" "Verbose upload logs: raw=${upload_raw_log#$ROOT_DIR/} normalized=${upload_log#$ROOT_DIR/}"
    log::info "TF-UPLOAD" "iTMSTransporter extra args: $transporter_extra_args"
    log::info "TF-UPLOAD" "Proxy env before fastlane: http_proxy=${http_proxy:-<unset>} https_proxy=${https_proxy:-<unset>} HTTP_PROXY=${HTTP_PROXY:-<unset>} HTTPS_PROXY=${HTTPS_PROXY:-<unset>} all_proxy=${all_proxy:-<unset>} ALL_PROXY=${ALL_PROXY:-<unset>} no_proxy=${no_proxy:-<unset>} NO_PROXY=${NO_PROXY:-<unset>} CGI_HTTP_PROXY=${CGI_HTTP_PROXY:-<unset>} SPACESHIP_DEBUG=${SPACESHIP_DEBUG:-<unset>} SPACESHIP_PROXY=${SPACESHIP_PROXY:-<unset>}"

    bundle_bin="$(command -v bundle || true)"
    if [[ -z "$bundle_bin" ]]; then
        log::error "TF-UPLOAD" "Could not resolve bundle executable from PATH"
        return "${EXIT_DEPLOY_ERROR}"
    fi
    log::info "TF-UPLOAD" "Using bundle executable: $bundle_bin"

    clean_env_args=(
        "-i"
        "HOME=$HOME"
        "PATH=$PATH"
        "LANG=${LANG:-en_US.UTF-8}"
        "LC_ALL=${LC_ALL:-en_US.UTF-8}"
        "CI=${CI:-true}"
        "TMPDIR=${TMPDIR:-/tmp}"
        "FASTLANE_SKIP_UPDATE_CHECK=1"
        "FASTLANE_DISABLE_COLORS=1"
        "FASTLANE_HIDE_TIMESTAMP=1"
        "FASTLANE_VERBOSE=1"
        "http_proxy="
        "https_proxy="
        "HTTP_PROXY="
        "HTTPS_PROXY="
        "all_proxy="
        "ALL_PROXY="
        "CGI_HTTP_PROXY="
        "no_proxy=*"
        "NO_PROXY=*"
        "DELIVER_ITMSTRANSPORTER_ADDITIONAL_UPLOAD_PARAMETERS=$transporter_extra_args"
    )

    # Only pass DEVELOPER_DIR when non-empty. Passing an explicit empty string is
    # worse than omitting it — env -i DEVELOPER_DIR= would override the system
    # default and cause pilot/altool to pick the wrong Xcode toolchain.
    if [[ -n "${DEVELOPER_DIR:-}" ]]; then
        clean_env_args+=("DEVELOPER_DIR=$DEVELOPER_DIR")
    fi

    local optional_env_var=""
    for optional_env_var in \
        RBENV_ROOT \
        RBENV_VERSION \
        RBENV_DIR \
        GEM_HOME \
        GEM_PATH \
        RUBYLIB \
        RUBYOPT \
        BUNDLE_GEMFILE \
        BUNDLE_APP_CONFIG \
        BUNDLE_BIN_PATH \
        BUNDLE_PATH \
        BUNDLE_WITHOUT \
        BUNDLE_FROZEN \
        BUNDLE_DEPLOYMENT \
        BUNDLE_JOBS \
        BUNDLE_RETRY
    do
        if [[ -n "${!optional_env_var+x}" ]]; then
            clean_env_args+=("${optional_env_var}=${!optional_env_var}")
        fi
    done

    # Use || to capture exit code without triggering set -e, so the API key
    # JSON cleanup below always runs even when fastlane fails.
    local exit_code=0
    env "${clean_env_args[@]}" "$bundle_bin" exec fastlane pilot upload "${pilot_args[@]}" 2>&1 | tee "$upload_raw_log" \
        || exit_code=$?

    perl -pe 's/\r$//; s/\e\[[0-9;]*[A-Za-z]//g' "$upload_raw_log" > "$upload_log"

    local duration
    duration=$(end_timer)

    # Always clean up API key JSON (contains sensitive private key content)
    rm -f "$api_key_json"

    if [[ $exit_code -ne 0 ]]; then
        log::error "TF-UPLOAD" "Upload failed (exit $exit_code) — see $TF_LOG_PATH/upload.log"
        log::error "TF-UPLOAD" "Raw upload log: ${upload_raw_log#$ROOT_DIR/}"
        return "${EXIT_DEPLOY_ERROR}"
    fi

    if ! tf_verify_uploaded_build_visible; then
        log::error "TF-UPLOAD" "Upload transport completed, but ASC did not confirm build visibility"
        return "${EXIT_DEPLOY_ERROR}"
    fi

    log::success "TF-UPLOAD" "Upload complete ($(format_duration "$duration"))"
    return 0
}
