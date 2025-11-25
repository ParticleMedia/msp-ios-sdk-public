#!/bin/bash
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
    
    # Check if modulemap already has simplified structure (no .Swift submodule)
    if ! echo "$CURRENT_CONTENT" | grep -q "module $MODULE_NAME.Swift"; then
        # Already simplified, but check if we need to add/update link directives
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
                echo "  Modulemap already simplified with all link directives, skipping"
                continue
            fi
        else
            # No dependencies and already simplified, skip
            echo "  Modulemap already simplified, skipping"
            continue
        fi
    fi
    
    # Parse existing modulemap to preserve structure
    # Extract umbrella header line if present
    UMBRELLA_HEADER=$(echo "$CURRENT_CONTENT" | grep -E "umbrella header" | sed -E 's/.*umbrella header "([^"]+)".*/\1/' || echo "$MODULE_NAME.h")
    
    # Create simplified modulemap with link directives (no .Swift submodule)
    # This avoids "underlying Objective-C module not found" errors
    {
        echo "framework module $MODULE_NAME {"
        if [[ -n "$UMBRELLA_HEADER" ]]; then
            echo "  umbrella header \"$UMBRELLA_HEADER\""
        fi
        echo "  export *"
        echo ""
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
        echo "  ✅ Fixed modulemap with dependencies: ${DEPENDENCIES[*]}"
    else
        echo "  ✅ Fixed modulemap (simplified, no dependencies)"
    fi
done

