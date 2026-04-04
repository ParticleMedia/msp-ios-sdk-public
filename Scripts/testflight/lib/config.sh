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

tf_query_asc_build_number() {
    local query_label="${1:-build-number-query}"
    local version="${2:-${TF_SDK_VERSION:-}}"
    local asc_build_number=""
    local raw_output=""
    local normalized_output=""
    local fastlane_exit_code=0

    if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_PATH:-}" ]]; then
        log::error "TF-CONFIG" "ASC credentials are incomplete for query '$query_label'"
        return 1
    fi

    ensure_directory "$ROOT_DIR/$TF_LOG_PATH"

    local api_key_json
    api_key_json="$(mktemp "${TMPDIR:-/tmp}/asc_api_key.XXXXXX")"

    python3 - "$ASC_KEY_PATH" "$ASC_KEY_ID" "$ASC_ISSUER_ID" <<'PYEOF' > "$api_key_json"
import json, sys
key_path, key_id, issuer_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(key_path, 'r') as f:
    key_content = f.read()
print(json.dumps({
    "key_id": key_id,
    "issuer_id": issuer_id,
    "key": key_content,
    "in_house": False,
}, indent=4))
PYEOF

    local -a fastlane_args=(
        run latest_testflight_build_number
        app_identifier:"${TF_BUNDLE_ID}"
        api_key_path:"$api_key_json"
    )
    if [[ -n "$version" ]]; then
        fastlane_args+=(version:"$version")
    fi

    raw_output="$(FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_DISABLE_COLORS=1 FASTLANE_HIDE_TIMESTAMP=1 \
        bundle exec fastlane "${fastlane_args[@]}" 2>&1)" || fastlane_exit_code=$?

    rm -f "$api_key_json"

    local raw_log="$ROOT_DIR/$TF_LOG_PATH/${query_label}.raw.log"
    local normalized_log="$ROOT_DIR/$TF_LOG_PATH/${query_label}.log"
    printf '%s\n' "$raw_output" > "$raw_log"

    local ansi_esc=$'\033'
    normalized_output="$(printf '%s\n' "$raw_output" \
        | sed "s/${ansi_esc}\[[0-9;]*[[:alpha:]]//g" \
        | tr -d '\r')" || true
    printf '%s\n' "$normalized_output" > "$normalized_log"

    export TF_LAST_ASC_QUERY_RAW_LOG="$raw_log"
    export TF_LAST_ASC_QUERY_LOG="$normalized_log"
    export TF_LAST_ASC_QUERY_EXIT_CODE="$fastlane_exit_code"
    export TF_LAST_ASC_QUERY_VERSION="$version"

    asc_build_number="$(printf '%s\n' "$normalized_output" \
        | sed -n -E 's/.*Result:[[:space:]]*([0-9]+).*/\1/p' \
        | tail -1 \
        | tr -d '[:space:]')" || true

    if [[ -n "$asc_build_number" && "$asc_build_number" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$asc_build_number"
        return 0
    fi

    return 1
}

tf_asc_query_returned_no_builds() {
    local log_file="${1:-${TF_LAST_ASC_QUERY_LOG:-}}"
    if [[ -z "$log_file" || ! -f "$log_file" ]]; then
        return 1
    fi

    if grep -Eqi \
        'Could not find (a )?build|Could not find any build|There are no builds|No build found|No data found|couldn.t find a build' \
        "$log_file"; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# tf_load_config — parse config.yaml into shell variables
# ---------------------------------------------------------------------------
tf_load_config() {
    local config_file="$ROOT_DIR/Scripts/testflight/config.yaml"

    if [[ ! -f "$config_file" ]]; then
        log::error "TF-CONFIG" "Config file not found: $config_file"
        return "${EXIT_CONFIG_ERROR}"
    fi

    # Helper: extract a top-level key (no indentation — avoids matching same-named
    # keys in nested sections).
    _yaml_top_value() {
        local key="$1"
        local val
        val="$(grep -E "^${key}:" "$config_file" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/[[:space:]]*$//')"
        val="${val#\"}" ; val="${val%\"}"
        val="${val#\'}" ; val="${val%\'}"
        printf '%s' "$val"
    }

    # Helper: extract a nested key (must have leading whitespace — avoids matching
    # top-level keys or sibling sections with the same name).
    _yaml_value() {
        local key="$1"
        local val
        val="$(grep -E "^[[:space:]]+${key}:" "$config_file" | head -1 | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed 's/[[:space:]]*$//')"
        val="${val#\"}" ; val="${val%\"}"
        val="${val#\'}" ; val="${val%\'}"
        printf '%s' "$val"
    }

    # Top-level (no indentation)
    TF_SCHEMA_VERSION="$(_yaml_top_value "schema_version")"
    TF_BUILD_NUMBER="$(_yaml_top_value "build_number")"

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
# tf_compute_next_build_number — query ASC for latest, then +1
# In real uploads, ASC is the source of truth. If ASC lookup fails, abort.
# Only dry-run mode falls back to local config.yaml for convenience.
# ---------------------------------------------------------------------------
tf_compute_next_build_number() {
    local override="${1:-}"

    if [[ -n "$override" ]]; then
        TF_NEXT_BUILD_NUMBER="$override"
        log::info "TF-CONFIG" "Using overridden build number: $TF_NEXT_BUILD_NUMBER"
        export TF_NEXT_BUILD_NUMBER
        return 0
    fi

    # Try to query the latest build number from ASC in real-time.
    # Scope the query to the current marketing version to avoid mixing trains.
    local asc_build_number=""
    local version_scoped_query_empty=false
    asc_build_number="$(tf_query_asc_build_number "build-number-query" "${TF_SDK_VERSION:-}")" || true
    if [[ -z "$asc_build_number" || ! "$asc_build_number" =~ ^[0-9]+$ ]]; then
        if tf_asc_query_returned_no_builds "${TF_LAST_ASC_QUERY_LOG:-}"; then
            version_scoped_query_empty=true
        fi
    fi

    if [[ -n "$asc_build_number" && "$asc_build_number" =~ ^[0-9]+$ ]]; then
        # Use whichever is higher: ASC or local config, then +1
        local base
        base=$(( asc_build_number > TF_BUILD_NUMBER ? asc_build_number : TF_BUILD_NUMBER ))
        TF_NEXT_BUILD_NUMBER=$(( base + 1 ))
        log::info "TF-CONFIG" "Next build number: $TF_NEXT_BUILD_NUMBER (ASC latest=$asc_build_number, local=$TF_BUILD_NUMBER)"
    else
        local unscoped_asc_build_number=""
        local unscoped_query_empty=false
        unscoped_asc_build_number="$(tf_query_asc_build_number "build-number-query-unscoped" "")" || true
        if [[ -z "$unscoped_asc_build_number" || ! "$unscoped_asc_build_number" =~ ^[0-9]+$ ]]; then
            if tf_asc_query_returned_no_builds "${TF_LAST_ASC_QUERY_LOG:-}"; then
                unscoped_query_empty=true
            fi
        fi

        if [[ -n "$unscoped_asc_build_number" && "$unscoped_asc_build_number" =~ ^[0-9]+$ ]]; then
            local base
            base=$(( unscoped_asc_build_number > TF_BUILD_NUMBER ? unscoped_asc_build_number : TF_BUILD_NUMBER ))
            TF_NEXT_BUILD_NUMBER=$(( base + 1 ))
            log::warn "TF-CONFIG" "No visible ASC builds found for version ${TF_SDK_VERSION:-unknown}; using app-wide latest build $unscoped_asc_build_number (next=$TF_NEXT_BUILD_NUMBER)"
        elif [[ "$version_scoped_query_empty" == "true" && "$unscoped_query_empty" == "true" ]]; then
            TF_NEXT_BUILD_NUMBER=$(( TF_BUILD_NUMBER + 1 ))
            log::warn "TF-CONFIG" "ASC reports no prior TestFlight builds for app ${TF_BUNDLE_ID}; using local config as initial build source (next=$TF_NEXT_BUILD_NUMBER)"
        elif [[ "${DRY_RUN_MODE:-false}" == "true" ]]; then
            TF_NEXT_BUILD_NUMBER=$(( TF_BUILD_NUMBER + 1 ))
            log::warn "TF-CONFIG" "Could not query ASC in dry-run mode — falling back to local config (next=$TF_NEXT_BUILD_NUMBER)"
        else
            log::error "TF-CONFIG" "Failed to query App Store Connect for the latest TestFlight build number"
            if [[ ${TF_LAST_ASC_QUERY_EXIT_CODE:-0} -ne 0 ]]; then
                log::error "TF-CONFIG" "fastlane latest_testflight_build_number exited with code ${TF_LAST_ASC_QUERY_EXIT_CODE}"
            fi

            local raw_excerpt=""
            raw_excerpt="$(tail -n 20 "${TF_LAST_ASC_QUERY_LOG:-/dev/null}" 2>/dev/null | sed '/^[[:space:]]*$/d')" || true
            if [[ -n "$raw_excerpt" ]]; then
                log::error "TF-CONFIG" "ASC query output (last lines):"
                while IFS= read -r line; do
                    log::error "TF-CONFIG" "  $line"
                done <<< "$raw_excerpt"
            fi

            if [[ -n "${TF_LAST_ASC_QUERY_VERSION:-}" ]]; then
                log::error "TF-CONFIG" "ASC query version filter: ${TF_LAST_ASC_QUERY_VERSION}"
            fi
            log::error "TF-CONFIG" "Full ASC query logs saved to ${TF_LAST_ASC_QUERY_LOG:-$TF_LOG_PATH/build-number-query.log}"

            log::error "TF-CONFIG" "Aborting upload to avoid reusing an existing build number. Re-run with --build-number only if you want to override manually."
            return "${EXIT_CONFIG_ERROR}"
        fi
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

    # Git commit + push
    git -C "$ROOT_DIR" add "$config_file"
    git -C "$ROOT_DIR" commit -m "chore(testflight): bump build number to ${TF_NEXT_BUILD_NUMBER}" || {
        log::warn "TF-CONFIG" "Git commit failed (IPA was already uploaded successfully)"
        return 0
    }
    log::success "TF-CONFIG" "Committed build number bump"

    # Push so the next CI run picks up the new build number.
    # Jenkins checks out in detached HEAD mode, so symbolic-ref may fail;
    # fall back to GIT_BRANCH env var (Jenkins sets it to "origin/<branch>").
    local branch
    branch="$(git -C "$ROOT_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
        branch="${GIT_BRANCH:-}"
        branch="${branch#origin/}"  # strip "origin/" prefix if present
    fi
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
        log::warn "TF-CONFIG" "Cannot determine branch for push (detached HEAD) — skipping"
        return 0
    fi
    git -C "$ROOT_DIR" push origin "HEAD:refs/heads/$branch" || {
        log::warn "TF-CONFIG" "Git push failed — build number committed locally but not pushed"
        return 0
    }
    log::success "TF-CONFIG" "Pushed build number bump to origin/$branch"
}
