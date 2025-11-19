#!/usr/bin/env bash
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
    echo "Usage: $0 [spm|pods]"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    log_error "Invalid target. Must be 'spm' or 'pods'"
    exit 1
fi

printf "============================================================================\n"
printf "Environment Validation: %s\n" "$TARGET"
printf "============================================================================\n"
printf "\n"

ERRORS=0

# Use common validation function
if validate_environment "$TARGET"; then
    ERRORS=0
else
    ERRORS=$?
fi

printf "\n"
printf "============================================================================\n"
if [[ $ERRORS -eq 0 ]]; then
    log_success "Environment validation PASSED"
    exit 0
else
    log_error "Environment validation FAILED ($ERRORS error(s))"
    exit 1
fi

