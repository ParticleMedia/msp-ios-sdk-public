#!/bin/bash
# ============================================================================
# XCFramework Builder for Single Module
# ============================================================================
# Purpose: Build a single module into .xcframework using XcodeGen project.yml
# Usage:   ./Scripts/xcframeworks/build_module.sh <ModuleName>
# ============================================================================

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/target-switching/common.sh
source "$SCRIPT_DIR/../target-switching/common.sh"

ensure_repo_root

MODULE_NAME="${1:-}"
if [[ -z "$MODULE_NAME" ]]; then
    log_error "Module name required"
    log_info "Usage: $0 <ModuleName>"
    exit 1
fi

# For Core modules, use XCFramework-suffixed scheme to avoid Pods conflicts
if [[ "$MODULE_NAME" =~ ^(MSPCore|NovaCore|MSPiOSCore|MSPSharedLibraries|MSPOMSDK)$ ]]; then
    SCHEME_NAME="${MODULE_NAME}-XCFramework"
else
    SCHEME_NAME="$MODULE_NAME"
fi
# Try new structure first (Sources/Core/, Sources/Adapters/, Sources/Common/), fallback to old
if [[ -f "$ROOT_DIR/Sources/Core/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/Core/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/Sources/Adapters/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/Adapters/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/Sources/Common/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/Common/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/project.yml"
elif [[ -f "$ROOT_DIR/$MODULE_NAME/project.yml" ]]; then
    PROJECT_YML="$ROOT_DIR/$MODULE_NAME/project.yml"
else
    log_error "project.yml not found for $MODULE_NAME"
    exit 1
fi

if [[ ! -f "$PROJECT_YML" ]]; then
    log_error "project.yml not found: $PROJECT_YML"
    exit 1
fi

log_title "Building XCFramework: $MODULE_NAME"

# Create output directories
ARCHIVES_DIR="$ROOT_DIR/Build/Archives"
XCFRAMEWORKS_DIR="$ROOT_DIR/Build/XCFrameworks"
mkdir -p "$ARCHIVES_DIR" "$XCFRAMEWORKS_DIR"

# Generate Xcode project from project.yml
# Run xcodegen from the project directory to ensure relative paths resolve correctly
log_step "Generating Xcode project from project.yml"
PROJECT_DIR=$(dirname "$PROJECT_YML")
if ! (cd "$PROJECT_DIR" && xcodegen generate --spec "$(basename "$PROJECT_YML")"); then
    log_error "Failed to generate Xcode project for $MODULE_NAME"
    exit 1
fi

# Verify project was generated
# Determine project location based on module location
if [[ -f "$ROOT_DIR/Sources/Core/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/Core/$MODULE_NAME/$MODULE_NAME.xcodeproj"
elif [[ -f "$ROOT_DIR/Sources/Adapters/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/Adapters/$MODULE_NAME/$MODULE_NAME.xcodeproj"
elif [[ -f "$ROOT_DIR/Sources/Common/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/Common/$MODULE_NAME/$MODULE_NAME.xcodeproj"
elif [[ -f "$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/project.yml" ]]; then
    XCODEPROJ="$ROOT_DIR/Sources/SharedLibraries/$MODULE_NAME/$MODULE_NAME.xcodeproj"
else
    XCODEPROJ="$ROOT_DIR/$MODULE_NAME/$MODULE_NAME.xcodeproj"
fi
if [[ ! -d "$XCODEPROJ" ]]; then
    log_error "Xcode project not generated: $XCODEPROJ"
    exit 1
fi

# DerivedData path - use shared path if Pods were pre-built, otherwise use module-specific
SHARED_DERIVED_DATA="$ROOT_DIR/DerivedData/build-shared"
if [[ -d "$SHARED_DERIVED_DATA" ]] && [[ -d "$SHARED_DERIVED_DATA/Build/Products/Release-iphoneos" ]]; then
    # Use shared DerivedData so pre-built Pods are available during archive
    DERIVED_DATA="$SHARED_DERIVED_DATA"
    log_info "Using shared DerivedData (Pods pre-built): $DERIVED_DATA"
else
    # Use module-specific DerivedData if Pods weren't pre-built
    DERIVED_DATA="$ROOT_DIR/.generated/DerivedData/build-$MODULE_NAME"
    log_info "Using module-specific DerivedData: $DERIVED_DATA"
fi
mkdir -p "$DERIVED_DATA"

# Archive paths
IOS_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-iOS.xcarchive"
SIMULATOR_ARCHIVE="$ARCHIVES_DIR/$MODULE_NAME-Simulator.xcarchive"

# Clean previous archives
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"

# Use workspace if available and scheme exists, otherwise use project
# Prefer main workspace (contains Pods) over generated workspace
WORKSPACE="$ROOT_DIR/msp-ios-sdk.xcworkspace"
if [[ ! -d "$WORKSPACE" ]]; then
    WORKSPACE="$ROOT_DIR/.generated/msp-ios-sdk.xcworkspace"
fi

# Check if scheme exists in workspace
# NOTE: Skip workspace mode entirely for XCFramework builds because:
#   1. CocoaPods creates duplicate schemes in Pods.xcodeproj that conflict with our targets
#   2. The Pods scheme has different build settings (staticlib, different install paths)
#   3. We need our XcodeGen-generated project with correct framework settings
# Always use project mode for XCFramework builds
SCHEME_IN_WORKSPACE=false
# Disabled: Pods project conflicts with adapter schemes
# if [[ -d "$WORKSPACE" ]]; then
#     if xcodebuild -workspace "$WORKSPACE" -list 2>/dev/null | grep -qE "^\s*$SCHEME_NAME\s*$"; then
#         SCHEME_IN_WORKSPACE=true
#     fi
# fi

# For Core modules, use PROJECT mode (not workspace) to avoid Pods scheme conflicts
# but still inject -I paths for pre-built Pod modules (especially Kingfisher from MSPKingfisher)
# CocoaPods creates duplicate xcodeproj files that conflict with our XcodeGen projects
if [[ "$MODULE_NAME" =~ ^(MSPCore|NovaCore|MSPiOSCore|MSPSharedLibraries|MSPOMSDK)$ ]]; then
    # Core modules MUST use project mode to avoid Pods conflicts
    BUILD_ARG="-project"
    BUILD_PATH="$XCODEPROJ"
    
    if [[ ! -d "$XCODEPROJ" ]]; then
        log_error "Project not found: $XCODEPROJ"
        exit 1
    fi
    
    # Add Swift include paths to find pre-built Pod modules (Kingfisher, SnapKit, etc.)
    # Pod modules are built in shared DerivedData by build-core.sh
    SHARED_DERIVED_DATA="$ROOT_DIR/.generated/DerivedData/build-shared"
    
    # Build SEPARATE path arrays for iOS and Simulator Pod modules
    # CRITICAL: Each archive must ONLY see its own platform's modules to avoid redefinition errors
    # NovaCore needs: Kingfisher, SnapKit, Lottie, Shimmer
    # MSPCore needs: MSPPrebidAdapter
    POD_MODULES=("MSPKingfisher" "SnapKit" "lottie-ios" "Shimmer" "MSPPrebidAdapter")
    POD_IOS_MODULES=""
    POD_SIM_MODULES=""
    
    for pod in "${POD_MODULES[@]}"; do
        ios_path="$SHARED_DERIVED_DATA/Build/Products/Release-iphoneos/$pod"
        sim_path="$SHARED_DERIVED_DATA/Build/Products/Release-iphonesimulator/$pod"
        if [[ -d "$ios_path" ]]; then
            POD_IOS_MODULES="$POD_IOS_MODULES:$ios_path"
        fi
        if [[ -d "$sim_path" ]]; then
            POD_SIM_MODULES="$POD_SIM_MODULES:$sim_path"
        fi
    done
    # Remove leading colons
    POD_IOS_MODULES="${POD_IOS_MODULES#:}"
    POD_SIM_MODULES="${POD_SIM_MODULES#:}"
    
    # Store BOTH paths separately - will be used for respective archives
    # DO NOT combine them - that causes module redefinition errors
    log_info "Found Pod modules (iOS): $POD_IOS_MODULES"
    log_info "Found Pod modules (Simulator): $POD_SIM_MODULES"
    
    log_info "Core module $MODULE_NAME: Using PROJECT mode (avoids Pods scheme conflicts)"
    log_info "  iOS Swift include paths: $POD_IOS_MODULES"
    log_info "  Simulator Swift include paths: $POD_SIM_MODULES"
elif [[ "$SCHEME_IN_WORKSPACE" == "true" ]]; then
    BUILD_ARG="-workspace"
    BUILD_PATH="$WORKSPACE"
    log_info "Using workspace for Pods dependencies: $WORKSPACE"
    POD_SWIFT_INCLUDE_PATHS=""
    POD_FRAMEWORK_SEARCH_PATHS=""
else
    BUILD_ARG="-project"
    BUILD_PATH="$XCODEPROJ"
    log_warn "Scheme not in workspace, using project directly (Pods dependencies may not be available)"
    POD_SWIFT_INCLUDE_PATHS=""
    POD_FRAMEWORK_SEARCH_PATHS=""
fi

# Build iOS device archive
log_step "Building iOS device archive"
# Add verification skip flags for Pods targets (applies to all targets in workspace)
# These settings are overridden by project.yml for MSP modules, so they only affect Pods
IOS_BUILD_SETTINGS=(
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    SKIP_INSTALL=NO
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface"
)

# Add Pod search paths for Core modules - ONLY iOS paths for iOS archive
# This allows Core modules to resolve Pod modules like Kingfisher (from MSPKingfisher)
if [[ -n "${POD_IOS_MODULES:-}" ]]; then
    # Add -I flags for each iOS Pod module path
    IOS_I_FLAGS=""
    IOS_HEADER_PATHS=""
    IFS=':' read -ra IOS_PATHS <<< "$POD_IOS_MODULES"
    for path in "${IOS_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            IOS_I_FLAGS="$IOS_I_FLAGS -I$path"
            IOS_HEADER_PATHS="$IOS_HEADER_PATHS $path"
        fi
    done
    if [[ -n "$IOS_I_FLAGS" ]]; then
        # Update OTHER_SWIFT_FLAGS to include ONLY iOS Pod module paths
        IOS_BUILD_SETTINGS[3]="OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface$IOS_I_FLAGS"
        # Add HEADER_SEARCH_PATHS for Clang to find module headers
        IOS_BUILD_SETTINGS+=("HEADER_SEARCH_PATHS=\$(inherited)$IOS_HEADER_PATHS")
        log_info "iOS archive: Added Swift include paths:$IOS_I_FLAGS"
    fi
fi

# Set MSP_SKIP_CP_XCFRAMEWORKS=1 for Core module builds to skip [CP] Copy XCFrameworks script
# This prevents CocoaPods from trying to copy XCFrameworks that don't exist yet during build
# For normal app builds, this env var is NOT set, so the script runs normally
if [[ "$MODULE_NAME" =~ ^(MSPCore|NovaCore|MSPiOSCore|MSPSharedLibraries|MSPOMSDK)$ ]]; then
    export MSP_SKIP_CP_XCFRAMEWORKS=1
    log_info "Setting MSP_SKIP_CP_XCFRAMEWORKS=1 to skip [CP] Copy XCFrameworks during Core XCFramework build"
fi

xcodebuild archive \
    "$BUILD_ARG" "$BUILD_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$IOS_ARCHIVE" \
    -derivedDataPath "$DERIVED_DATA" \
    "${IOS_BUILD_SETTINGS[@]}" \
    -allowProvisioningUpdates

if [[ ! -d "$IOS_ARCHIVE" ]]; then
    log_error "iOS archive not created: $IOS_ARCHIVE"
    exit 1
fi

# Build iOS Simulator archive
log_step "Building iOS Simulator archive"
# CRITICAL: Use SEPARATE BUILD_SETTINGS for Simulator with ONLY Simulator Pod paths
# This prevents module redefinition errors caused by seeing both iOS and Simulator modules
SIM_BUILD_SETTINGS=(
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    SKIP_INSTALL=NO
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO
    OTHER_SWIFT_FLAGS="-no-verify-emitted-module-interface"
)

# Add Pod search paths for Core modules - ONLY Simulator paths for Simulator archive
if [[ -n "${POD_SIM_MODULES:-}" ]]; then
    # Add -I flags for each Simulator Pod module path
    SIM_I_FLAGS=""
    SIM_HEADER_PATHS=""
    IFS=':' read -ra SIM_PATHS <<< "$POD_SIM_MODULES"
    for path in "${SIM_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            SIM_I_FLAGS="$SIM_I_FLAGS -I$path"
            SIM_HEADER_PATHS="$SIM_HEADER_PATHS $path"
        fi
    done
    if [[ -n "$SIM_I_FLAGS" ]]; then
        # Update OTHER_SWIFT_FLAGS to include ONLY Simulator Pod module paths
        SIM_BUILD_SETTINGS[3]="OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface$SIM_I_FLAGS"
        # Add HEADER_SEARCH_PATHS for Clang to find module headers
        SIM_BUILD_SETTINGS+=("HEADER_SEARCH_PATHS=\$(inherited)$SIM_HEADER_PATHS")
        log_info "Simulator archive: Added Swift include paths:$SIM_I_FLAGS"
    fi
fi

# MSP_SKIP_CP_XCFRAMEWORKS is already set above for Core modules, reuse it here
xcodebuild archive \
    "$BUILD_ARG" "$BUILD_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$SIMULATOR_ARCHIVE" \
    -derivedDataPath "$DERIVED_DATA" \
    "${SIM_BUILD_SETTINGS[@]}" \
    -allowProvisioningUpdates

if [[ ! -d "$SIMULATOR_ARCHIVE" ]]; then
    log_error "Simulator archive not created: $SIMULATOR_ARCHIVE"
    exit 1
fi

# Extract PRODUCT_NAME from project.yml (fallback to MODULE_NAME if not found)
# First try global settings
PRODUCT_NAME=$(grep -E "^\s+PRODUCT_NAME:" "$PROJECT_YML" | head -1 | sed -E 's/.*PRODUCT_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' | xargs || echo "")
# If not found, try target-specific settings
if [[ -z "$PRODUCT_NAME" ]]; then
    PRODUCT_NAME=$(grep -A 30 "targets:" "$PROJECT_YML" | grep -E "^\s+PRODUCT_NAME:" | head -1 | sed -E 's/.*PRODUCT_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' | xargs || echo "")
fi
# Fallback to MODULE_NAME if still not found
PRODUCT_NAME="${PRODUCT_NAME:-$MODULE_NAME}"
log_info "Using PRODUCT_NAME: $PRODUCT_NAME (module: $MODULE_NAME)"

# Embed third-party XCFrameworks into archives before creating XCFramework
# This ensures all dependencies are available when the XCFramework is used
log_step "Embedding third-party XCFrameworks into archives"

# Function to embed a third-party XCFramework into a framework archive
embed_thirdparty_xcframework() {
    local archive_path="$1"
    local thirdparty_xcf="$2"
    local framework_path="$archive_path/Products/Library/Frameworks/$PRODUCT_NAME.framework"
    
    if [[ ! -d "$thirdparty_xcf" ]]; then
        log_warn "Third-party XCFramework not found, skipping: $thirdparty_xcf"
        return 0
    fi
    
    # Create Frameworks directory inside the framework if it doesn't exist
    mkdir -p "$framework_path/Frameworks"
    
    # Copy the XCFramework into the framework's Frameworks directory
    local xcf_name=$(basename "$thirdparty_xcf")
    if cp -R "$thirdparty_xcf" "$framework_path/Frameworks/$xcf_name"; then
        log_info "  Embedded: $xcf_name"
    else
        log_warn "  Failed to embed: $xcf_name"
    fi
}

# Determine which third-party frameworks this module needs
# NOTE: Core modules (MSPCore, NovaCore) do NOT embed third-party XCFrameworks.
# They use @_implementationOnly imports and depend on Pod sources at build time.
THIRDPARTY_XCFS=()
case "$MODULE_NAME" in
    # Core modules: No third-party XCFrameworks (use Pod sources)
    MSPCore|NovaCore|MSPiOSCore|MSPSharedLibraries|MSPOMSDK)
        # Core modules use Pod sources, not XCFrameworks
        THIRDPARTY_XCFS=()
        ;;
    NovaAdapter)
        # Adapters are source pods, not XCFrameworks (Round 11)
        THIRDPARTY_XCFS=()
        ;;
    UnityAdapter)
        # UnityAdapter needs IronSource - check if wrapper exists
        if [[ -d "$ROOT_DIR/Scripts/xcframeworks/output-temp/IronSourceSDKWrapper/Frameworks/IronSourceSDK.xcframework" ]]; then
            THIRDPARTY_XCFS=(
                "$ROOT_DIR/Scripts/xcframeworks/output-temp/IronSourceSDKWrapper/Frameworks/IronSourceSDK.xcframework"
            )
        fi
        ;;
    InmobiAdapter)
        # InmobiAdapter needs InMobiSDK
        if [[ -d "$ROOT_DIR/Scripts/xcframeworks/output-temp/InMobiSDKWrapper/Frameworks/InMobiSDK.xcframework" ]]; then
            THIRDPARTY_XCFS=(
                "$ROOT_DIR/Scripts/xcframeworks/output-temp/InMobiSDKWrapper/Frameworks/InMobiSDK.xcframework"
            )
        fi
        ;;
esac

# Embed third-party XCFrameworks into both archives
if [[ ${#THIRDPARTY_XCFS[@]} -gt 0 ]]; then
    for thirdparty_xcf in "${THIRDPARTY_XCFS[@]}"; do
        if [[ -d "$thirdparty_xcf" ]]; then
            embed_thirdparty_xcframework "$IOS_ARCHIVE" "$thirdparty_xcf"
            embed_thirdparty_xcframework "$SIMULATOR_ARCHIVE" "$thirdparty_xcf"
        fi
    done
else
    log_info "  No third-party XCFrameworks to embed for $MODULE_NAME"
fi

# Create XCFramework
log_step "Creating XCFramework"
# Use PRODUCT_NAME for XCFramework output name (matches framework name)
XCFRAMEWORK_OUTPUT="$XCFRAMEWORKS_DIR/$PRODUCT_NAME.xcframework"
rm -rf "$XCFRAMEWORK_OUTPUT"

# Find framework in archive (may be in Products/Library/Frameworks or InstallationBuildProductsLocation)
IOS_FRAMEWORK=""
SIM_FRAMEWORK=""

# Try standard location first
if [[ -d "$IOS_ARCHIVE/Products/Library/Frameworks/$PRODUCT_NAME.framework" ]]; then
    IOS_FRAMEWORK="$IOS_ARCHIVE/Products/Library/Frameworks/$PRODUCT_NAME.framework"
elif [[ -d "$IOS_ARCHIVE/InstallationBuildProductsLocation/Library/Frameworks/$PRODUCT_NAME.framework" ]]; then
    IOS_FRAMEWORK="$IOS_ARCHIVE/InstallationBuildProductsLocation/Library/Frameworks/$PRODUCT_NAME.framework"
else
    # Search in archive
    IOS_FRAMEWORK=$(find "$IOS_ARCHIVE" -name "$PRODUCT_NAME.framework" -type d | head -1)
fi

if [[ -d "$SIMULATOR_ARCHIVE/Products/Library/Frameworks/$PRODUCT_NAME.framework" ]]; then
    SIM_FRAMEWORK="$SIMULATOR_ARCHIVE/Products/Library/Frameworks/$PRODUCT_NAME.framework"
elif [[ -d "$SIMULATOR_ARCHIVE/InstallationBuildProductsLocation/Library/Frameworks/$PRODUCT_NAME.framework" ]]; then
    SIM_FRAMEWORK="$SIMULATOR_ARCHIVE/InstallationBuildProductsLocation/Library/Frameworks/$PRODUCT_NAME.framework"
else
    # Search in archive
    SIM_FRAMEWORK=$(find "$SIMULATOR_ARCHIVE" -name "$PRODUCT_NAME.framework" -type d | head -1)
fi

if [[ -z "$IOS_FRAMEWORK" ]] || [[ ! -d "$IOS_FRAMEWORK" ]]; then
    log_error "iOS framework not found in archive: $IOS_ARCHIVE"
    exit 1
fi

if [[ -z "$SIM_FRAMEWORK" ]] || [[ ! -d "$SIM_FRAMEWORK" ]]; then
    log_error "Simulator framework not found in archive: $SIMULATOR_ARCHIVE"
    exit 1
fi

log_info "Using iOS framework: $IOS_FRAMEWORK"
log_info "Using Simulator framework: $SIM_FRAMEWORK"

xcodebuild -create-xcframework \
    -framework "$IOS_FRAMEWORK" \
    -framework "$SIM_FRAMEWORK" \
    -output "$XCFRAMEWORK_OUTPUT"

if [[ ! -d "$XCFRAMEWORK_OUTPUT" ]]; then
    log_error "XCFramework not created: $XCFRAMEWORK_OUTPUT"
    exit 1
fi

# Verify XCFramework structure
log_step "Verifying XCFramework structure"
if [[ ! -d "$XCFRAMEWORK_OUTPUT/ios-arm64" ]] && [[ ! -d "$XCFRAMEWORK_OUTPUT/ios-arm64_x86_64-simulator" ]]; then
    log_error "XCFramework missing required slices"
    exit 1
fi

# Verify Swift module exists
# Extract PRODUCT_MODULE_NAME from project.yml (fallback to PRODUCT_NAME)
PRODUCT_MODULE_NAME=$(grep -E "^\s*PRODUCT_MODULE_NAME:" "$PROJECT_YML" | head -1 | sed -E 's/.*PRODUCT_MODULE_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' || echo "$PRODUCT_NAME")
if [[ -z "$PRODUCT_MODULE_NAME" ]] || [[ "$PRODUCT_MODULE_NAME" == "$MODULE_NAME" ]]; then
    # Try to get from target settings
    PRODUCT_MODULE_NAME=$(grep -A 20 "targets:" "$PROJECT_YML" | grep -E "^\s*PRODUCT_MODULE_NAME:" | head -1 | sed -E 's/.*PRODUCT_MODULE_NAME:\s*["'\'']?([^"'\'']+)["'\'']?.*/\1/' || echo "$PRODUCT_NAME")
fi
# Fallback to PRODUCT_NAME if still not found
PRODUCT_MODULE_NAME="${PRODUCT_MODULE_NAME:-$PRODUCT_NAME}"

SWIFT_MODULE="$XCFRAMEWORK_OUTPUT/ios-arm64/$PRODUCT_NAME.framework/Modules/$PRODUCT_MODULE_NAME.swiftmodule"
if [[ ! -d "$SWIFT_MODULE" ]] && [[ ! -f "$SWIFT_MODULE/arm64.swiftmodule" ]]; then
    log_warn "Swift module directory not found (may be normal for some modules)"
fi

log_success "XCFramework created: $XCFRAMEWORK_OUTPUT"

# Remove precompiled .swiftmodule binary files to avoid "module was built in directory X but now resides in directory Y" errors
# Keep only .swiftinterface files for interface-based module resolution
log_step "Removing precompiled .swiftmodule binary files"
find "$XCFRAMEWORK_OUTPUT" -type f -name "*.swiftmodule" ! -name "*.swiftinterface" ! -name "*.swiftdoc" ! -name "*.abi.json" -delete 2>/dev/null || true
log_info "  Removed binary .swiftmodule files (keeping .swiftinterface only)"

# Fix module.modulemap to include link directives for embedded third-party frameworks
log_step "Fixing module.modulemap with link directives"
# Use ROOT_DIR to find fix_modulemap.sh (same directory as build_module.sh)
FIX_MODULEMAP_SCRIPT="$ROOT_DIR/Scripts/xcframeworks/fix_modulemap.sh"
if [[ -f "$FIX_MODULEMAP_SCRIPT" ]]; then
    # Build list of third-party framework names from THIRDPARTY_XCFS
    THIRDPARTY_NAMES=()
    if [[ ${#THIRDPARTY_XCFS[@]} -gt 0 ]]; then
        for thirdparty_xcf in "${THIRDPARTY_XCFS[@]}"; do
            if [[ -d "$thirdparty_xcf" ]]; then
                # Extract framework name from path (e.g., "SwiftProtobuf" from ".../SwiftProtobuf.xcframework")
                FRAMEWORK_NAME=$(basename "$thirdparty_xcf" .xcframework)
                THIRDPARTY_NAMES+=("$FRAMEWORK_NAME")
            fi
        done
    fi
    
    if [[ ${#THIRDPARTY_NAMES[@]} -gt 0 ]]; then
        log_info "  Adding link directives for: ${THIRDPARTY_NAMES[*]}"
        if bash "$FIX_MODULEMAP_SCRIPT" "$XCFRAMEWORK_OUTPUT" "$PRODUCT_NAME" "${THIRDPARTY_NAMES[@]}"; then
            log_success "  Module map fixed with link directives"
        else
            log_warn "  Failed to fix module map (non-fatal)"
        fi
    else
        log_info "  No third-party frameworks to link"
    fi
else
    log_warn "fix_modulemap.sh not found, skipping module map fix"
fi

# Special handling for NovaCore: Copy to NovaAdapter/ folder (legacy compatibility)
# This ensures compatibility with scripts that expect NovaCore.xcframework in NovaAdapter/
if [[ "$MODULE_NAME" == "NovaCore" ]]; then
    log_step "Deploying NovaCore.xcframework to NovaAdapter (legacy compatibility)"
    NOVA_ADAPTER_DEST="$ROOT_DIR/NovaAdapter/NovaCore.xcframework"
    TEMP_DEST="$ROOT_DIR/NovaAdapter/NovaCore.xcframework.tmp"
    
    # Backup existing if present
    if [[ -d "$NOVA_ADAPTER_DEST" ]]; then
        mv "$NOVA_ADAPTER_DEST" "${NOVA_ADAPTER_DEST}.backup" 2>/dev/null || true
    fi
    
    # Atomic copy: copy to temp, then move
    if cp -R "$XCFRAMEWORK_OUTPUT" "$TEMP_DEST"; then
        mv "$TEMP_DEST" "$NOVA_ADAPTER_DEST"
        rm -rf "${NOVA_ADAPTER_DEST}.backup" 2>/dev/null || true
        log_success "NovaCore.xcframework deployed to NovaAdapter/"
    else
        log_warn "Failed to copy NovaCore.xcframework to NovaAdapter (continuing anyway)"
        # Restore backup if copy failed
        mv "${NOVA_ADAPTER_DEST}.backup" "$NOVA_ADAPTER_DEST" 2>/dev/null || true
    fi
fi

