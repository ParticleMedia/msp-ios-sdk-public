#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Environment Validation
# ============================================================================
# Purpose: Validate the environment matches the selected target
#
# Safety: Read-only validation. Never modifies files.
#
# Usage:   ./Scripts/target-switching/validate_environment.sh [spm|pods]
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    log_error "Usage: $0 [spm|pods]"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    log_error "Invalid target. Must be 'spm' or 'pods'"
    exit 1
fi

log_title "Environment Validation: $TARGET"

ERRORS=0

# Use common validation function
if validate_environment "$TARGET"; then
    ERRORS=0
else
    ERRORS=$?
fi

log_title "Validation Complete"

if [[ $ERRORS -eq 0 ]]; then
    log_success "Environment validation PASSED"
    exit 0
else
    log_error "Environment validation FAILED ($ERRORS error(s))"
    exit 1
fi
