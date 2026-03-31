#!/usr/bin/env bash
# ============================================================================
# TestFlight Config Loader — Build Number Management
# ============================================================================
# Reads Scripts/testflight/config.yaml (lightweight grep/awk, no yq dependency).
# Manages build_number as SSOT for TestFlight uploads.
#
# Exports:
#   tf_load_config           - Parse config.yaml into TF_* variables
#   tf_compute_next_build_number - Increment or override build number
#   tf_commit_build_number   - Write back to config.yaml + git commit
# ============================================================================

# Module guard
[[ -n "${_TF_CONFIG_SOURCED:-}" ]] && return 0
_TF_CONFIG_SOURCED=1

# ---------------------------------------------------------------------------
# tf_load_config — parse config.yaml into shell variables
# ---------------------------------------------------------------------------
tf_load_config() {
    local config_file="$ROOT_DIR/Scripts/testflight/config.yaml"

    if [[ ! -f "$config_file" ]]; then
        log::error "TF-CONFIG" "Config file not found: $config_file"
        return "${EXIT_CONFIG_ERROR}"
    fi

    # Helper: extract a value for a given key (supports nested "parent.key" via indentation)
    _yaml_value() {
        local key="$1"
        grep -E "^[[:space:]]*${key}:" "$config_file" | head -1 | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed 's/[[:space:]]*$//'
    }

    # Top-level
    TF_SCHEMA_VERSION="$(_yaml_value "schema_version")"
    TF_BUILD_NUMBER="$(_yaml_value "build_number")"

    # app.*
    TF_SCHEME="$(_yaml_value "scheme")"
    TF_WORKSPACE="$(_yaml_value "workspace")"
    TF_BUNDLE_ID="$(_yaml_value "bundle_id")"
    TF_CONFIGURATION="$(_yaml_value "configuration")"

    # signing.*
    TF_TEAM_ID="$(_yaml_value "team_id")"

    # testflight.*
    TF_SKIP_WAITING="$(_yaml_value "skip_waiting")"
    TF_CHANGELOG_TEMPLATE="$(_yaml_value "changelog_template")"

    # output.*
    TF_ARCHIVE_PATH="$(_yaml_value "archive_path")"
    TF_EXPORT_PATH="$(_yaml_value "export_path")"
    TF_LOG_PATH="$(_yaml_value "log_path")"

    # Validate required fields
    local missing=()
    [[ -z "$TF_SCHEME" ]]        && missing+=("app.scheme")
    [[ -z "$TF_WORKSPACE" ]]     && missing+=("app.workspace")
    [[ -z "$TF_BUNDLE_ID" ]]     && missing+=("app.bundle_id")
    [[ -z "$TF_TEAM_ID" ]]       && missing+=("signing.team_id")
    [[ -z "$TF_BUILD_NUMBER" ]]  && missing+=("build_number")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log::error "TF-CONFIG" "Missing required config fields: ${missing[*]}"
        return "${EXIT_CONFIG_ERROR}"
    fi

    log::info "TF-CONFIG" "Config loaded — scheme=$TF_SCHEME build_number=$TF_BUILD_NUMBER"
    return 0
}

# ---------------------------------------------------------------------------
# tf_compute_next_build_number — query ASC for latest, then +1; fallback to config.yaml
# ---------------------------------------------------------------------------
tf_compute_next_build_number() {
    local override="${1:-}"

    if [[ -n "$override" ]]; then
        TF_NEXT_BUILD_NUMBER="$override"
        log::info "TF-CONFIG" "Using overridden build number: $TF_NEXT_BUILD_NUMBER"
        export TF_NEXT_BUILD_NUMBER
        return 0
    fi

    # Try to query the latest build number from ASC in real-time
    local asc_build_number=""
    if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
        local api_key_json
        api_key_json="$(mktemp -t asc_api_key)"

        cat > "$api_key_json" <<EOF
{
    "key_id": "${ASC_KEY_ID}",
    "issuer_id": "${ASC_ISSUER_ID}",
    "key_filepath": "${ASC_KEY_PATH}",
    "in_house": false
}
EOF

        local raw_output=""
        # Temporarily disable set -e so fastlane failure doesn't abort the script
        set +e
        raw_output="$(bundle exec fastlane run latest_testflight_build_number \
            app_identifier:"${TF_BUNDLE_ID}" \
            api_key_path:"$api_key_json" 2>&1)"
        set -e

        rm -f "$api_key_json"

        # Parse "Result: <number>" from fastlane output
        asc_build_number="$(echo "$raw_output" | grep -E "^[[:space:]]*Result:" | tail -1 | sed 's/.*Result:[[:space:]]*//' | tr -d '[:space:]')" || true
    fi

    if [[ -n "$asc_build_number" && "$asc_build_number" =~ ^[0-9]+$ ]]; then
        # Use whichever is higher: ASC or local config, then +1
        local base
        base=$(( asc_build_number > TF_BUILD_NUMBER ? asc_build_number : TF_BUILD_NUMBER ))
        TF_NEXT_BUILD_NUMBER=$(( base + 1 ))
        log::info "TF-CONFIG" "Next build number: $TF_NEXT_BUILD_NUMBER (ASC latest=$asc_build_number, local=$TF_BUILD_NUMBER)"
    else
        # Fallback to local config.yaml
        TF_NEXT_BUILD_NUMBER=$(( TF_BUILD_NUMBER + 1 ))
        log::warn "TF-CONFIG" "Could not query ASC — falling back to local config (next=$TF_NEXT_BUILD_NUMBER)"
    fi

    export TF_NEXT_BUILD_NUMBER
}

# ---------------------------------------------------------------------------
# tf_commit_build_number — persist new build_number to config.yaml + git
# ---------------------------------------------------------------------------
tf_commit_build_number() {
    local config_file="$ROOT_DIR/Scripts/testflight/config.yaml"

    # Replace the build_number line
    sed -i '' "s/^build_number: .*/build_number: ${TF_NEXT_BUILD_NUMBER}/" "$config_file"

    log::info "TF-CONFIG" "Updated config.yaml: build_number=$TF_NEXT_BUILD_NUMBER"

    # Git commit
    if command -v git >/dev/null 2>&1; then
        git -C "$ROOT_DIR" add "$config_file"
        git -C "$ROOT_DIR" commit -m "chore(testflight): bump build number to ${TF_NEXT_BUILD_NUMBER}" || {
            log::warn "TF-CONFIG" "Git commit failed (IPA was already uploaded successfully)"
            return 0
        }
        log::success "TF-CONFIG" "Committed build number bump"
    else
        log::warn "TF-CONFIG" "git not available — skipping commit"
    fi
}
