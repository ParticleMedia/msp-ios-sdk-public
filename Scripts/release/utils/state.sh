# ============================================================================
# MSP Release State Management
# ============================================================================
# Purpose: Persistent state tracking for release operations
#          Backed by .msp-release-state.json in repo root
#
# Usage:
#   source Scripts/release/utils/state.sh
#   msp_state_init "run"
#   msp_state_mark_step_running "preflight"
#   msp_state_mark_step_success "preflight"
#
# Dependencies:
#   - jq (optional, system becomes no-op if missing)
#   - MSP_STATE_DISABLE=1 to disable entirely
# ============================================================================

# ============================================================================
# Internal Helpers
# ============================================================================

# Compute repository root based on this file's location
# state.sh is located at Scripts/release/utils/state.sh
_msp_state_repo_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # ../../.. -> <repo_root>
    cd "${script_dir}/../../.." && pwd
}

# Get absolute path to state file
msp_state_file_path() {
    local root
    root="$(_msp_state_repo_root)"
    echo "${root}/.msp-release-state.json"
}

# Get current timestamp in ISO8601 format
_msp_state_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Safely update JSON file via jq
_msp_state_update_json() {
    local jq_filter="$1"
    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    local tmp
    tmp="${path}.tmp"

    if ! jq "$jq_filter" "$path" > "$tmp" 2>/dev/null; then
        # Do not overwrite the original file on jq failure
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$path"
    return 0
}

# ============================================================================
# Enable/Disable Detection
# ============================================================================

msp_state_is_enabled() {
    # If explicitly disabled, return 1
    if [[ "${MSP_STATE_DISABLE:-0}" == "1" ]]; then
        return 1
    fi

    # Require jq
    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

# ============================================================================
# Public API: State Initialization
# ============================================================================

msp_state_init() {
    local mode="${1:-unknown}"

    # Check if enabled
    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    # If file exists, only update timestamp
    if [[ -f "$path" ]]; then
        _msp_state_update_json ".timestamps.updated_at = \"$(_msp_state_now)\"" || return 0
        return 0
    fi

    # Get values from environment
    local version="${RELEASE_VERSION:-unknown}"
    local base_branch="${BASE_BRANCH:-unknown}"
    local release_branch="${RELEASE_BRANCH:-unknown}"
    local dry_run_val="${DRY_RUN:-false}"
    local config_path="${CONFIG_FILE:-null}"
    local cli_args="${MSP_RELEASE_ORIGINAL_ARGS:-}"
    local invoked_subcommand="${SUBCOMMAND:-${mode}}"

    # Normalize dry_run to boolean
    local dry_run_bool="false"
    if [[ "$dry_run_val" == "true" ]] || [[ "$dry_run_val" == "1" ]]; then
        dry_run_bool="true"
    fi

    # Normalize config_path
    if [[ -z "$config_path" ]] || [[ "$config_path" == "null" ]]; then
        config_path="null"
    else
        config_path="\"$config_path\""
    fi

    local now
    now="$(_msp_state_now)"

    # Create initial state JSON
    jq -n \
        --arg run_id "$now" \
        --arg mode "$mode" \
        --arg version "$version" \
        --arg base_branch "$base_branch" \
        --arg release_branch "$release_branch" \
        --argjson dry_run "$dry_run_bool" \
        --argjson config_path "$config_path" \
        --arg cli_args "$cli_args" \
        --arg invoked_subcommand "$invoked_subcommand" \
        --arg started_at "$now" \
        --arg updated_at "$now" \
        '{
            schema_version: 1,
            run_id: $run_id,
            mode: $mode,
            version: $version,
            base_branch: $base_branch,
            release_branch: $release_branch,
            dry_run: $dry_run,
            config: {
                config_path: ($config_path | if . == "null" then null else . end),
                cli_args: $cli_args,
                invoked_subcommand: $invoked_subcommand
            },
            git: {
                tag_created: false,
                tag_name: null,
                release_branch_pushed: false,
                github_release_created: false
            },
            steps: {},
            timestamps: {
                started_at: $started_at,
                updated_at: $updated_at
            },
            last_error: {
                step: null,
                message: null,
                exit_code: null,
                occurred_at: null
            }
        }' > "$path" 2>/dev/null || return 0

    return 0
}

