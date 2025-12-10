#!/bin/bash
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
# ============================================================================
# XCFramework Validator
# ============================================================================
# Purpose: Validate an XCFramework structure and contents
# Usage:   ./Scripts/xcframeworks/validate_xcframework.sh <XCFrameworkPath> <ModuleName>
# ============================================================================

set -euo pipefail

XCFRAMEWORK_PATH="$1"
MODULE_NAME="$2"

if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
    echo "ERROR: XCFramework not found: $XCFRAMEWORK_PATH"
    exit 1
fi

echo "=== Validating $MODULE_NAME.xcframework ==="

# Check structure
VALID=true
ISSUES=()

# 1. Check for platform slices
IOS_SLICE=$(find "$XCFRAMEWORK_PATH" -mindepth 1 -maxdepth 1 -type d -name "ios-arm64" | head -1)
SIM_SLICE=$(find "$XCFRAMEWORK_PATH" -mindepth 1 -maxdepth 1 -type d -name "ios-arm64_x86_64-simulator" | head -1)

if [[ -z "$IOS_SLICE" ]]; then
    ISSUES+=("Missing ios-arm64 slice")
    VALID=false
fi

if [[ -z "$SIM_SLICE" ]]; then
    ISSUES+=("Missing ios-arm64_x86_64-simulator slice")
    VALID=false
fi

# 2. Check module.modulemap for each slice
for slice in "$IOS_SLICE" "$SIM_SLICE"; do
    if [[ -n "$slice" ]]; then
        FRAMEWORK_DIR="$slice/$MODULE_NAME.framework"
        MODULEMAP="$FRAMEWORK_DIR/Modules/module.modulemap"
        
        if [[ ! -f "$MODULEMAP" ]]; then
            ISSUES+=("Missing module.modulemap in $(basename "$slice")")
            VALID=false
        else
            # Check if modulemap has basic structure
            if ! grep -q "framework module $MODULE_NAME" "$MODULEMAP"; then
                ISSUES+=("Invalid module.modulemap structure in $(basename "$slice")")
                VALID=false
            fi
        fi
    fi
done

# 3. Check umbrella header
for slice in "$IOS_SLICE" "$SIM_SLICE"; do
    if [[ -n "$slice" ]]; then
        FRAMEWORK_DIR="$slice/$MODULE_NAME.framework"
        UMBRELLA_HEADER="$FRAMEWORK_DIR/Headers/$MODULE_NAME.h"
        
        if [[ ! -f "$UMBRELLA_HEADER" ]]; then
            ISSUES+=("Missing umbrella header in $(basename "$slice")")
            VALID=false
        fi
    fi
done

# 4. Check for hardcoded paths in swiftinterface files
HARDCODED_PATHS=$(find "$XCFRAMEWORK_PATH" -name "*.swiftinterface" -type f -exec grep -l "Users/" {} \; 2>/dev/null || true)
if [[ -n "$HARDCODED_PATHS" ]]; then
    ISSUES+=("Found hardcoded paths in swiftinterface files")
    VALID=false
fi

# 5. Check embedded frameworks
EMBEDDED_FRAMEWORKS=()
if [[ -d "$IOS_SLICE/$MODULE_NAME.framework/Frameworks" ]]; then
    while IFS= read -r -d '' xcf; do
        EMBEDDED_FRAMEWORKS+=("$(basename "$xcf" .xcframework)")
    done < <(find "$IOS_SLICE/$MODULE_NAME.framework/Frameworks" -mindepth 1 -maxdepth 1 -type d -name "*.xcframework" -print0 2>/dev/null || true)
fi

# 6. Check link directives in modulemap
LINK_DIRECTIVES=()
if [[ -f "$IOS_SLICE/$MODULE_NAME.framework/Modules/module.modulemap" ]]; then
    while IFS= read -r line; do
        if echo "$line" | grep -qE '^\s*link\s+"'; then
            LINK_NAME=$(echo "$line" | sed -E 's/.*link\s+"([^"]+)".*/\1/')
            LINK_DIRECTIVES+=("$LINK_NAME")
        fi
    done < "$IOS_SLICE/$MODULE_NAME.framework/Modules/module.modulemap"
fi

# Output results
echo "Structure: $([ "$VALID" = true ] && echo "✅ Valid" || echo "❌ Invalid")"
if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo "Issues:"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
fi

echo "Embedded frameworks: ${EMBEDDED_FRAMEWORKS[*]:-none}"
echo "Link directives: ${LINK_DIRECTIVES[*]:-none}"

# Check if link directives match embedded frameworks
if [[ ${#EMBEDDED_FRAMEWORKS[@]} -gt 0 ]]; then
    for embedded in "${EMBEDDED_FRAMEWORKS[@]}"; do
        if [[ ! " ${LINK_DIRECTIVES[*]} " =~ " ${embedded} " ]]; then
            ISSUES+=("Embedded framework '$embedded' missing link directive")
            VALID=false
        fi
    done
fi

if [[ "$VALID" = true ]]; then
    echo "Overall: ✅ PASS"
    exit 0
else
    echo "Overall: ❌ NEEDS FIX"
    exit 1
fi

