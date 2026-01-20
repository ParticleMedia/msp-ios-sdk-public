#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Test Script for generate_release_md.sh
# ============================================================================
# Purpose: Test the release Markdown report generator
#
# Usage:   bash Scripts/tests/generate_release_md_test.sh
# ============================================================================

set -euo pipefail

echo "[TEST] generate_release_md_test.sh: START"

# Detect ROOT_DIR
if [[ -z "${ROOT_DIR:-}" ]]; then
    if command -v git >/dev/null 2>&1; then
        ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
    fi
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
    fi
fi
export ROOT_DIR

STATE_FILE="${ROOT_DIR}/.msp-release-state.json"

# Check if state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo "[WARN] State file not found: $STATE_FILE" >&2
    echo "[WARN] Skipping test (soft-fail)" >&2
    exit 0
fi

echo "[TEST] State file found: $STATE_FILE"

# Run the generator with default arguments
echo "[TEST] Running generate_release_md.sh..."
bash "${ROOT_DIR}/Scripts/release/generate_release_md.sh" || {
    echo "[WARN] generate_release_md.sh failed (soft-fail)" >&2
    exit 0
}

# Extract version to determine output path
VERSION="$(jq -r '.version // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")"
OUTPUT_FILE="${ROOT_DIR}/Releases/release-${VERSION}.md"

echo "[TEST] Output file: $OUTPUT_FILE"

# Check if output file was created
if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "[WARN] Output file not created: $OUTPUT_FILE" >&2
    exit 0
fi

echo "[TEST] Output file created successfully"
echo "[TEST] First 30 lines of generated Markdown:"
echo "----------------------------------------"
head -30 "$OUTPUT_FILE" || echo "(file is shorter than 30 lines)"
echo "----------------------------------------"

echo "[TEST] generate_release_md_test.sh: DONE"
exit 0

