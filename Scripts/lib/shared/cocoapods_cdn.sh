#!/usr/bin/env bash
# ============================================================================
# CocoaPods CDN Availability Module
# ============================================================================
# Module: shared/cocoapods_cdn.sh
# Purpose: Direct CDN URL check for CocoaPods podspec availability.
#          Replaces the brittle `pod repo update` + `pod search` chain.
#
# Functions:
#   cocoapods_cdn_compute_shard <pod_name>
#       Returns the 3-component shard path (e.g. "9/c/4") from md5(pod_name)
#
#   cocoapods_cdn_build_url <pod_name> <version>
#       Returns the full CDN URL for the podspec JSON
#
#   cocoapods_cdn_check_pod_available <pod_name> <version>
#       Exit 0  = HTTP 200 (available)
#       Exit 2  = HTTP 404 (not yet published)
#       Exit 3  = unreachable (timeout/5xx after all retries)
#       Exit 1  = bad arguments
#
#   cocoapods_cdn_metrics_init
#       Reset in-memory metrics accumulators for the current session
#
#   cocoapods_cdn_metrics_record <http_status> <latency_ms>
#       Update accumulators with one check result
#
#   cocoapods_cdn_metrics_flush_to_state
#       Write accumulated metrics to .msp-release-state.json via state.sh
#
#   cocoapods_cdn_emit_check_log <pod> <version> <status> <latency_ms> <attempt> <max> <url>
#       Emit a structured [CDN_CHECK] log line
#
#   cocoapods_cdn_emit_failure_block <pod> <version> <url> <last_err> <total_s>
#       Emit the human-readable triage block on CDN unreachable
#
# Override for tests:
#   CDN_CURL_CMD — replace the curl invocation entirely.
#                  Must echo an HTTP status code (e.g., "echo 200") or exit
#                  non-zero to simulate a network failure.
#
# Dependencies:
#   - curl
#   - md5 (macOS) or md5sum (Linux)
#   - jq (for metrics flush, optional — gracefully no-ops if absent)
#   - state.sh functions (msp_state_set_cdn_metrics) if flushing to state
# ============================================================================

set -euo pipefail

[[ -n "${_SHARED_COCOAPODS_CDN_SOURCED:-}" ]] && return 0
readonly _SHARED_COCOAPODS_CDN_SOURCED=1

# ============================================================================
# Internal: MD5 portability (macOS vs Linux)
# ============================================================================
_cocoapods_cdn_md5() {
    local input="$1"
    if command -v md5 >/dev/null 2>&1; then
        # macOS: md5 -q -s <string>
        printf '%s' "$input" | md5 -q 2>/dev/null \
            || printf '%s' "$input" | md5 2>/dev/null | awk '{print $NF}'
    else
        # Linux: md5sum
        printf '%s' "$input" | md5sum | awk '{print $1}'
    fi
}

# ============================================================================
# cocoapods_cdn_compute_shard <pod_name>
# Returns: "h0/h1/h2" where h0=md5[0], h1=md5[1], h2=md5[2] (lowercase hex)
# ============================================================================
cocoapods_cdn_compute_shard() {
    local pod_name="$1"
    if [[ -z "$pod_name" ]]; then
        echo "Error: pod_name is required" >&2
        return 1
    fi

    local hash
    hash=$(_cocoapods_cdn_md5 "$pod_name")

    local h0="${hash:0:1}"
    local h1="${hash:1:1}"
    local h2="${hash:2:1}"

    echo "${h0}/${h1}/${h2}"
}

# ============================================================================
# cocoapods_cdn_build_url <pod_name> <version>
# Returns: full CDN podspec URL
# ============================================================================
cocoapods_cdn_build_url() {
    local pod_name="$1"
    local version="$2"

    if [[ -z "$pod_name" || -z "$version" ]]; then
        echo "Error: pod_name and version are required" >&2
        return 1
    fi

    local shard
    shard=$(cocoapods_cdn_compute_shard "$pod_name")

    echo "https://cdn.cocoapods.org/Specs/${shard}/${pod_name}/${version}/${pod_name}.podspec.json"
}

