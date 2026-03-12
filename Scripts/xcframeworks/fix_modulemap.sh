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
# Fix module.modulemap for XCFramework
# ============================================================================
# Purpose: Add link directives for third-party dependencies to module maps
# Usage:   ./Scripts/xcframeworks/fix_modulemap.sh <XCFrameworkPath> <ModuleName> [dependencies...]
# ============================================================================

set -euo pipefail

XCFRAMEWORK_PATH="$1"
MODULE_NAME="$2"
shift 2
DEPENDENCIES=("$@")

if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
    echo "Error: XCFramework not found: $XCFRAMEWORK_PATH"
    exit 1
fi

# Find only the main module's module.modulemap files (not embedded frameworks)
# Pattern: <XCFramework>/<platform>/<ModuleName>.framework/Modules/module.modulemap
find "$XCFRAMEWORK_PATH" -type d -name "*.framework" | while read -r framework_dir; do
    # Check if this is the main module's framework (not an embedded one)
    framework_name=$(basename "$framework_dir" .framework)
    
    # Skip if this is an embedded framework (inside Frameworks/ subdirectory)
    if echo "$framework_dir" | grep -q "/Frameworks/"; then
        continue
    fi
    
    # Only process if this matches our module name
    if [[ "$framework_name" != "$MODULE_NAME" ]]; then
        continue
    fi
    
    modulemap="$framework_dir/Modules/module.modulemap"
    if [[ ! -f "$modulemap" ]]; then
        continue
    fi
    
    echo "Fixing modulemap: $modulemap"
    
    # Read current modulemap
    CURRENT_CONTENT=$(cat "$modulemap")
    
    # Check if modulemap already has pure Swift structure (no umbrella header, no .Swift submodule)
    HAS_UMBRELLA=$(echo "$CURRENT_CONTENT" | grep -q "umbrella header" && echo "yes" || echo "no")
    HAS_SWIFT_SUBMODULE=$(echo "$CURRENT_CONTENT" | grep -q "module $MODULE_NAME.Swift" && echo "yes" || echo "no")
    
    # Check if already pure Swift (no umbrella, no .Swift submodule)
    if [[ "$HAS_UMBRELLA" == "no" ]] && [[ "$HAS_SWIFT_SUBMODULE" == "no" ]]; then
        # Already pure Swift, but check if we need to add/update link directives
        if [[ ${#DEPENDENCIES[@]} -gt 0 ]]; then
            # Check if all dependencies are already linked
            ALL_LINKED=true
            for dep in "${DEPENDENCIES[@]}"; do
                if ! echo "$CURRENT_CONTENT" | grep -q "link \"$dep\""; then
                    ALL_LINKED=false
                    break
                fi
            done
            if [[ "$ALL_LINKED" == "true" ]]; then
                echo "  Modulemap already pure Swift with all link directives, skipping"
                continue
            fi
        else
            # No dependencies and already pure Swift, skip
            echo "  Modulemap already pure Swift, skipping"
            continue
        fi
    fi
    
    # Create pure Swift modulemap (no umbrella header, no ObjC references)
    # This is the correct structure for Swift-only frameworks
    {
        echo "framework module $MODULE_NAME {"
        echo "  export *"
        echo "  module * { export * }"
        
        # Add link directives for each dependency (if any)
        if [[ ${#DEPENDENCIES[@]} -gt 0 ]]; then
            for dep in "${DEPENDENCIES[@]}"; do
                echo "  link \"$dep\""
            done
        fi
        
        echo "}"
    } > "$modulemap.tmp"
    
    mv "$modulemap.tmp" "$modulemap"
    if [[ ${#DEPENDENCIES[@]} -gt 0 ]]; then
        echo "  ✅ Fixed modulemap (pure Swift) with dependencies: ${DEPENDENCIES[*]}"
    else
        echo "  ✅ Fixed modulemap (pure Swift, no dependencies)"
    fi
done