# ============================================================================
# Public API: Step Status Management
# ============================================================================

msp_state_mark_step_running() {
    local step_name="$1"

    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    local now
    now="$(_msp_state_now)"

    # Check if step exists
    local step_exists
    step_exists=$(jq -e ".steps[\"$step_name\"] != null" "$path" 2>/dev/null || echo "false")

    if [[ "$step_exists" == "true" ]]; then
        # Increment attempt (or set to 1 if missing)
        local current_attempt
        current_attempt=$(jq -r ".steps[\"$step_name\"].attempt // 1" "$path" 2>/dev/null || echo "1")
        local new_attempt=$((current_attempt + 1))

        # Update existing step
        _msp_state_update_json ".steps[\"$step_name\"].status = \"running\" | .steps[\"$step_name\"].attempt = $new_attempt | .steps[\"$step_name\"].started_at = (if .steps[\"$step_name\"].started_at == null then \"$now\" else .steps[\"$step_name\"].started_at end) | .timestamps.updated_at = \"$now\"" || return 0
    else
        # Create new step
        _msp_state_update_json ".steps[\"$step_name\"] = {status: \"running\", attempt: 1, started_at: \"$now\", completed_at: null, notes: null} | .timestamps.updated_at = \"$now\"" || return 0
    fi

    return 0
}

msp_state_mark_step_success() {
    local step_name="$1"

    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    local now
    now="$(_msp_state_now)"

    # Ensure step exists, then update
    local step_exists
    step_exists=$(jq -e ".steps[\"$step_name\"] != null" "$path" 2>/dev/null || echo "false")

    if [[ "$step_exists" != "true" ]]; then
        # Create step first
        _msp_state_update_json ".steps[\"$step_name\"] = {status: \"success\", attempt: 1, started_at: \"$now\", completed_at: \"$now\", notes: null} | .timestamps.updated_at = \"$now\"" || return 0
    else
        # Update existing step
        _msp_state_update_json ".steps[\"$step_name\"].status = \"success\" | .steps[\"$step_name\"].started_at = (if .steps[\"$step_name\"].started_at == null then \"$now\" else .steps[\"$step_name\"].started_at end) | .steps[\"$step_name\"].completed_at = \"$now\" | .timestamps.updated_at = \"$now\"" || return 0
    fi

    return 0
}