# ============================================================================
# cocoapods_cdn_check_pod_available <pod_name> <version>
# Checks CDN with up to 3 retries (exponential backoff: 1s, 2s, 4s).
# Per-request timeout: 10s.
# Exit codes: 0=available, 2=not_yet, 3=unreachable, 1=bad_args
# ============================================================================
cocoapods_cdn_check_pod_available() {
    local pod_name="$1"
    local version="$2"

    if [[ -z "$pod_name" || -z "$version" ]]; then
        echo "[CDN_CHECK] Error: pod_name and version are required" >&2
        return 1
    fi

    local url
    url=$(cocoapods_cdn_build_url "$pod_name" "$version")

    local max_attempts=3
    local attempt=1
    local delay=1
    local http_code=""
    local last_err=""
    local latency_ms=0

    while [[ $attempt -le $max_attempts ]]; do
        local start_ms
        start_ms=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
            || date +%s 2>/dev/null || echo "0")

        # CDN_CURL_CMD override for test injection
        if [[ -n "${CDN_CURL_CMD:-}" ]]; then
            http_code=$(${CDN_CURL_CMD} 2>/dev/null) || {
                local curl_exit=$?
                http_code=""
                last_err="curl exit ${curl_exit}"
            }
        else
            http_code=$(curl --max-time 10 -L -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null) || {
                local curl_exit=$?
                http_code=""
                last_err="curl exit ${curl_exit}"
            }
        fi

        local end_ms
        end_ms=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
            || date +%s 2>/dev/null || echo "0")
        if [[ "$start_ms" != "0" && "$end_ms" != "0" ]]; then
            latency_ms=$(( end_ms - start_ms ))
        fi

        if [[ "$http_code" == "200" ]]; then
            cocoapods_cdn_emit_check_log \
                "$pod_name" "$version" "200" "$latency_ms" "$attempt" "$max_attempts" "$url"
            cocoapods_cdn_metrics_record "200" "$latency_ms"
            return 0
        elif [[ "$http_code" == "404" ]]; then
            cocoapods_cdn_emit_check_log \
                "$pod_name" "$version" "404" "$latency_ms" "$attempt" "$max_attempts" "$url"
            cocoapods_cdn_metrics_record "404" "$latency_ms"
            # 404 means not yet published — no retry needed
            return 2
        else
            # 5xx, empty (timeout/network error), or other
            local status_label="${http_code:-TIMEOUT}"
            [[ -z "$http_code" ]] && status_label="TIMEOUT"

            cocoapods_cdn_emit_check_log \
                "$pod_name" "$version" "$status_label" "$latency_ms" \
                "$attempt" "$max_attempts" "$url"

            if [[ $attempt -lt $max_attempts ]]; then
                sleep "$delay"
                delay=$(( delay * 2 ))
            fi
        fi

        attempt=$(( attempt + 1 ))
    done

    # All retries exhausted
    cocoapods_cdn_metrics_record "${http_code:-0}" "$latency_ms"
    cocoapods_cdn_emit_failure_block \
        "$pod_name" "$version" "$url" "${last_err:-HTTP ${http_code:-unknown}}" \
        "$latency_ms"
    return 3
}

# ============================================================================
# Metrics accumulators (in-memory, per-session)
# ============================================================================

# Initialize/reset metrics for the session
cocoapods_cdn_metrics_init() {
    _CDN_METRICS_TOTAL=0
    _CDN_METRICS_SUCCESS=0
    _CDN_METRICS_RETRY=0
    _CDN_METRICS_FAIL=0
    _CDN_METRICS_LATENCIES=()
    _CDN_METRICS_FIRST_AT=""
    _CDN_METRICS_LAST_AT=""
}

# Record one check result
# Args: <http_status> <latency_ms>
cocoapods_cdn_metrics_record() {
    local http_status="$1"
    local latency_ms="${2:-0}"

    # Initialize on first call if not done
    if [[ -z "${_CDN_METRICS_TOTAL+x}" ]]; then
        cocoapods_cdn_metrics_init
    fi

    _CDN_METRICS_TOTAL=$(( _CDN_METRICS_TOTAL + 1 ))

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    [[ -z "$_CDN_METRICS_FIRST_AT" ]] && _CDN_METRICS_FIRST_AT="$now"
    _CDN_METRICS_LAST_AT="$now"

    _CDN_METRICS_LATENCIES+=("$latency_ms")

    if [[ "$http_status" == "200" ]]; then
        _CDN_METRICS_SUCCESS=$(( _CDN_METRICS_SUCCESS + 1 ))
    elif [[ "$http_status" == "404" ]]; then
        # 404 = not-yet, counts as a check but not success or fail
        true
    else
        _CDN_METRICS_FAIL=$(( _CDN_METRICS_FAIL + 1 ))
        # Each non-200/non-404 response on a retry counts as a retry
        if [[ _CDN_METRICS_TOTAL -gt 1 ]]; then
            _CDN_METRICS_RETRY=$(( _CDN_METRICS_RETRY + 1 ))
        fi
    fi
}

