#!/usr/bin/env bash
# Check if generated Xcode project files have changed
# This script warns developers if .pbxproj or .xcscheme files were modified
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

# Patterns to check for generated Xcode files
CHECK_PATTERNS=(
    "MSPDemoApp/**/*.pbxproj"
    "MSPDemoApp/**/*.xcscheme"
)

# Check if any generated files have changed
CHANGED_FILES=()
for pattern in "${CHECK_PATTERNS[@]}"; do
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            CHANGED_FILES+=("$file")
        fi
    done < <(git diff --name-only | grep -E "$pattern" || true)
done

if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    echo ""
    log_warn "Generated Xcode files have changed"
    echo ""
    log_info "The following generated files were modified:"
    echo ""
    for file in "${CHANGED_FILES[@]}"; do
        echo -e "  ${YELLOW}⚠${NC}  $file"
    done
    echo ""
    log_warn "These files should NOT be committed!"
    echo ""
    log_info "These files are generated from YAML specs. If you need to update them:"
    echo ""
    log_info "  1. Run: ${CYAN}xcodegen generate --spec MSPDemoApp/project.yml${NC}"
    echo ""
    log_info "  2. Review the changes to ensure they're expected"
    echo ""
    log_info "  3. If changes are unexpected, revert them:"
    echo ""
    for file in "${CHANGED_FILES[@]}"; do
        echo -e "     ${CYAN}git restore $file${NC}"
    done
    echo ""
    log_info "  4. Only commit source files (project.yml, workspace.yml, .swift, etc.)"
    echo ""
    log_warn "The pre-commit hook will block committing these files."
    echo ""
else
    # Silent success - no need to spam output if everything is fine
    exit 0
fi

# Exit with 0 (non-blocking warning)
exit 0

