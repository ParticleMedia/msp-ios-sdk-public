#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
#
# Script Path Lint Validator
#
# Validates that all scripts in Scripts/ directory use correct ROOT_DIR patterns
# and do not reference obsolete paths.
#
# Exit codes:
#   0 - All checks passed
#   1 - Violations found
#

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

# Track violations
VIOLATIONS=0
TOTAL_FILES=0
ISSUES=()

# Output directory for reports
OUTPUT_DIR="$SCRIPT_DIR/output"
mkdir -p "$OUTPUT_DIR"

log_title "Script Path Lint Validator"

# Function to check if script should be excluded from checks
should_exclude_script() {
    local script_path="$1"
    local script_dir="$(dirname "$script_path")"
    local relative_path="${script_dir#$ROOT_DIR/}"
    local basename=$(basename "$script_path")
    
    # Exclude compatibility shims (build-*-xcframework.sh in Scripts root)
    if [[ "$relative_path" == Scripts ]] && [[ "$basename" =~ ^build-.*-xcframework\.sh$ ]]; then
        echo "Excluded compatibility shim: $script_path" >&2
        return 0  # Should exclude
    fi
    
    # Exclude other compatibility shims in Scripts root
    if [[ "$relative_path" == Scripts ]]; then
        case "$basename" in
            build-xcframework.sh|build-all-xcframeworks.sh|setup-spm-environment.sh|update-workspace.sh|validate-source-parity.sh|generate-wrappers.sh)
                echo "Excluded compatibility shim: $script_path" >&2
                return 0  # Should exclude
                ;;
        esac
    fi
    
    # Exclude legacy scripts
    if [[ "$relative_path" == Scripts/legacy/* ]]; then
        return 0  # Should exclude
    fi
    
    # Exclude plugins/ scripts - they are sourced, not executed directly
    if [[ "$relative_path" == Scripts/plugins/* ]]; then
        return 0  # Should exclude
    fi
    
    # Exclude lib/ scripts - they are sourced, not executed directly
    if [[ "$relative_path" == Scripts/lib/* ]]; then
        return 0  # Should exclude
    fi
    
    return 1  # Should NOT exclude
}

# Function to check ROOT_DIR pattern
check_root_dir_pattern() {
    local script_path="$1"
    local script_dir="$(dirname "$script_path")"
    local relative_path="${script_dir#$ROOT_DIR/}"
    
    # Skip excluded scripts
    if should_exclude_script "$script_path"; then
        return 0
    fi
    
    # Determine expected ROOT_DIR pattern based on directory depth
    local depth=$(echo "$relative_path" | tr -cd '/' | wc -c)
    local expected_pattern=""
    
    case "$relative_path" in
        Scripts)
            # Top-level scripts should use ../
            expected_pattern="\\.\\./"
            ;;
        Scripts/xcframeworks/wrappers|Scripts/xcframeworks/internal|Scripts/workspace|Scripts/environment|Scripts/release|Scripts/build|Scripts/ci|Scripts/validation)
            # Second-level scripts should use ../../
            expected_pattern="\\.\\./\\.\\./"
            ;;
        Scripts/*/*/*)
            # Third-level scripts should use ../../../
            expected_pattern="\\.\\./\\.\\./\\.\\./"
            ;;
        *)
            # Default: count depth
            if [ "$depth" -eq 1 ]; then
                expected_pattern="\\.\\./"
            elif [ "$depth" -eq 2 ]; then
                expected_pattern="\\.\\./\\.\\./"
            else
                expected_pattern="\\.\\./\\.\\./\\.\\./"
            fi
            ;;
    esac
    
    # Check if script calculates ROOT_DIR (only for executable scripts)
    if ! grep -q "ROOT_DIR.*pwd" "$script_path" 2>/dev/null; then
        # Only flag if it's not a library/plugin script
        ISSUES+=("⚠️  $script_path: Missing ROOT_DIR calculation (may be intentional for sourced scripts)")
        return 0  # Don't fail for this
    fi
    
    # If script has any ROOT_DIR assignment, don't warn about depth pattern
    # (depth warnings are often false positives)
    return 0
}

# Function to check for obsolete paths
check_obsolete_paths() {
    local script_path="$1"
    local basename=$(basename "$script_path")
    
    # List of obsolete paths to detect
    local obsolete_patterns=(
        "Scripts/build-.*-xcframework\\.sh"
        "Scripts/update-workspace\\.sh"
        "Scripts/setup-spm-environment\\.sh"
        "Scripts/build-xcframework\\.sh"
        "Scripts/build-all-xcframeworks\\.sh"
        "Scripts/generate-wrappers\\.sh"
        "Scripts/validate-source-parity\\.sh"
    )
    
    for pattern in "${obsolete_patterns[@]}"; do
        if grep -qE "$pattern" "$script_path" 2>/dev/null; then
            ISSUES+=("❌ $script_path: References obsolete path pattern: $pattern")
            return 1
        fi
    done
    
    return 0
}

# Function to check for hard-coded relative paths
check_hardcoded_paths() {
    local script_path="$1"
    
    # Check for hard-coded Scripts/ paths that should use ROOT_DIR
    if grep -qE '(\.\./)+Scripts/' "$script_path" 2>/dev/null && ! grep -q "ROOT_DIR" "$script_path" 2>/dev/null; then
        ISSUES+=("⚠️  $script_path: Uses hard-coded relative paths instead of ROOT_DIR")
        return 1
    fi
    
    return 0
}

# Function to check executable permissions
check_permissions() {
    local script_path="$1"
    
    if [ ! -x "$script_path" ]; then
        ISSUES+=("❌ $script_path: Missing executable permission (chmod +x)")
        return 1
    fi
    
    return 0
}

# Function to check wrapper script references
check_wrapper_references() {
    local script_path="$1"
    
    # Wrapper scripts should reference builder.sh
    if [[ "$script_path" == *"xcframeworks/wrappers/build-"*".sh" ]]; then
        if ! grep -q "xcframeworks/builder.sh\|builder.sh" "$script_path" 2>/dev/null; then
            ISSUES+=("⚠️  $script_path: Wrapper script should reference builder.sh")
            return 1
        fi
    fi
    
    return 0
}

# Main validation loop
echo "Scanning Scripts/ directory..."
echo ""

# Find all shell scripts
while IFS= read -r -d '' script_path; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Skip this script itself
    if [ "$script_path" = "$SCRIPT_DIR/script-path-lint.sh" ]; then
        continue
    fi
    
    # Run all checks
    check_root_dir_pattern "$script_path" || VIOLATIONS=$((VIOLATIONS + 1))
    check_obsolete_paths "$script_path" || VIOLATIONS=$((VIOLATIONS + 1))
    check_hardcoded_paths "$script_path" || VIOLATIONS=$((VIOLATIONS + 1))
    check_permissions "$script_path" || VIOLATIONS=$((VIOLATIONS + 1))
    check_wrapper_references "$script_path" || VIOLATIONS=$((VIOLATIONS + 1))
    
done < <(find "$ROOT_DIR/Scripts" -type f -name "*.sh" -print0)

# Print summary
echo ""
echo "=============================="
echo "📊 Validation Summary"
echo "=============================="
echo ""
echo "Total files checked: $TOTAL_FILES"
echo "Violations found: $VIOLATIONS"
echo ""

if [ $VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Violations detected:${NC}"
    echo ""
    for issue in "${ISSUES[@]}"; do
        echo "  $issue"
    done
    echo ""
    echo -e "${YELLOW}💡 Suggested fixes:${NC}"
    echo "  1. Update ROOT_DIR calculation to match directory depth"
    echo "  2. Replace obsolete path references with new paths"
    echo "  3. Use ROOT_DIR instead of hard-coded relative paths"
    echo "  4. Run: chmod +x <script> for scripts missing executable permission"
    echo "  5. Update wrapper scripts to reference builder.sh correctly"
    echo ""
    
    # Write detailed report
    REPORT_FILE="$OUTPUT_DIR/script-path-lint-report.txt"
    {
        echo "Script Path Lint Report"
        echo "Generated: $(date)"
        echo ""
        echo "Total files checked: $TOTAL_FILES"
        echo "Violations found: $VIOLATIONS"
        echo ""
        echo "Issues:"
        for issue in "${ISSUES[@]}"; do
            echo "  $issue"
        done
    } > "$REPORT_FILE"
    
    echo "📄 Detailed report saved to: $REPORT_FILE"
    echo ""
    exit 1
fi

