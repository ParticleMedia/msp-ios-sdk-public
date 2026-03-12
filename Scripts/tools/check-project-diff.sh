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
# Check if generated Xcode project files have changed
# This script provides informational awareness about project file changes
# Usage: Scripts/tools/check-project-diff.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

init_paths

CHANGED_FILES=()
while IFS= read -r file; do
    if [[ -n "$file" ]]; then
        CHANGED_FILES+=("$file")
    fi
done < <(git diff --name-only | grep -E "(\.pbxproj$|\.xcscheme$|\.xcworkspace$)" || true)

if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    log::info "TOOLS" "Xcode project files changed. This is expected after regeneration."
    log::info "TOOLS" ""
    log::info "TOOLS" "Changed files:"
    for file in "${CHANGED_FILES[@]}"; do
        log::info "TOOLS" "  • $file"
    done
    log::info "TOOLS" ""
    log::info "TOOLS" "These files are auto-generated and nondeterministic."
    log::info "TOOLS" "YAML files (project.yml, workspace.yml) are the source of truth."
else
    # Silent success - no changes detected
    :
fi

# Always exit 0 (informational only)
exit 0

