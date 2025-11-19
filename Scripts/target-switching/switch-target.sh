#!/usr/bin/env bash
# ============================================================================
# Target Switching Script
# ============================================================================
# Purpose: Switch between CocoaPods and Swift Package Manager (SPM) targets.
#
# Usage:   ./Scripts/target-switching/switch-target.sh [spm|pods]
# ============================================================================

set -euo pipefail

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared libraries
# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"

# Initialize paths
init_paths

# Bold text
BOLD='\033[1m'

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 [spm|pods]"
    echo ""
    echo "Examples:"
    echo "  $0 spm    # Switch to Swift Package Manager"
    echo "  $0 pods   # Switch to CocoaPods"
    exit 1
fi

if [[ "$TARGET" != "spm" ]] && [[ "$TARGET" != "pods" ]]; then
    echo -e "${RED}ERROR: Invalid target. Must be 'spm' or 'pods'${NC}" >&2
    exit 1
fi

echo "============================================================================"
echo "${BOLD}Target Switching: $TARGET${NC}"
echo "============================================================================"
echo ""
echo "Repository: $ROOT_DIR"
echo ""

# Safety check
if [[ ! -f "$ROOT_DIR/.git/config" ]] && [[ ! -f "$ROOT_DIR/Podfile" ]]; then
    echo -e "${RED}ERROR: Not in MSP iOS SDK repository. Aborting.${NC}" >&2
    exit 1
fi

# ============================================================================
# SPM TARGET SWITCHING
# ============================================================================

if [[ "$TARGET" == "spm" ]]; then
    echo "Switching to Swift Package Manager (SPM)..."
    echo ""
    
    # Step 1: Clean CocoaPods
    echo "Step 1: Cleaning CocoaPods environment..."
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        echo "  Removing Pods/ directory..."
        rm -rf "$ROOT_DIR/Pods"
        echo -e "  ${GREEN}✓${NC} Pods/ removed"
    else
        echo -e "  ${YELLOW}⚠${NC} Pods/ already removed"
    fi
    
    if [[ -d "$ROOT_DIR/MSPDemoApp.xcworkspace" ]]; then
        echo "  Removing CocoaPods workspace..."
        rm -rf "$ROOT_DIR/MSPDemoApp.xcworkspace"
        echo -e "  ${GREEN}✓${NC} CocoaPods workspace removed"
    else
        echo -e "  ${YELLOW}⚠${NC} CocoaPods workspace already removed"
    fi
    
    # Step 2: Clean SPM
    echo ""
    echo "Step 2: Cleaning SwiftPM environment..."
    "$SCRIPT_DIR/cleanup-spm.sh" <<< "y" || {
        echo -e "${YELLOW}⚠${NC} SPM cleanup had warnings (continuing)"
    }
    
    # Step 3: Build xcframeworks
    echo ""
    echo "Step 3: Building wrapper xcframeworks..."
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        echo -e "${YELLOW}⚠${NC} Pods/ still exists. Building xcframeworks requires CocoaPods."
        echo "  Skipping xcframework build. Run manually after pod install if needed."
    else
        echo -e "${YELLOW}⚠${NC} Pods/ not found. Cannot build xcframeworks."
        echo "  If xcframeworks are missing, run:"
        echo "    1. bundle exec pod install"
        echo "    2. Scripts/target-switching/build-xcframeworks.sh"
    fi
    
    # Step 4: Update workspace
    echo ""
    echo "Step 4: Updating workspace..."
    UPDATE_SCRIPT="$ROOT_DIR/Scripts/workspace/update.sh"
    if [[ -f "$UPDATE_SCRIPT" ]]; then
        "$UPDATE_SCRIPT"
        echo -e "${GREEN}✓${NC} Workspace updated"
    else
        echo -e "${RED}✗${NC} Workspace update script not found: $UPDATE_SCRIPT"
        exit 1
    fi
    
    # Step 5: Validate environment
    echo ""
    echo "Step 5: Validating environment..."
    "$SCRIPT_DIR/switch-target-validator.sh" || {
        echo -e "${YELLOW}⚠${NC} Validation had warnings or failures"
    }
    
    # Step 6: Verify environment
    echo ""
    echo "Step 6: Verifying environment..."
    "$SCRIPT_DIR/verify-environment.sh" spm || {
        echo -e "${RED}✗${NC} Environment verification failed"
        exit 1
    }
    
    # Step 7: Open Xcode
    echo ""
    echo "Step 7: Opening Xcode..."
    WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
    if [[ -d "$WORKSPACE" ]]; then
        open "$WORKSPACE"
        echo -e "${GREEN}✓${NC} Xcode opened with SPM workspace"
    else
        echo -e "${RED}✗${NC} Workspace not found: $WORKSPACE"
        exit 1
    fi

# ============================================================================
# COCOAPODS TARGET SWITCHING
# ============================================================================

elif [[ "$TARGET" == "pods" ]]; then
    echo "Switching to CocoaPods..."
    echo ""
    
    # Step 1: Clean SPM
    echo "Step 1: Cleaning SwiftPM environment..."
    "$SCRIPT_DIR/cleanup-spm.sh" <<< "y" || {
        echo -e "${YELLOW}⚠${NC} SPM cleanup had warnings (continuing)"
    }
    
    # Step 2: Clean and install CocoaPods
    echo ""
    echo "Step 2: Cleaning and installing CocoaPods..."
    "$SCRIPT_DIR/cleanup-cocoapods.sh"
    
    # Step 3: Validate wrappers (if Pods exist)
    echo ""
    echo "Step 3: Validating wrapper xcframeworks..."
    if [[ -d "$ROOT_DIR/Pods" ]]; then
        VALIDATE_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/validate-wrappers.sh"
        if [[ -f "$VALIDATE_SCRIPT" ]]; then
            "$VALIDATE_SCRIPT" || {
                echo -e "${YELLOW}⚠${NC} Wrapper validation had warnings or failures"
            }
        else
            echo -e "${YELLOW}⚠${NC} Wrapper validation script not found"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Pods/ not found, skipping wrapper validation"
    fi
    
    # Step 4: Verify environment
    echo ""
    echo "Step 4: Verifying environment..."
    "$SCRIPT_DIR/verify-environment.sh" pods || {
        echo -e "${RED}✗${NC} Environment verification failed"
        exit 1
    }
    
    # Step 5: Open Xcode
    echo ""
    echo "Step 5: Opening Xcode..."
    WORKSPACE="$ROOT_DIR/MSPDemoApp.xcworkspace"
    if [[ -d "$WORKSPACE" ]]; then
        open "$WORKSPACE"
        echo -e "${GREEN}✓${NC} Xcode opened with CocoaPods workspace"
    else
        echo -e "${RED}✗${NC} Workspace not found: $WORKSPACE"
        exit 1
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "============================================================================"
echo "${BOLD}Switching Complete${NC}"
echo "============================================================================"
echo ""
echo -e "${GREEN}✓${NC} Successfully switched to: ${BOLD}$TARGET${NC}"
echo ""
echo "Next steps:"
if [[ "$TARGET" == "spm" ]]; then
    echo "  1. Wait for Xcode to resolve packages (File → Packages → Resolve Package Versions)"
    echo "  2. Build MSPDemoApp-SPM target"
    echo "  3. Run: Scripts/target-switching/switch-target-validator.sh (if needed)"
else
    echo "  1. Build MSPDemoApp target"
    echo "  2. Verify all adapters are working"
fi
echo ""

