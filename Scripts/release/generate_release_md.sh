#!/usr/bin/env bash
# ============================================================================
# MSP Release Markdown Report Generator
# ============================================================================
# Purpose: Generate human-readable Markdown report from .msp-release-state.json
#
# Usage:
#   bash Scripts/release/generate_release_md.sh [--state-file <path>] [--output <path>]
#
# Options:
#   --state-file <path>   Path to state file (default: .msp-release-state.json in repo root)
#   --output <path>       Path to output Markdown file (default: Releases/release-<version>.md)
# ============================================================================

set -euo pipefail

# ============================================================================
# Dependencies Check
# ============================================================================

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed." >&2
    echo "Please install jq: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    exit 1
fi

# ============================================================================
# CLI Argument Parsing
# ============================================================================

STATE_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --state-file)
            STATE_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--state-file <path>] [--output <path>]" >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# ROOT_DIR Detection
# ============================================================================

if [[ -z "${ROOT_DIR:-}" ]]; then
    if command -v git >/dev/null 2>&1; then
        ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
    fi
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$(dirname "$SCRIPT_DIR")"
    fi
fi
export ROOT_DIR

# ============================================================================
# Resolve State File Path
# ============================================================================

if [[ -z "$STATE_FILE" ]]; then
    STATE_FILE="${ROOT_DIR}/.msp-release-state.json"
else
    # Convert to absolute path if relative
    if [[ ! "$STATE_FILE" =~ ^/ ]]; then
        STATE_FILE="$(cd "$(dirname "$STATE_FILE")" && pwd)/$(basename "$STATE_FILE")"
    fi
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    exit 1
fi

# ============================================================================
# Extract Data from State JSON
# ============================================================================

# Version
VERSION="$(jq -r '.version // .release.version // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"

# Status / Overall Success
OVERALL_SUCCESS="$(jq -r '.overall_success // (.steps.run.status // "unknown")' "$STATE_FILE" 2>/dev/null || echo "unknown")"
if [[ "$OVERALL_SUCCESS" == "success" ]]; then
    STATUS="SUCCESS"
elif [[ "$OVERALL_SUCCESS" == "failed" ]]; then
    STATUS="FAILED"
elif [[ "$OVERALL_SUCCESS" == "running" ]]; then
    STATUS="IN_PROGRESS"
else
    # Try to derive from steps
    RUN_STATUS="$(jq -r '.steps.run.status // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"
    if [[ "$RUN_STATUS" == "success" ]]; then
        STATUS="SUCCESS"
    elif [[ "$RUN_STATUS" == "failed" ]]; then
        STATUS="FAILED"
    else
        STATUS="PARTIAL"
    fi
fi

# Author (try multiple paths)
AUTHOR="$(jq -r '.author.email // .author.name // .author // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"

# Source time utilities
if [[ -f "${ROOT_DIR}/Scripts/lib/time-utils.sh" ]]; then
    source "${ROOT_DIR}/Scripts/lib/time-utils.sh" 2>/dev/null || true
fi

# Timing
DURATION_HUMAN="$(jq -r '.timing.duration_human // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"

# Format timestamps (convert ISO8601 to human-readable)
STARTED_AT_RAW="$(jq -r '.timestamps.started_at // .timing.started_at // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"
if command -v format_timestamp_human >/dev/null 2>&1; then
    STARTED_AT="$(format_timestamp_human "$STARTED_AT_RAW")"
else
    # Fallback if time-utils.sh is not available
    STARTED_AT="$STARTED_AT_RAW"
fi

FINISHED_AT_RAW="$(jq -r '.timestamps.updated_at // .timing.finished_at // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"
if command -v format_timestamp_human >/dev/null 2>&1; then
    FINISHED_AT="$(format_timestamp_human "$FINISHED_AT_RAW")"
else
    # Fallback if time-utils.sh is not available
    FINISHED_AT="$FINISHED_AT_RAW"
fi

# Git Info
BASE_BRANCH="$(jq -r '.base_branch // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"
RELEASE_BRANCH="$(jq -r '.release_branch // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"

# Release Notes
RELEASE_NOTES="$(jq -r '.release_notes // .notes // ""' "$STATE_FILE" 2>/dev/null || echo "")"
if [[ -z "$RELEASE_NOTES" ]] || [[ "$RELEASE_NOTES" == "null" ]]; then
    RELEASE_NOTES="N/A"
fi

# ============================================================================
# Extract Modules (CocoaPods)
# ============================================================================