msp_state_mark_step_failed() {
    local step_name="$1"
    local message="${2:-Unknown error}"
    local exit_code="${3:-1}"

    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    local now
    now="$(_msp_state_now)"

    # Truncate message if too long (limit to 500 chars)
    if [[ ${#message} -gt 500 ]]; then
        message="${message:0:497}..."
    fi

    # Escape message for JSON
    local message_json
    message_json=$(printf '%s' "$message" | jq -Rs .)

    # Ensure step exists, then update
    local step_exists
    step_exists=$(jq -e ".steps[\"$step_name\"] != null" "$path" 2>/dev/null || echo "false")

    if [[ "$step_exists" != "true" ]]; then
        # Create step first
        _msp_state_update_json ".steps[\"$step_name\"] = {status: \"failed\", attempt: 1, started_at: \"$now\", completed_at: \"$now\", notes: null} | .last_error = {step: \"$step_name\", message: $message_json, exit_code: $exit_code, occurred_at: \"$now\"} | .timestamps.updated_at = \"$now\"" || return 0
    else
        # Update existing step
        _msp_state_update_json ".steps[\"$step_name\"].status = \"failed\" | .steps[\"$step_name\"].started_at = (if .steps[\"$step_name\"].started_at == null then \"$now\" else .steps[\"$step_name\"].started_at end) | .steps[\"$step_name\"].completed_at = \"$now\" | .last_error = {step: \"$step_name\", message: $message_json, exit_code: $exit_code, occurred_at: \"$now\"} | .timestamps.updated_at = \"$now\"" || return 0
    fi

    return 0
}

msp_state_mark_step_skipped() {
    local step_name="$1"
    local reason="${2:-}"

    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    local now
    now="$(_msp_state_now)"

    # Ensure step exists, then update
    local step_exists
    step_exists=$(jq -e ".steps[\"$step_name\"] != null" "$path" 2>/dev/null || echo "false")

    if [[ "$step_exists" != "true" ]]; then
        # Create step first
        if [[ -n "$reason" ]]; then
            local reason_json
            reason_json=$(printf '%s' "$reason" | jq -Rs .)
            _msp_state_update_json ".steps[\"$step_name\"] = {status: \"skipped\", attempt: 0, started_at: null, completed_at: \"$now\", notes: $reason_json} | .timestamps.updated_at = \"$now\"" || return 0
        else
            _msp_state_update_json ".steps[\"$step_name\"] = {status: \"skipped\", attempt: 0, started_at: null, completed_at: \"$now\", notes: null} | .timestamps.updated_at = \"$now\"" || return 0
        fi
    else
        # Update existing step
        if [[ -n "$reason" ]]; then
            local reason_json
            reason_json=$(printf '%s' "$reason" | jq -Rs .)
            _msp_state_update_json ".steps[\"$step_name\"].status = \"skipped\" | .steps[\"$step_name\"].completed_at = \"$now\" | .steps[\"$step_name\"].notes = $reason_json | .timestamps.updated_at = \"$now\"" || return 0
        else
            _msp_state_update_json ".steps[\"$step_name\"].status = \"skipped\" | .steps[\"$step_name\"].completed_at = \"$now\" | .timestamps.updated_at = \"$now\"" || return 0
        fi
    fi

    return 0
}

msp_state_get_step_status() {
    local step_name="$1"

    if ! msp_state_is_enabled; then
        echo "unknown"
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    if [[ ! -f "$path" ]]; then
        echo "unknown"
        return 0
    fi

    local status
    status=$(jq -r ".steps[\"$step_name\"].status // \"unknown\"" "$path" 2>/dev/null || echo "unknown")
    echo "$status"
    return 0
}

# ============================================================================
# Public API: Git Flags and Timestamps
# ============================================================================

msp_state_mark_git_flag() {
    local field_name="$1"
    local bool_value="$2"

    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    # Normalize to JSON boolean
    local json_bool="false"
    if [[ "$bool_value" == "true" ]] || [[ "$bool_value" == "1" ]]; then
        json_bool="true"
    fi

    _msp_state_update_json ".git[\"$field_name\"] = $json_bool | .timestamps.updated_at = \"$(_msp_state_now)\"" || return 0

    return 0
}

msp_state_touch() {
    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    _msp_state_update_json ".timestamps.updated_at = \"$(_msp_state_now)\"" || return 0

    return 0
}

# Set tag name in state
msp_state_set_tag_name() {
    local name="$1"

    if ! msp_state_is_enabled; then
        return 0
    fi

    local path
    path="$(msp_state_file_path)"

    [[ -f "$path" ]] || return 0

    # Escape name for JSON
    local name_json
    name_json=$(printf '%s' "$name" | jq -Rs .)

    _msp_state_update_json ".git.tag_name = $name_json | .timestamps.updated_at = \"$(_msp_state_now)\"" || return 0

    return 0
}

# ============================================================================
# Export Functions
# ============================================================================
export -f msp_state_file_path
export -f msp_state_is_enabled
export -f msp_state_init
export -f msp_state_mark_step_running
export -f msp_state_mark_step_success
export -f msp_state_mark_step_failed
export -f msp_state_mark_step_skipped
export -f msp_state_get_step_status
export -f msp_state_mark_git_flag
export -f msp_state_touch
export -f msp_state_set_tag_name
