#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ========================================
# Unified ROOT_DIR resolution (final)
# ========================================
# The root dir is always the directory that contains
# the parent Scripts/ folder where msp-release.sh lives.
if [[ -z "${ROOT_DIR:-}" ]]; then
    # Find Scripts/ directory by going up until we find it, then go up one more level
    ROOT_DIR="$SCRIPT_DIR"
    while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    done
    # If we found Scripts/, go up one more level to get repo root
    if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
        ROOT_DIR="$(dirname "$ROOT_DIR")"
    fi
fi
export ROOT_DIR

CASES_DIR="$SCRIPT_DIR/cases"

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_ROOT="$ROOT_DIR/verification_matrix/run-$TIMESTAMP"
LOGS_DIR="$OUTPUT_ROOT"
SUMMARY_JSON="$OUTPUT_ROOT/summary.json"

mkdir -p "$OUTPUT_ROOT"

source "$ROOT_DIR/Scripts/lib/colors.sh"
source "$ROOT_DIR/Scripts/lib/ui.sh"
source "$ROOT_DIR/Scripts/lib/logging.sh"

# Load release state utilities
source "$SCRIPT_DIR/../utils/state.sh"

# Initialize state for verify-matrix
msp_state_init "verify_matrix"

# Check if we should skip this step in resume mode
if [[ "${MSP_RESUME_MODE:-0}" == "1" ]]; then
    local status
    status="$(msp_state_get_step_status "verify_matrix" 2>/dev/null || echo "unknown")"
    if [[ "$status" == "success" || "$status" == "skipped" ]]; then
        log_info "Resuming: skipping verify_matrix (status already ${status})"
        exit 0
    fi
fi

msp_state_mark_step_running "verify_matrix"

log_section "MSP Release Verification Matrix"
log_info "Executing all test cases from: $CASES_DIR"

declare -A RESULTS
declare -A EXIT_CODES

for case_file in "$CASES_DIR"/*.sh; do
    case_name="$(basename "$case_file" .sh)"

    log_section "Running case: $case_name"

    case_output_dir="$OUTPUT_ROOT/case-${case_name}"
    mkdir -p "$case_output_dir"
    log_file="$case_output_dir/output.log"

    if bash "$case_file" >"$log_file" 2>&1; then
        exit_code=0
        RESULTS["$case_name"]="success"
        log_success "Case $case_name: PASSED"
    else
        exit_code=$?
        RESULTS["$case_name"]="failed"
        EXIT_CODES["$case_name"]=$exit_code
        log_error "Case $case_name: FAILED (exit code: $exit_code)"
    fi
done

log_section "Summary"

# Generate summary.json
cat > "$SUMMARY_JSON" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "cases": {
EOF

first=1
for case_name in "${!RESULTS[@]}"; do
    if [[ $first -eq 0 ]]; then
        echo "," >> "$SUMMARY_JSON"
    fi
    exit_code="${EXIT_CODES[$case_name]:-0}"
    echo -n "    \"$case_name\": { \"status\": \"${RESULTS[$case_name]}\", \"exit_code\": $exit_code }" >> "$SUMMARY_JSON"
    first=0
done

cat >> "$SUMMARY_JSON" <<EOF

  }
}
EOF

log_info "Summary written to: $SUMMARY_JSON"
log_info "All case logs available in: $OUTPUT_ROOT"

# Check if any strict-mode case failed
matrix_failed=0
for case_name in "${!RESULTS[@]}"; do
    if [[ "${RESULTS[$case_name]}" == "failed" ]]; then
        matrix_failed=1
        break
    fi
done

if [[ $matrix_failed -eq 1 ]]; then
    log_error "Verification matrix completed with failures"
    msp_state_mark_step_failed "verify_matrix" "verification matrix completed with failures" "1"
    exit 1
fi

log_success "Verification matrix completed successfully"
msp_state_mark_step_success "verify_matrix"
exit 0

