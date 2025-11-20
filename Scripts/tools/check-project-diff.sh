#!/usr/bin/env bash
# Check if generated Xcode project files have changed
# This script provides informational awareness about project file changes
# Usage: Scripts/tools/check-project-diff.sh

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

# Initialize paths
init_paths

# Check for changed Xcode project files
CHANGED_FILES=()
while IFS= read -r file; do
    if [[ -n "$file" ]]; then
        CHANGED_FILES+=("$file")
    fi
done < <(git diff --name-only | grep -E "(\.pbxproj$|\.xcscheme$|\.xcworkspace$)" || true)

if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    log_info "Xcode project files changed. This is expected after regeneration."
    log_info ""
    log_info "Changed files:"
    for file in "${CHANGED_FILES[@]}"; do
        log_info "  • $file"
    done
    log_info ""
    log_info "These files are auto-generated and nondeterministic."
    log_info "YAML files (project.yml, workspace.yml) are the source of truth."
else
    # Silent success - no changes detected
    :
fi

# Always exit 0 (informational only)
exit 0