# Compute p50 and p95 from latency array
_cocoapods_cdn_percentile() {
    local pct="$1"
    shift
    local -a sorted=("$@")
    local n=${#sorted[@]}

    if [[ $n -eq 0 ]]; then
        echo "0"
        return
    fi

    # Bubble sort (small N — typically < 100 per session)
    local i j tmp
    for (( i=0; i<n-1; i++ )); do
        for (( j=0; j<n-i-1; j++ )); do
            if [[ ${sorted[$j]} -gt ${sorted[$((j+1))]} ]]; then
                tmp=${sorted[$j]}
                sorted[$j]=${sorted[$((j+1))]}
                sorted[$((j+1))]=$tmp
            fi
        done
    done

    local idx
    idx=$(( (n * pct) / 100 ))
    [[ $idx -ge $n ]] && idx=$(( n - 1 ))
    echo "${sorted[$idx]}"
}

# Flush accumulated metrics to state file via msp_state_set_cdn_metrics
cocoapods_cdn_metrics_flush_to_state() {
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    if ! command -v msp_state_set_cdn_metrics >/dev/null 2>&1; then
        # state.sh not sourced — skip silently
        return 0
    fi

    local total="${_CDN_METRICS_TOTAL:-0}"
    local success="${_CDN_METRICS_SUCCESS:-0}"
    local retry="${_CDN_METRICS_RETRY:-0}"
    local fail="${_CDN_METRICS_FAIL:-0}"
    local first_at="${_CDN_METRICS_FIRST_AT:-null}"
    local last_at="${_CDN_METRICS_LAST_AT:-null}"

    local p50=0
    local p95=0
    if [[ ${#_CDN_METRICS_LATENCIES[@]} -gt 0 ]]; then
        p50=$(_cocoapods_cdn_percentile 50 "${_CDN_METRICS_LATENCIES[@]}")
        p95=$(_cocoapods_cdn_percentile 95 "${_CDN_METRICS_LATENCIES[@]}")
    fi

    # Build JSON for first_at/last_at (null vs quoted string)
    local first_json="null"
    local last_json="null"
    [[ -n "$first_at" ]] && first_json="\"${first_at}\""
    [[ -n "$last_at" ]] && last_json="\"${last_at}\""

    local metrics_json
    metrics_json=$(printf \
        '{"total_checks":%d,"success_count":%d,"retry_count":%d,"failure_count":%d,"p50_latency_ms":%d,"p95_latency_ms":%d,"first_check_at":%s,"last_check_at":%s}' \
        "$total" "$success" "$retry" "$fail" "$p50" "$p95" "$first_json" "$last_json")

    msp_state_set_cdn_metrics "$metrics_json" 2>/dev/null || true
}

# ============================================================================
# Logging helpers
# ============================================================================

# Emit a structured [CDN_CHECK] log line
# Args: pod version status latency_ms attempt max_attempts url
cocoapods_cdn_emit_check_log() {
    local pod="$1"
    local version="$2"
    local status="$3"
    local latency_ms="$4"
    local attempt="$5"
    local max_attempts="$6"
    local url="$7"

    echo "[CDN_CHECK] pod=${pod} version=${version} status=${status} latency_ms=${latency_ms} attempt=${attempt}/${max_attempts} url=${url}" >&2
}

# Emit the human-readable triage block on CDN unreachable
# Args: pod version url last_err total_ms
cocoapods_cdn_emit_failure_block() {
    local pod="$1"
    local version="$2"
    local url="$3"
    local last_err="$4"
    local total_ms="${5:-0}"
    local total_s
    total_s=$(awk "BEGIN{printf \"%.1f\", ${total_ms}/1000}" 2>/dev/null || echo "${total_ms}ms")

    cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ CDN UNREACHABLE AFTER 3 RETRIES
   Pod:       ${pod} ${version}
   URL:       ${url}
   Last err:  ${last_err}
   Total:     ${total_s}s
   Action:    Check https://status.cocoapods.org, then retry release
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# ============================================================================
# Exports
# ============================================================================
export -f cocoapods_cdn_compute_shard
export -f cocoapods_cdn_build_url
export -f cocoapods_cdn_check_pod_available
export -f cocoapods_cdn_metrics_init
export -f cocoapods_cdn_metrics_record
export -f cocoapods_cdn_metrics_flush_to_state
export -f cocoapods_cdn_emit_check_log
export -f cocoapods_cdn_emit_failure_block