PODS_MODULES=""
PODS_DATA="$(jq -r '.modules // .pods.modules // .pods_results // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
if [[ "$PODS_DATA" != "{}" ]] && [[ "$PODS_DATA" != "null" ]]; then
    # Try to extract module list
    PODS_MODULES="$(echo "$PODS_DATA" | jq -r 'to_entries[] | "\(.key) \(.value.version // .value // "'"$VERSION"'")"' 2>/dev/null || echo "")"
    if [[ -z "$PODS_MODULES" ]]; then
        # Try alternative structure
        PODS_MODULES="$(echo "$PODS_DATA" | jq -r 'keys[] as $k | "\($k) \(.[$k])"' 2>/dev/null || echo "")"
    fi
fi

if [[ -z "$PODS_MODULES" ]]; then
    PODS_MODULES="N/A"
fi

# ============================================================================
# Extract Modules (SPM)
# ============================================================================

SPM_MODULES=""
SPM_DATA="$(jq -r '.spm.modules // .spm_results // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
if [[ "$SPM_DATA" != "{}" ]] && [[ "$SPM_DATA" != "null" ]]; then
    SPM_MODULES="$(echo "$SPM_DATA" | jq -r 'to_entries[] | "\(.key) \(.value.version // .value // "'"$VERSION"'")"' 2>/dev/null || echo "")"
    if [[ -z "$SPM_MODULES" ]]; then
        SPM_MODULES="$(echo "$SPM_DATA" | jq -r 'keys[] as $k | "\($k) \(.[$k])"' 2>/dev/null || echo "")"
    fi
fi

if [[ -z "$SPM_MODULES" ]]; then
    SPM_MODULES="N/A"
fi

# ============================================================================
# Extract Verification Results
# ============================================================================

# Remote SPM
REMOTE_SPM_STATUS="N/A"
REMOTE_SPM_DATA="$(jq -r '.remote_verify.spm // .verification.remote.spm // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
if [[ "$REMOTE_SPM_DATA" != "{}" ]] && [[ "$REMOTE_SPM_DATA" != "null" ]]; then
    REMOTE_SPM_EXECUTED="$(echo "$REMOTE_SPM_DATA" | jq -r '.executed // false' 2>/dev/null || echo "false")"
    if [[ "$REMOTE_SPM_EXECUTED" == "true" ]]; then
        REMOTE_SPM_SUCCESS="$(echo "$REMOTE_SPM_DATA" | jq -r '.success // false' 2>/dev/null || echo "false")"
        if [[ "$REMOTE_SPM_SUCCESS" == "true" ]]; then
            REMOTE_SPM_STATUS="PASS"
        else
            REMOTE_SPM_STATUS="FAIL"
        fi
    else
        REMOTE_SPM_STATUS="SKIPPED"
    fi
fi

# Remote Pods
REMOTE_PODS_STATUS="N/A"
REMOTE_PODS_DATA="$(jq -r '.remote_verify.pods // .verification.remote.pods // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
if [[ "$REMOTE_PODS_DATA" != "{}" ]] && [[ "$REMOTE_PODS_DATA" != "null" ]]; then
    REMOTE_PODS_EXECUTED="$(echo "$REMOTE_PODS_DATA" | jq -r '.executed // false' 2>/dev/null || echo "false")"
    if [[ "$REMOTE_PODS_EXECUTED" == "true" ]]; then
        REMOTE_PODS_SUCCESS="$(echo "$REMOTE_PODS_DATA" | jq -r '.success // false' 2>/dev/null || echo "false")"
        if [[ "$REMOTE_PODS_SUCCESS" == "true" ]]; then
            REMOTE_PODS_STATUS="PASS"
        else
            REMOTE_PODS_STATUS="FAIL"
        fi
    else
        REMOTE_PODS_STATUS="SKIPPED"
    fi
fi

# Local Verification
LOCAL_VERIFY_STATUS="N/A"
LOCAL_VERIFY_DATA="$(jq -r '.local_verify // .verification.local // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
if [[ "$LOCAL_VERIFY_DATA" != "{}" ]] && [[ "$LOCAL_VERIFY_DATA" != "null" ]]; then
    LOCAL_EXECUTED="$(echo "$LOCAL_VERIFY_DATA" | jq -r '.executed // false' 2>/dev/null || echo "false")"
    if [[ "$LOCAL_EXECUTED" == "true" ]]; then
        LOCAL_SUCCESS="$(echo "$LOCAL_VERIFY_DATA" | jq -r '.success // false' 2>/dev/null || echo "false")"
        LOCAL_MODE="$(echo "$LOCAL_VERIFY_DATA" | jq -r '.mode // "unknown"' 2>/dev/null || echo "unknown")"
        if [[ "$LOCAL_SUCCESS" == "true" ]]; then
            LOCAL_VERIFY_STATUS="PASS ($LOCAL_MODE)"
        else
            LOCAL_VERIFY_STATUS="FAIL ($LOCAL_MODE)"
        fi
    else
        LOCAL_VERIFY_STATUS="SKIPPED"
    fi
fi

# Device Verification
DEVICE_VERIFY_STATUS="N/A"
DEVICE_VERIFY_DATA="$(jq -r '.device_verify // .verification.device // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
if [[ "$DEVICE_VERIFY_DATA" != "{}" ]] && [[ "$DEVICE_VERIFY_DATA" != "null" ]]; then
    DEVICE_EXECUTED="$(echo "$DEVICE_VERIFY_DATA" | jq -r '.executed // false' 2>/dev/null || echo "false")"
    if [[ "$DEVICE_EXECUTED" == "true" ]]; then
        DEVICE_SUCCESS="$(echo "$DEVICE_VERIFY_DATA" | jq -r '.success // false' 2>/dev/null || echo "false")"
        DEVICE_MODE="$(echo "$DEVICE_VERIFY_DATA" | jq -r '.mode // "unknown"' 2>/dev/null || echo "unknown")"
        if [[ "$DEVICE_SUCCESS" == "true" ]]; then
            DEVICE_VERIFY_STATUS="PASS ($DEVICE_MODE)"
        else
            DEVICE_VERIFY_STATUS="FAIL ($DEVICE_MODE)"
        fi
    else
        DEVICE_VERIFY_STATUS="SKIPPED"
    fi
fi

# XCFramework Verification
XCF_VERIFY_DATA="$(jq -r '.xcframework_verify // .verification.xcframework // {}' "$STATE_FILE" 2>/dev/null || echo "{}")"
XCF_MODULES_LIST=""
if [[ "$XCF_VERIFY_DATA" != "{}" ]] && [[ "$XCF_VERIFY_DATA" != "null" ]]; then
    XCF_MODULES="$(echo "$XCF_VERIFY_DATA" | jq -r '.modules // {}' 2>/dev/null || echo "{}")"
    if [[ "$XCF_MODULES" != "{}" ]] && [[ "$XCF_MODULES" != "null" ]]; then
        XCF_MODULES_LIST="$(echo "$XCF_MODULES" | jq -r 'to_entries[] | "\(.key): \(if .value.success == true then "PASS" else "FAIL" end) (\(.value.warnings // 0) warnings)"' 2>/dev/null || echo "")"
    fi
fi

if [[ -z "$XCF_MODULES_LIST" ]]; then
    XCF_MODULES_LIST="N/A"
fi

# ============================================================================
# Resolve Output File Path
# ============================================================================

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_DIR="${ROOT_DIR}/Releases"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="${OUTPUT_DIR}/release-${VERSION}.md"
else
    # Ensure output directory exists
    OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
    mkdir -p "$OUTPUT_DIR"
    # Convert to absolute path if relative
    if [[ ! "$OUTPUT_FILE" =~ ^/ ]]; then
        OUTPUT_FILE="$(cd "$OUTPUT_DIR" && pwd)/$(basename "$OUTPUT_FILE")"
    fi
fi

# ============================================================================
# Generate Markdown Report
# ============================================================================

cat > "$OUTPUT_FILE" <<EOF
# MSP iOS SDK Release ${VERSION}

## Overview

- **Status:** ${STATUS}
- **Author:** ${AUTHOR}
- **Duration:** ${DURATION_HUMAN}
- **Started:** ${STARTED_AT}
- **Finished:** ${FINISHED_AT}
- **Base Branch:** ${BASE_BRANCH}
- **Release Branch:** ${RELEASE_BRANCH}

## Modules Released (CocoaPods)

$(if [[ "$PODS_MODULES" != "N/A" ]] && [[ -n "$PODS_MODULES" ]]; then
    echo "$PODS_MODULES" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo "- ${line} — PASS"
        fi
    done
else
    echo "N/A"
fi)

## Modules Released (SPM)

$(if [[ "$SPM_MODULES" != "N/A" ]] && [[ -n "$SPM_MODULES" ]]; then
    echo "$SPM_MODULES" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo "- ${line} — PASS"
        fi
    done
else
    echo "N/A"
fi)

## Verification Summary

- **Remote SPM:** ${REMOTE_SPM_STATUS}
- **Remote Pods:** ${REMOTE_PODS_STATUS}
- **Local (pods/spm):** ${LOCAL_VERIFY_STATUS}
- **Device:** ${DEVICE_VERIFY_STATUS}
$(if [[ "$XCF_MODULES_LIST" != "N/A" ]]; then
    echo "$XCF_MODULES_LIST" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo "- **XCFramework ${line}**"
        fi
    done
else
    echo "- **XCFramework:** N/A"
fi)

## Release Notes

${RELEASE_NOTES}

## State & Artifacts

- **State file:** ${STATE_FILE}
- **XCFramework dir:** Build/XCFrameworks (if available)
EOF

echo "Release report generated: $OUTPUT_FILE"
exit 0

