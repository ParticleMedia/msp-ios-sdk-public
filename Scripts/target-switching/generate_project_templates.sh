#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Generate project.yml files from templates
# ============================================================================
# Purpose: Copy all project.yml.template files to project.yml
#          This ensures that tracked templates are the source of truth.
#
# Usage:   ./Scripts/target-switching/generate_project_templates.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/common.sh"

# Ensure logger functions are available in subprocess
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    unset MSP_LOGGER_LOADED
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

ensure_repo_root

log_section "Generating project.yml files from templates"

GENERATED_COUNT=0
FAILED_COUNT=0

# Task 2: Ensure we only generate project.yml from templates
# Never commit project.yml to Git - they are build artifacts
# Find all project.yml.template files
while IFS= read -r template; do
    [[ -z "$template" ]] && continue
    
    output="${template%.template}"
    template_rel="${template#$ROOT_DIR/}"
    output_rel="${output#$ROOT_DIR/}"
    
    # Simple copy (templates are ready to use as-is)
    # In the future, can add variable substitution if needed
    if cp "$template" "$output" 2>/dev/null; then
        log::info "TARGET" "  ✓ Generated $output_rel"
        ((GENERATED_COUNT++)) || true
    else
        log::warn "TARGET" "  ✗ Failed to generate $output_rel"
        ((FAILED_COUNT++)) || true
    fi
done < <(find "$ROOT_DIR" -name "project.yml.template" \
    ! -path "*/Pods/*" \
    ! -path "*/.generated/*" \
    ! -path "*/DerivedData/*" \
    ! -path "*/.build/*" \
    -print 2>/dev/null | LC_ALL=C sort || true)

if [[ $GENERATED_COUNT -gt 0 ]]; then
    log::success "TARGET" "Generated $GENERATED_COUNT project.yml file(s) from templates"
fi

if [[ $FAILED_COUNT -gt 0 ]]; then
    log::warn "TARGET" "Failed to generate $FAILED_COUNT project.yml file(s)"
    exit 1
fi

if [[ $GENERATED_COUNT -eq 0 ]]; then
    log::warn "TARGET" "No project.yml.template files found!"
fi

exit 0

