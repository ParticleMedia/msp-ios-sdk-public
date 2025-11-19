#!/usr/bin/env bash
# ============================================================================
# Environment Verification
# ============================================================================
# Purpose: Quick checks to verify the environment matches the selected target.
#
# Safety: Read-only checks. Never modifies files.
#
# Usage:   ./Scripts/target-switching/verify-environment.sh [spm|pods]
# ============================================================================

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"

# Initialize paths
init_paths

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 [spm|pods]"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    echo "ERROR: Invalid target. Must be 'spm' or 'pods'" >&2
    exit 1
fi

echo "============================================================================"
echo "Environment Verification: $TARGET"
echo "============================================================================"
echo ""

ERRORS=0

# Check workspace existence
if [[ "$TARGET" == "spm" ]]; then
    WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    WRONG_WORKSPACE="$ROOT_DIR/MSPDemoApp.xcworkspace"
    
    if [[ -d "$WORKSPACE" ]]; then
        echo -e "${GREEN}✓${NC} SPM workspace exists: msp-ios-sdk.xcworkspace"
    else
        echo -e "${RED}✗${NC} SPM workspace missing: msp-ios-sdk.xcworkspace"
        ((ERRORS++))
    fi
    
    if [[ -d "$WRONG_WORKSPACE" ]]; then
        echo -e "${YELLOW}⚠${NC} CocoaPods workspace found (should not exist for SPM): MSPDemoApp.xcworkspace"
    else
        echo -e "${GREEN}✓${NC} CocoaPods workspace correctly absent"
    fi
    
    # Check Pods/ should not exist
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        echo -e "${YELLOW}⚠${NC} Pods/ directory exists (should be removed for SPM)"
    else
        echo -e "${GREEN}✓${NC} Pods/ directory correctly absent"
    fi
    
elif [[ "$TARGET" == "pods" ]]; then
    WORKSPACE="$ROOT_DIR/MSPDemoApp.xcworkspace"
    WRONG_WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    
    if [[ -d "$WORKSPACE" ]]; then
        echo -e "${GREEN}✓${NC} CocoaPods workspace exists: MSPDemoApp.xcworkspace"
    else
        echo -e "${RED}✗${NC} CocoaPods workspace missing: MSPDemoApp.xcworkspace"
        ((ERRORS++))
    fi
    
    if [[ -d "$WRONG_WORKSPACE" ]]; then
        echo -e "${YELLOW}⚠${NC} SPM workspace found (should not exist for CocoaPods): msp-ios-sdk.xcworkspace"
    else
        echo -e "${GREEN}✓${NC} SPM workspace correctly absent"
    fi
    
    # Check Pods/ should exist
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        echo -e "${GREEN}✓${NC} Pods/ directory exists"
    else
        echo -e "${RED}✗${NC} Pods/ directory missing (required for CocoaPods)"
        ((ERRORS++))
    fi
fi

echo ""
echo "============================================================================"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Environment verification PASSED"
    exit 0
else
    echo -e "${RED}✗${NC} Environment verification FAILED ($ERRORS error(s))"
    exit 1
fi

