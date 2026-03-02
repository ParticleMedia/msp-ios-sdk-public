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
# tf_compute_next_build_number — current + 1 or use override
# ---------------------------------------------------------------------------
tf_compute_next_build_number() {
    local override="${1:-}"

    if [[ -n "$override" ]]; then
        TF_NEXT_BUILD_NUMBER="$override"
        log::info "TF-CONFIG" "Using overridden build number: $TF_NEXT_BUILD_NUMBER"
    else
        TF_NEXT_BUILD_NUMBER=$(( TF_BUILD_NUMBER + 1 ))
        log::info "TF-CONFIG" "Next build number: $TF_NEXT_BUILD_NUMBER (was $TF_BUILD_NUMBER)"
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
