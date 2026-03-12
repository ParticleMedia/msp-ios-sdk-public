#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

ensure_repo_root

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    log::error "TARGET" "Usage: $0 [spm|pods]"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    log::error "TARGET" "Invalid target. Must be 'spm' or 'pods'"
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
    log::success "TARGET" "Environment validation PASSED"
    exit 0
else
    log::error "TARGET" "Environment validation FAILED ($ERRORS error(s))"
    exit 1
fi
