#!/usr/bin/env bash
set -euo pipefail

# Script: migrate-spec-names.sh
# Purpose: Migrate spec directories from numbered (001-name) to semantic (name) format
# Usage: ./migrate-spec-names.sh [--dry-run]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly SPECS_DIR="$REPO_ROOT/specs"

DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: $0 [--dry-run]" >&2
            exit 1
            ;;
    esac
done

# Function to migrate a single spec
migrate_spec() {
    local old_name="$1"
    local new_name="${old_name#[0-9][0-9][0-9]-}"

    # Skip if already migrated (no number prefix)
    if [[ "$old_name" == "$new_name" ]]; then
        echo "[INFO] Already migrated: $old_name"
        return 0
    fi

    local old_path="$SPECS_DIR/$old_name"
    local new_path="$SPECS_DIR/$new_name"
    local spec_file="$old_path/spec.md"

    if [[ ! -d "$old_path" ]]; then
        echo "[WARN] Spec directory not found: $old_path"
        return 0
    fi

    echo "[MIGRATE] $old_name → $new_name"

    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY-RUN] Would rename directory: $old_path → $new_path"
        if [[ -f "$spec_file" ]]; then
            echo "  [DRY-RUN] Would update spec.md Feature Branch field"
        fi
        if git rev-parse --verify "$old_name" &>/dev/null; then
            echo "  [DRY-RUN] Would rename git branch: $old_name → $new_name"
        fi
        return 0
    fi

    # Rename directory
    if [[ -d "$new_path" ]]; then
        echo "  [ERROR] Target directory already exists: $new_path" >&2
        return 1
    fi
    mv "$old_path" "$new_path"
    echo "  [OK] Renamed directory"

    # Update spec.md Feature Branch field
    if [[ -f "$new_path/spec.md" ]]; then
        # Match both backtick and non-backtick formats
        if grep -q "Feature Branch" "$new_path/spec.md"; then
            # Use sed to update the Feature Branch field
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS sed requires empty string for -i
                sed -i '' "s/Feature Branch.*$old_name/Feature Branch**: \`$new_name\`/" "$new_path/spec.md"
            else
                # GNU sed
                sed -i "s/Feature Branch.*$old_name/Feature Branch**: \`$new_name\`/" "$new_path/spec.md"
            fi
            echo "  [OK] Updated spec.md"
        else
            echo "  [WARN] Feature Branch field not found in spec.md"
        fi
    fi

    # Rename git branch if it exists
    if git rev-parse --verify "$old_name" &>/dev/null 2>&1; then
        git branch -m "$old_name" "$new_name"
        echo "  [OK] Renamed git branch"
    else
        echo "  [INFO] Git branch '$old_name' not found (may be on remote only or already renamed)"
    fi
}

# Main execution
main() {
    echo "================================================================"
    echo "  Spec Migration: Numbered → Semantic Naming"
    echo "================================================================"
    echo "Specs directory: $SPECS_DIR"
    if [[ "$DRY_RUN" == true ]]; then
        echo "Mode: DRY RUN (no changes will be made)"
    fi
    echo ""

    # Find all numbered spec directories
    if [[ ! -d "$SPECS_DIR" ]]; then
        echo "[ERROR] Specs directory not found: $SPECS_DIR" >&2
        exit 1
    fi

    local count=0
    local migrated=0
    local skipped=0

    # Process all directories matching the pattern NNN-*
    for dir in "$SPECS_DIR"/[0-9][0-9][0-9]-*; do
        if [[ -d "$dir" ]]; then
            local dir_name=$(basename "$dir")
            count=$((count + 1))

            if migrate_spec "$dir_name"; then
                migrated=$((migrated + 1))
            else
                skipped=$((skipped + 1))
            fi
        fi
    done

    echo ""
    echo "================================================================"
    echo "  Migration Summary"
    echo "================================================================"
    echo "Total specs found: $count"
    echo "Successfully migrated: $migrated"
    echo "Skipped/Failed: $skipped"

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "This was a DRY RUN. Run without --dry-run to apply changes."
    fi
}

# Entry point
main
