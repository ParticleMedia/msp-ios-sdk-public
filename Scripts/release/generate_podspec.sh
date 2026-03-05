#!/usr/bin/env bash
# Minimal Podspec Generator for Release Mode Only
#
# Purpose: Generate release podspecs with correct binary paths
# Scope: Phase B - Unified tier architecture (all modes use GitHub Release checksums)
# Input: Existing repo podspec + XCFramework paths
# Output: Build/ReleasePodspecs/*.podspec

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source logging functions
if [[ -f "$ROOT_DIR/Scripts/lib/release-common.sh" ]]; then
    source "$ROOT_DIR/Scripts/lib/release-common.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
fi

# R031d: Source checksum module for unified checksum computation
if [[ -f "$ROOT_DIR/Scripts/lib/checksum.sh" ]]; then
    # shellcheck source=Scripts/lib/checksum.sh
    source "$ROOT_DIR/Scripts/lib/checksum.sh" 2>/dev/null || true
fi

# ============================================================================
# Configuration
# ============================================================================

# Output directory for generated podspecs
GENERATED_PODSPECS_DIR="$ROOT_DIR/Build/ReleasePodspecs"

# Core modules (binary XCFrameworks) vs Adapters (source-based)
# This classification matches the architecture documented in README.md
# Note: NovaCore is not included here - it's embedded via vendored_frameworks, not published separately
# NovaAdapter is a pure binary adapter (vendored_frameworks only), so it's included in CORE_MODULES
CORE_MODULES=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore" "MSPOMSDK" "MSPNovaAdapter")

# Check if a module is a core module
is_core_module() {
    local module="$1"
    for core in "${CORE_MODULES[@]}"; do
        if [[ "$module" == "$core" ]]; then
            return 0
        fi
    done
    return 1
}

# MSP internal dependencies that require version constraints
# Used for dependency version alignment (aligned with legacy update_adapter_podspec_dependencies)
MSP_VERSIONED_DEPS=("MSPiOSCore" "MSPSharedLibraries" "MSPPrebidAdapter" "PrebidAdapter" "MSPGoogleAdsTypes")
MSP_VERSIONED_DEPS_PATTERN="$(IFS='|'; echo "${MSP_VERSIONED_DEPS[*]}")"

# Pods that should consume MSPSnapKit from MSPSharedLibraries in release mode.
# This avoids duplicate MSPSnapKit.xcframeworks across adapters.
SNAPKIT_FROM_SHARED_LIBS_PODS=("MSPNovaAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter" "MSPCore")

should_strip_mspsnapkit_dependency() {
    local module="$1"
    for pod in "${SNAPKIT_FROM_SHARED_LIBS_PODS[@]}"; do
        if [[ "$module" == "$pod" ]]; then
            return 0
        fi
    done
    return 1
}

# Pods that embed Kingfisher inside NovaCore and must NOT add a public Kingfisher dependency.
# This prevents a second copy of Kingfisher from being pulled into the app.
KINGFISHER_EMBEDDED_PODS=("MSPNovaAdapter")

should_skip_kingfisher_dependency() {
    local module="$1"
    for pod in "${KINGFISHER_EMBEDDED_PODS[@]}"; do
        if [[ "$module" == "$pod" ]]; then
            return 0
        fi
    done
    return 1
}

# ============================================================================
# Binary Distribution Pods (HTTP zip source)
# ============================================================================
# These pods are distributed as pre-built XCFrameworks via HTTP zip from GitHub Releases.
# This is a DISTRIBUTION METHOD choice, NOT a release order priority.
#
# Two Independent Dimensions:
# 1. Release Order: Based on dependency relationships (see publish.sh)
#    MSPiOSCore → MSPSharedLibraries → Adapters → MSPCore
# 2. Distribution Method: Binary (HTTP zip) vs Source (git+tag)
#    - Binary: MSPiOSCore, MSPSharedLibraries, MSPCore, NovaAdapter
#    - Source: MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, MSPAmazonAdapter
#
# Note: NovaAdapter uses binary distribution (includes private NovaCore.xcframework)
#       but is released in Adapters phase (Step 2), NOT in foundation phase.
# ============================================================================
BINARY_DISTRIBUTION_PODS=("MSPSharedLibraries" "MSPGoogleAdsTypes" "MSPCore" "MSPiOSCore" "MSPNovaAdapter" "MSPPrebidAdapter" "MSPGoogleAdapter" "MSPFacebookAdapter" "MSPAmazonAdapter" "MSPMolocoAdapter" "MSPLiftoffAdapter")

# Check if a pod uses binary distribution (HTTP zip source)
# Returns 0 (true) if the pod is in BINARY_DISTRIBUTION_PODS
is_binary_distribution() {
    local module="$1"
    for pod in "${BINARY_DISTRIBUTION_PODS[@]}"; do
        if [[ "$module" == "$pod" ]]; then
            return 0
        fi
    done
    return 1
}

# MSP internal dependencies that require version constraints
# Used for dependency version alignment (aligned with legacy update_adapter_podspec_dependencies)
MSP_VERSIONED_DEPS=("MSPiOSCore" "MSPSharedLibraries" "MSPPrebidAdapter" "PrebidAdapter" "MSPGoogleAdsTypes")
MSP_VERSIONED_DEPS_PATTERN="$(IFS='|'; echo "${MSP_VERSIONED_DEPS[*]}")"

# ============================================================================
# Unified Checksum Calculation (Phase B)
# ============================================================================
# Phase B Change: Always calculate checksum from GitHub Release CDN
# NO MORE local zip checksums (except debug fallback with explicit flag)
# ============================================================================

# Calculate checksum from GitHub Release CDN (ONLY source of truth)
# Args:
#   $1: zip_url - GitHub Release URL
#   $2: pod_name - Pod name
#   $3: version - Release version
# Returns:
#   Prints SHA256 checksum (64 hex chars) to stdout
#   Returns 1 if zip file not accessible
calculate_checksum_from_github() {
    local zip_url="$1"
    local pod_name="$2"
    local version="$3"
    local zip_name="${pod_name}-${version}.zip"

    log::info "PODSPEC" "Calculating checksum from GitHub Release CDN" >&2
    log::debug "PODSPEC" "URL: $zip_url" >&2

    # Wait for CDN propagation (configurable)
    local cdn_wait_time="${MSP_CDN_WAIT_TIME:-120}"
    log::info "PODSPEC" "Waiting ${cdn_wait_time}s for GitHub CDN propagation..." >&2
    sleep "$cdn_wait_time"

    # Download and calculate checksum
    local temp_zip="/tmp/verify-${pod_name}-${version}-$$.zip"
    local download_attempt=1
    local max_attempts=3
    local checksum=""

    while [[ $download_attempt -le $max_attempts ]]; do
        if curl -L -f -s -o "$temp_zip" "$zip_url" 2>/dev/null; then
            local file_size=$(stat -f%z "$temp_zip" 2>/dev/null || stat -c%s "$temp_zip" 2>/dev/null || echo "0")

            if [[ $file_size -gt 0 ]]; then
                # R031d: Use checksum.sh module if available, fallback to shasum
                if command -v checksum_compute_sha256 &>/dev/null; then
                    checksum=$(checksum_compute_sha256 "$temp_zip")
                else
                    checksum=$(shasum -a 256 "$temp_zip" 2>/dev/null | awk '{print $1}')
                fi

                if [[ -n "$checksum" && ${#checksum} -eq 64 ]]; then
                    log::success "PODSPEC" "✅ Successfully calculated checksum from GitHub Release" >&2
                    log::info "PODSPEC" "   Checksum: $checksum" >&2
                    log::info "PODSPEC" "   File size: $file_size bytes" >&2

                    # Cleanup
                    rm -f "$temp_zip"
                    echo "$checksum"
                    return 0
                else
                    log::warn "PODSPEC" "Invalid checksum format, retrying..." >&2
                fi
            else
                log::warn "PODSPEC" "Downloaded file is empty, retrying..." >&2
            fi
        else
            log::warn "PODSPEC" "Download failed (attempt $download_attempt/$max_attempts)" >&2
        fi

        if [[ $download_attempt -lt $max_attempts ]]; then
            log::info "PODSPEC" "Waiting 30 seconds before retry..." >&2
            sleep 30
        fi

        ((download_attempt++)) || true
    done

    # Cleanup on failure
    rm -f "$temp_zip"

    log::error "PODSPEC" "❌ Failed to calculate checksum from GitHub Release" >&2
    log::error "PODSPEC" "URL: $zip_url" >&2
    log::error "PODSPEC" "Possible causes:" >&2
    log::error "PODSPEC" "  1. CDN not yet propagated (increase MSP_CDN_WAIT_TIME)" >&2
    log::error "PODSPEC" "  2. GitHub Release not created" >&2
    log::error "PODSPEC" "  3. Zip file not uploaded to release" >&2
    log::error "PODSPEC" "  4. Network issue or rate limiting" >&2
    return 1
}

# Optional: Local checksum fallback (ONLY FOR DEBUGGING)
# Args:
#   $1: pod_name - Pod name
#   $2: version - Release version
# Returns:
#   Prints SHA256 checksum (64 hex chars) to stdout
#   Returns 1 if zip file not found
calculate_checksum_from_local() {
    local pod_name="$1"
    local version="$2"
    local zip_name="${pod_name}-${version}.zip"
    local local_zip="$ROOT_DIR/Build/Zips/$zip_name"

    log::warn "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    log::warn "PODSPEC" "⚠️  WARNING: Using LOCAL CHECKSUM (debug mode)" >&2
    log::warn "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    log::warn "PODSPEC" "This checksum will NOT match production GitHub Release!" >&2
    log::warn "PODSPEC" "This is ONLY for debugging. Do NOT publish with local checksums." >&2
    log::warn "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    if [[ ! -f "$local_zip" ]]; then
        log::error "PODSPEC" "Local zip not found: $local_zip" >&2
        return 1
    fi

    # R031d: Use checksum.sh module if available, fallback to shasum
    local checksum
    if command -v checksum_compute_sha256 &>/dev/null; then
        checksum=$(checksum_compute_sha256 "$local_zip")
    else
        checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
    fi

    if [[ ! "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
        log::error "PODSPEC" "Invalid checksum format: $checksum" >&2
        return 1
    fi

    log::warn "PODSPEC" "Local checksum: $checksum (DEBUG ONLY)" >&2
    echo "$checksum"
    return 0
}

# Main checksum calculation entry point (backward compatible)
# Args:
#   $1: zip_url - GitHub Release URL
#   $2: pod_name - Pod name
#   $3: version - Release version
# Returns:
#   Prints SHA256 checksum (64 hex chars) to stdout
#   Returns 1 if zip file not accessible
calculate_zip_sha256() {
    local zip_url="$1"
    local pod_name="$2"
    local version="$3"

    # ALWAYS try GitHub first (ONLY source of truth)
    local checksum
    if checksum=$(calculate_checksum_from_github "$zip_url" "$pod_name" "$version" 2>/dev/null); then
        echo "$checksum"
        return 0
    fi

    # Local fallback ONLY if explicitly allowed (debug mode)
    if [[ "${MSP_ALLOW_LOCAL_CHECKSUM:-false}" == "true" ]]; then
        log::warn "PODSPEC" "GitHub checksum failed, falling back to local zip" >&2
        log::warn "PODSPEC" "Set MSP_ALLOW_LOCAL_CHECKSUM=false to disable this fallback" >&2
        if checksum=$(calculate_checksum_from_local "$pod_name" "$version" 2>/dev/null); then
            echo "$checksum"
            return 0
        fi
    fi

    # Both failed
    log::error "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    log::error "PODSPEC" "Failed to calculate checksum for $pod_name $version" >&2
    log::error "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    log::error "PODSPEC" "GitHub checksum failed and local fallback disabled" >&2
    log::error "PODSPEC" "Troubleshooting:" >&2
    log::error "PODSPEC" "  1. Ensure GitHub Release is created" >&2
    log::error "PODSPEC" "  2. Ensure zip is uploaded to release" >&2
    log::error "PODSPEC" "  3. Wait for CDN propagation (60-120s)" >&2
    log::error "PODSPEC" "  4. Check network connectivity" >&2
    log::error "PODSPEC" "" >&2
    log::error "PODSPEC" "Debug: Set MSP_ALLOW_LOCAL_CHECKSUM=true to use local zip (NOT for production)" >&2
    log::error "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    return 1
}

# Verify checksum consistency (podspec vs GitHub)
# Args:
#   $1: pod_name - Pod name
#   $2: version - Release version
# Returns:
#   0 if checksums match, 1 if mismatch
verify_podspec_checksum() {
    local pod_name="$1"
    local version="$2"
    local podspec_path="$ROOT_DIR/Build/ReleasePodspecs/${pod_name}.podspec"

    if [[ ! -f "$podspec_path" ]]; then
        log::error "PODSPEC" "Podspec not found: $podspec_path" >&2
        return 1
    fi

    log::info "PODSPEC" "Verifying podspec checksum: $pod_name" >&2

    # Extract checksum from podspec
    local podspec_checksum
    podspec_checksum=$(grep -A 3 "s.source = {" "$podspec_path" | grep ":sha256" | sed -E "s/.*['\"]([a-f0-9]{64})['\"].*/\1/" | head -1)

    if [[ -z "$podspec_checksum" ]]; then
        log::error "PODSPEC" "Failed to extract checksum from podspec" >&2
        return 1
    fi

    log::debug "PODSPEC" "Podspec checksum: $podspec_checksum" >&2

    # Calculate current GitHub checksum
    local zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod_name}-${version}.zip"
    local github_checksum
    if ! github_checksum=$(calculate_checksum_from_github "$zip_url" "$pod_name" "$version" 2>/dev/null); then
        log::error "PODSPEC" "Failed to calculate GitHub checksum for verification" >&2
        return 1
    fi

    log::debug "PODSPEC" "GitHub checksum:  $github_checksum" >&2

    # Compare
    if [[ "$podspec_checksum" == "$github_checksum" ]]; then
        log::success "PODSPEC" "✓ Checksum verified: $pod_name" >&2
        log::info "PODSPEC" "Checksum: $podspec_checksum" >&2
        return 0
    else
        log::error "PODSPEC" "✗ Checksum MISMATCH: $pod_name" >&2
        log::error "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        log::error "PODSPEC" "Podspec checksum:  $podspec_checksum" >&2
        log::error "PODSPEC" "GitHub checksum:   $github_checksum" >&2
        log::error "PODSPEC" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        log::error "PODSPEC" "This indicates the podspec was generated before GitHub Release was ready" >&2
        log::error "PODSPEC" "Or the GitHub Release zip was modified after podspec generation" >&2
        log::error "PODSPEC" "" >&2
        log::error "PODSPEC" "Action required: Regenerate podspec with current GitHub checksum" >&2
        return 1
    fi
}

# ============================================================================
# Usage
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $0 <POD_NAME> <VERSION>

Generate release podspec with binary XCFramework paths.

Arguments:
  POD_NAME    Pod module name (e.g., MSPSharedLibraries)
  VERSION     Release version (e.g., 0.8.8-real.1)

Example:
  $0 MSPSharedLibraries 0.8.8-real.1

Environment:
  ROOT_DIR    Repository root (auto-detected)

Output:
  Build/ReleasePodspecs/<POD_NAME>.podspec
EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

if [[ $# -lt 2 ]]; then
    show_usage
    exit 1
fi

POD_NAME="$1"
VERSION="$2"

# ============================================================================
# Validate Inputs
# ============================================================================

SOURCE_PODSPEC="$ROOT_DIR/${POD_NAME}.podspec"

if [[ ! -f "$SOURCE_PODSPEC" ]]; then
    log::error "PODSPEC" "Source podspec not found: $SOURCE_PODSPEC"
    exit 1
fi

# Check if this pod uses binary distribution (HTTP zip source)
if is_binary_distribution "$POD_NAME"; then
    # Binary distribution pods require XCFrameworks
    # Handle different cases:
    # 1. NovaAdapter: XCFrameworks in Binary/ directory (in zip)
    # 2. New adapters: XCFrameworks built by build-adapters.sh
    # 3. Core pods: Pre-built XCFrameworks required
    case "$POD_NAME" in
        MSPNovaAdapter)
            log::info "PODSPEC" "Binary distribution pod: $POD_NAME (XCFrameworks in Binary/)"
            ;;
        MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|MSPAmazonAdapter|MSPMolocoAdapter|MSPLiftoffAdapter)
            # XCFramework name matches pod name (unified naming)
            XCFRAMEWORK_PATH="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${POD_NAME}.xcframework"
            if [[ -d "$XCFRAMEWORK_PATH" ]]; then
                log::info "PODSPEC" "Binary distribution pod: $POD_NAME (XCFramework found: ${POD_NAME}.xcframework)"
            else
                log::error "PODSPEC" "XCFramework not found: $XCFRAMEWORK_PATH"
                log::error "PODSPEC" "Run: ./Scripts/xcframeworks/build-adapters.sh"
                exit 1
            fi
            ;;
        *)
            # XCFramework name matches pod name (unified naming)
            XCFRAMEWORK_PATH="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${POD_NAME}.xcframework"
            if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
                log::error "PODSPEC" "XCFramework not found: $XCFRAMEWORK_PATH"
                log::error "PODSPEC" "Run pre-release setup (Step 0) first"
                exit 1
            fi
            log::info "PODSPEC" "Binary distribution pod: $POD_NAME (XCFramework validated)"
            ;;
    esac
else
    # Source distribution pods (git+tag source, no XCFramework required)
    log::info "PODSPEC" "Source distribution pod detected: $POD_NAME (git+tag source, skipping XCFramework check)"
fi

# ============================================================================
# Generate Release Podspec
# ============================================================================

log::info "PODSPEC" "Generating release podspec for $POD_NAME v$VERSION"

# Create output directory
mkdir -p "$GENERATED_PODSPECS_DIR"

OUTPUT_PODSPEC="$GENERATED_PODSPECS_DIR/${POD_NAME}.podspec"

# ============================================================================
# Extract metadata from source podspec using awk/sed
# ============================================================================

log::info "PODSPEC" "Parsing source podspec: $SOURCE_PODSPEC"

# Extract key metadata fields from source podspec
extract_field() {
    local field="$1"
    local file="$2"
    grep -m 1 "spec\\.${field}" "$file" || true
}

# Start writing the podspec
cat > "$OUTPUT_PODSPEC" <<'EOF_HEADER'
Pod::Spec.new do |spec|

EOF_HEADER

# Extract and write metadata fields
{
    extract_field "name" "$SOURCE_PODSPEC"
    extract_field "summary" "$SOURCE_PODSPEC"
    extract_field "description" "$SOURCE_PODSPEC"
    extract_field "homepage" "$SOURCE_PODSPEC"
    extract_field "license" "$SOURCE_PODSPEC"
    extract_field "author" "$SOURCE_PODSPEC"
    extract_field "platform" "$SOURCE_PODSPEC"
    extract_field "ios\\.deployment_target" "$SOURCE_PODSPEC"
    extract_field "swift_version" "$SOURCE_PODSPEC"
    extract_field "requires_arc" "$SOURCE_PODSPEC"
    extract_field "static_framework" "$SOURCE_PODSPEC"
} | grep -v "^\s*#" >> "$OUTPUT_PODSPEC"

# ═══════════════════════════════════════════════════════════════════════════
# Extract and clean pod_target_xcconfig (fix for binary distribution issues)
# ═══════════════════════════════════════════════════════════════════════════
# Fixes:
# 1. Remove BUILD_LIBRARY_FOR_DISTRIBUTION: NO (binary frameworks are YES)
# 2. Remove SWIFT_INCLUDE_PATHS override (let CocoaPods auto-handle dependencies)
# 3. Keep only necessary configs (DEFINES_MODULE, VALID_ARCHS, FRAMEWORK_SEARCH_PATHS)
# ═══════════════════════════════════════════════════════════════════════════

# Extract pod_target_xcconfig to temp file for processing
TEMP_XCCONFIG=$(mktemp)
awk '
/spec\.pod_target_xcconfig/ {
    print
    if ($0 ~ /\{/ && $0 !~ /\}/) {
        in_block = 1
        next
    }
}
in_block {
    print
    if ($0 ~ /\}/) {
        in_block = 0
    }
}
' "$SOURCE_PODSPEC" > "$TEMP_XCCONFIG"

# Clean up pod_target_xcconfig: remove problematic configs
if [[ -s "$TEMP_XCCONFIG" ]]; then
    # Remove BUILD_LIBRARY_FOR_DISTRIBUTION, SWIFT_EMIT_MODULE_INTERFACE, SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT
    # Remove old SWIFT_INCLUDE_PATHS (will add correct one for release mode)
    # Remove FRAMEWORK_SEARCH_PATHS (dev mode path doesn't exist in lint env, vendored_frameworks handles paths)
    # Keep: DEFINES_MODULE, VALID_ARCHS
    sed -i '' \
        -e "/'BUILD_LIBRARY_FOR_DISTRIBUTION'/d" \
        -e "/\"BUILD_LIBRARY_FOR_DISTRIBUTION\"/d" \
        -e "/'SWIFT_EMIT_MODULE_INTERFACE'/d" \
        -e "/\"SWIFT_EMIT_MODULE_INTERFACE\"/d" \
        -e "/'SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT'/d" \
        -e "/\"SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT\"/d" \
        -e "/'SWIFT_INCLUDE_PATHS'/d" \
        -e "/\"SWIFT_INCLUDE_PATHS\"/d" \
        -e "/'FRAMEWORK_SEARCH_PATHS'/d" \
        -e "/\"FRAMEWORK_SEARCH_PATHS\"/d" \
        "$TEMP_XCCONFIG"

    # Write cleaned config to output
    cat "$TEMP_XCCONFIG" >> "$OUTPUT_PODSPEC"

    # FIX: Add SWIFT_INCLUDE_PATHS to pod_target_xcconfig for swiftinterface validation
    # This is needed because Xcode validates swiftinterface in pod target context
    sed -i '' "s/spec\.pod_target_xcconfig = {/spec.pod_target_xcconfig = {\n    'SWIFT_INCLUDE_PATHS' => '\$(inherited) \$(PODS_CONFIGURATION_BUILD_DIR)',/" "$OUTPUT_PODSPEC"
    log::info "PODSPEC" "Cleaned pod_target_xcconfig: removed old SWIFT_INCLUDE_PATHS, added release-mode SWIFT_INCLUDE_PATHS"
else
    # No pod_target_xcconfig found, create minimal one for binary distribution pods
    if is_binary_distribution "$POD_NAME"; then
        # Note: FRAMEWORK_SEARCH_PATHS removed - vendored_frameworks handles paths automatically
        # The old path $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks was for dev mode and doesn't exist in lint env
        cat >> "$OUTPUT_PODSPEC" <<'EOF_XCCONFIG'
  spec.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_CONFIGURATION_BUILD_DIR)',
    'DEFINES_MODULE' => 'YES',
  }
EOF_XCCONFIG
        log::info "PODSPEC" "Added minimal pod_target_xcconfig for binary distribution pod (with SWIFT_INCLUDE_PATHS)"
    fi
fi
rm -f "$TEMP_XCCONFIG"

# Extract user_target_xcconfig (keep as-is, but clean SWIFT_INCLUDE_PATHS if present)
TEMP_USER_XCCONFIG=$(mktemp)
awk '
/spec\.user_target_xcconfig/ {
    print
    if ($0 ~ /\{/ && $0 !~ /\}/) {
        in_block = 1
        next
    }
}
in_block {
    print
    if ($0 ~ /\}/) {
        in_block = 0
    }
}
' "$SOURCE_PODSPEC" > "$TEMP_USER_XCCONFIG"

if [[ -s "$TEMP_USER_XCCONFIG" ]]; then
    # Remove SWIFT_INCLUDE_PATHS and FRAMEWORK_SEARCH_PATHS from user_target_xcconfig
    # FRAMEWORK_SEARCH_PATHS points to dev paths that don't exist in lint env
    sed -i '' \
        -e "/'SWIFT_INCLUDE_PATHS'/d" \
        -e "/\"SWIFT_INCLUDE_PATHS\"/d" \
        -e "/'FRAMEWORK_SEARCH_PATHS'/d" \
        -e "/\"FRAMEWORK_SEARCH_PATHS\"/d" \
        "$TEMP_USER_XCCONFIG"
    cat "$TEMP_USER_XCCONFIG" >> "$OUTPUT_PODSPEC"
fi
rm -f "$TEMP_USER_XCCONFIG"

# ═══════════════════════════════════════════════════════════════════════════
# Extract dependencies and detect missing imports from swiftinterface
# ═══════════════════════════════════════════════════════════════════════════

# Function to extract imports from swiftinterface files
extract_swiftinterface_imports() {
    local xcframework_path="$1"
    local pod_name="$2"
    
    if [[ ! -d "$xcframework_path" ]]; then
        return 0
    fi
    
    # System modules to skip (common iOS/Swift system modules)
    local system_modules="Foundation|Swift|UIKit|_Concurrency|_StringProcessing|_SwiftConcurrencyShims|os|Darwin|ObjectiveC|Dispatch|CoreFoundation|CoreGraphics|QuartzCore|AVFoundation|AVKit|WebKit|StoreKit|SystemConfiguration|Security|CFNetwork|MobileCoreServices|ImageIO|Accelerate|Metal|MetalKit|SceneKit|SpriteKit|GameplayKit|ModelIO|CoreML|Vision|NaturalLanguage|Speech|MediaPlayer|MediaAccessibility|MapKit|CoreLocation|CoreMotion|HealthKit|HomeKit|LocalAuthentication|PassKit|QuickLook|SafariServices|Social|Twitter|WatchConnectivity|WatchKit|UserNotifications|Intents|IntentsUI|CallKit|Contacts|ContactsUI|EventKit|EventKitUI|MessageUI|MultipeerConnectivity|NetworkExtension|NotificationCenter|Photos|PhotosUI|ReplayKit|VideoSubscriberAccount|iAd|AdSupport|JavaScriptCore|GLKit|OpenGLES|OpenAL|AudioToolbox|AudioUnit|CoreAudio|CoreMedia|CoreVideo|CoreText|CoreData|CloudKit|CoreSpotlight|CoreTelephony|ExternalAccessory|GameController|GSS|IOKit|IOSurface|IOText|IOBluetooth|IOBluetoothUI|IOHIDFamily|libkern|libresolv|libsystem|libxpc|mach"
    
    # Find all swiftinterface files and extract imports
    local temp_imports=$(mktemp)
    
    while IFS= read -r -d '' swiftinterface_file; do
        # Extract non-system imports
        grep "^import " "$swiftinterface_file" 2>/dev/null | \
            grep -vE "import (${system_modules})" | \
            sed 's/^import //' | \
            sed 's/[[:space:]]*$//' >> "$temp_imports" 2>/dev/null || true
    done < <(find "$xcframework_path" -name "*.swiftinterface" -type f -print0 2>/dev/null)
    
    # Filter out empty lines and the pod itself, then return unique imports
    if [[ -f "$temp_imports" ]] && [[ -s "$temp_imports" ]]; then
        grep -v "^${pod_name}$" "$temp_imports" | grep -v "^$" | sort -u
        rm -f "$temp_imports"
    else
        rm -f "$temp_imports"
    fi
}

get_prebidmobile_version() {
    local plist_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/PrebidMobile.xcframework/ios-arm64/PrebidMobile.framework/Info.plist"
    local version=""

    if [[ -f "$plist_path" ]]; then
        version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist_path" 2>/dev/null || true)
        if [[ -z "$version" ]]; then
            version=$(plutil -p "$plist_path" 2>/dev/null | awk -F'=> ' '/CFBundleShortVersionString/ {gsub(/[\" ]/,"",$2); print $2; exit}')
        fi
    fi

    echo "$version"
}

# Extract dependencies from source podspec
if [[ "$POD_NAME" == "MSPNovaAdapter" ]]; then
    # Filter out NovaCore (vendored), MSPSnapKit (provided via MSPSharedLibraries), and MSPKingfisher
    # IMPORTANT: NovaCore binary already statically links Kingfisher in release artifacts.
    # Adding a public Kingfisher dependency would introduce a second copy and can cause runtime conflicts.
    grep "spec\\.dependency" "$SOURCE_PODSPEC" | grep -vE "(NovaCore|MSPKingfisher|Lottie|MSPSnapKit)" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
elif [[ "$POD_NAME" == "MSPMolocoAdapter" ]]; then
    # Keep MolocoSDK and MSP deps; MSPSnapKit is provided via MSPSharedLibraries in release
    grep "spec\\.dependency" "$SOURCE_PODSPEC" | grep -vE "MSPSnapKit" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
elif is_binary_distribution "$POD_NAME"; then
    # Binary distribution pods: keep all dependencies
    grep "spec\\.dependency" "$SOURCE_PODSPEC" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
else
    # Source distribution pods: keep all dependencies (including MSPiOSCore, which is now a separate pod)
    grep "spec\\.dependency" "$SOURCE_PODSPEC" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
fi

# If MSPSnapKit is supplied by MSPSharedLibraries, remove direct dependency to avoid duplicates.
if should_strip_mspsnapkit_dependency "$POD_NAME"; then
    sed -i '' "/spec\\.dependency.*['\"]MSPSnapKit['\"]/d" "$OUTPUT_PODSPEC"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Detect missing dependencies from swiftinterface imports (for binary pods)
# ═══════════════════════════════════════════════════════════════════════════
if is_binary_distribution "$POD_NAME"; then
    # Find XCFramework path
    xcframework_path=""
    case "$POD_NAME" in
        MSPNovaAdapter)
            xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/Binary/MSPNovaAdapter.xcframework"
            ;;
        MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|MSPAmazonAdapter|MSPMolocoAdapter|MSPLiftoffAdapter)
            xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${POD_NAME}.xcframework"
            ;;
        *)
            xcframework_path="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks/${POD_NAME}.xcframework"
            ;;
    esac
    
    if [[ -d "$xcframework_path" ]]; then
        log::info "PODSPEC" "Scanning swiftinterface files for missing dependencies..."
        
        # Extract imports from swiftinterface
        missing_imports=""
        missing_imports=$(extract_swiftinterface_imports "$xcframework_path" "$POD_NAME")
        
        if [[ -n "$missing_imports" ]]; then
            # Check each import against declared dependencies
            while IFS= read -r import_module; do
                if [[ -z "$import_module" ]]; then
                    continue
                fi
                
                # Check if dependency is already declared
                if ! grep -q "spec\\.dependency.*['\"]${import_module}['\"]" "$OUTPUT_PODSPEC" 2>/dev/null; then
                    case "$import_module" in
                        PrebidMobile)
                            prebidmobile_version="$(get_prebidmobile_version)"
                            if [[ -z "$prebidmobile_version" ]]; then
                                prebidmobile_version="2.0.4"
                                log::warn "PODSPEC" "PrebidMobile version not found; defaulting to $prebidmobile_version (vendored)"
                            fi

                            if grep -q "spec\\.dependency.*['\"]MSPSharedLibraries['\"]" "$OUTPUT_PODSPEC" 2>/dev/null || [[ "$POD_NAME" == "MSPSharedLibraries" ]]; then
                                log::info "PODSPEC" "PrebidMobile import satisfied by vendored XCFramework via MSPSharedLibraries (version: $prebidmobile_version); skipping pod dependency to avoid duplicate embed"
                            else
                                log::warn "PODSPEC" "PrebidMobile import detected but MSPSharedLibraries dependency missing; expected vendored PrebidMobile.xcframework to supply the module"
                                log::warn "PODSPEC" "Please add MSPSharedLibraries as the dependency instead of a direct PrebidMobile pod"
                            fi
                            ;;
                        MSPSnapKit)
                            if should_strip_mspsnapkit_dependency "$POD_NAME"; then
                                log::info "PODSPEC" "MSPSnapKit import satisfied by MSPSharedLibraries for $POD_NAME; skipping pod dependency"
                            else
                                log::warn "PODSPEC" "Missing dependency detected in swiftinterface: $import_module"
                                log::warn "PODSPEC" "MSPSnapKit should be vendored via MSPSharedLibraries; skipping pod dependency"
                            fi
                            ;;
                        Kingfisher)
                            if should_skip_kingfisher_dependency "$POD_NAME"; then
                                log::info "PODSPEC" "Kingfisher import satisfied by embedded NovaCore for $POD_NAME; skipping pod dependency"
                            else
                                log::warn "PODSPEC" "Missing dependency detected in swiftinterface: $import_module"
                                log::info "PODSPEC" "Adding Kingfisher dependency (required by swiftinterface)"
                                echo "  spec.dependency 'Kingfisher', '7.12.0'" >> "$OUTPUT_PODSPEC"
                            fi
                            ;;
                        *)
                            log::warn "PODSPEC" "Missing dependency detected in swiftinterface: $import_module"
                            log::warn "PODSPEC" "Unknown import module: $import_module (may need manual dependency addition)"
                            ;;
                    esac
                fi
            done <<< "$missing_imports"
        fi
        
    else
        log::debug "PODSPEC" "XCFramework not found at $xcframework_path, skipping swiftinterface import check"
    fi
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CRITICAL FIX: Add user_target_xcconfig for ALL binary distribution pods
    # ═══════════════════════════════════════════════════════════════════════════
    # Why user_target_xcconfig instead of pod_target_xcconfig:
    # - pod_target_xcconfig only affects the pod's own target
    # - Xcode validates swiftinterface using the consumer project's context
    # - user_target_xcconfig affects all targets that use this pod, including validation
    # - This ensures module search paths are available during swiftinterface validation
    # ═══════════════════════════════════════════════════════════════════════════
    # Check if user_target_xcconfig already exists and has SWIFT_INCLUDE_PATHS
    if grep -q "spec\\.user_target_xcconfig" "$OUTPUT_PODSPEC" 2>/dev/null; then
        # user_target_xcconfig exists, check if SWIFT_INCLUDE_PATHS is present
        if ! grep -A 10 "spec\\.user_target_xcconfig" "$OUTPUT_PODSPEC" | grep -q "SWIFT_INCLUDE_PATHS" 2>/dev/null; then
            # user_target_xcconfig exists but missing SWIFT_INCLUDE_PATHS, add it
            log::info "PODSPEC" "Adding SWIFT_INCLUDE_PATHS to existing user_target_xcconfig (required for swiftinterface validation)"
            sed -i '' "s/spec\.user_target_xcconfig = {/spec.user_target_xcconfig = {\n    'SWIFT_INCLUDE_PATHS' => '\$(inherited) \$(PODS_CONFIGURATION_BUILD_DIR)',/" "$OUTPUT_PODSPEC"
        else
            log::debug "PODSPEC" "user_target_xcconfig already contains SWIFT_INCLUDE_PATHS"
        fi
    else
        # user_target_xcconfig doesn't exist, create new one
        # This is REQUIRED for all binary distribution pods to ensure swiftinterface validation works
        log::info "PODSPEC" "Adding user_target_xcconfig with SWIFT_INCLUDE_PATHS (required for swiftinterface validation)"
        cat >> "$OUTPUT_PODSPEC" <<'EOF_USER_XCCONFIG'
  spec.user_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_CONFIGURATION_BUILD_DIR)',
  }
EOF_USER_XCCONFIG
        log::info "PODSPEC" "Added user_target_xcconfig for swiftinterface validation (affects all consumer targets)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# DEPENDENCY VERSION ALIGNMENT (aligned with legacy update_adapter_podspec_dependencies)
# ═══════════════════════════════════════════════════════════════════════════
# Legacy script logic (publish.sh:336-360):
#   - MSPSharedLibraries → add version
#   - PrebidAdapter → add version (now MSPPrebidAdapter)
#   - MSPOMSDK → keep without version
#
# New architecture extensions:
#   - MSPiOSCore → add version (new independent module)
#   - MSPSharedLibraries → add version (align with legacy)
#   - MSPPrebidAdapter → add version (align with legacy, renamed from PrebidAdapter)
#
# For pre-release versions (contains -rc, -alpha, -beta):
#   CocoaPods REQUIRES explicit version for pre-release dependencies
#
# For stable versions:
#   Add version for consistency and dependency locking
# ═══════════════════════════════════════════════════════════════════════════

# Always add version numbers to MSP internal dependencies (aligned with legacy behavior)
if grep -qE "spec\\.dependency.*'($MSP_VERSIONED_DEPS_PATTERN)'" "$OUTPUT_PODSPEC"; then
    log::info "PODSPEC" "Adding version numbers to MSP internal dependencies (version: $VERSION)"
    
    # Transform dependency declarations (aligned with legacy update_adapter_podspec_dependencies):
    #   spec.dependency 'MSPiOSCore'          → spec.dependency 'MSPiOSCore', '$VERSION'
    #   spec.dependency 'MSPSharedLibraries'  → spec.dependency 'MSPSharedLibraries', '$VERSION'
    #   spec.dependency 'MSPPrebidAdapter'    → spec.dependency 'MSPPrebidAdapter', '$VERSION'
    #   spec.dependency 'PrebidAdapter'       → spec.dependency 'PrebidAdapter', '$VERSION' (legacy name)
    #   spec.dependency 'MSPGoogleAdsTypes'   → spec.dependency 'MSPGoogleAdsTypes', '$VERSION'
    
    # Step 1: Remove any existing version constraints first (cleanup, aligned with legacy)
    sed -i "" -E "s/(spec\\.dependency[[:space:]]+'($MSP_VERSIONED_DEPS_PATTERN)')[^#\n]*/\\1/g" "$OUTPUT_PODSPEC"
    
    # Step 2: Add the new version (ensures consistency)
    sed -i "" -E "s/(spec\\.dependency[[:space:]]+'($MSP_VERSIONED_DEPS_PATTERN)')/\\1, '$VERSION'/g" "$OUTPUT_PODSPEC"
    
    log::success "PODSPEC" "Updated MSP internal dependencies to version $VERSION"
fi

# Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
# No longer need to handle MSPOMSDK dependency

# Add release-specific configuration
# Binary distribution vs Source distribution: Different source strategies
if is_binary_distribution "$POD_NAME"; then
    # ═══════════════════════════════════════════════════════════════
    # BINARY DISTRIBUTION PODS: HTTP binary zip distribution
    # Used by: release tier AND test tier (both use real distribution)
    # ═══════════════════════════════════════════════════════════════
    zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${VERSION}/${POD_NAME}-${VERSION}.zip"

    # Calculate SHA256 checksum from actual zip file
    log::info "PODSPEC" "Calculating SHA256 checksum for $POD_NAME-$VERSION.zip..."
    
    # FIX: 只捕获 stdout，忽略 stderr（双重保险）
    zip_checksum=$(calculate_zip_sha256 "$zip_url" "$POD_NAME" "$VERSION" 2>/dev/null)

    # FIX: 验证 checksum 格式（防止日志污染）
    if [[ -z "$zip_checksum" ]]; then
        log::error "PODSPEC" "Failed to calculate checksum for $POD_NAME"
        log::error "PODSPEC" "Zip file not accessible:"
        log::error "PODSPEC" "  GitHub Release: $zip_url"
        log::error "PODSPEC" "  Local Build:    $ROOT_DIR/Build/Zips/${POD_NAME}-${VERSION}.zip"
        log::error "PODSPEC" ""
        log::error "PODSPEC" "CRITICAL: Binary distribution pods MUST have SHA256 checksum for CocoaPods validation"
        log::error "PODSPEC" "Please ensure:"
        log::error "PODSPEC" "  1. XCFramework is built: Build/ReleaseArtifacts/XCFrameworks/${POD_NAME}.xcframework"
        log::error "PODSPEC" "  2. Zip is created and uploaded to GitHub Release"
        log::error "PODSPEC" "  3. Or run: Scripts/release/package_and_upload.sh $POD_NAME $VERSION"
        exit 1
    fi

    # FIX: 清理 checksum：移除所有非十六进制字符（防止日志污染）
    zip_checksum=$(echo "$zip_checksum" | tr -d '[:space:]' | grep -oE '^[0-9a-f]{64}$' || echo "")

    # FIX: 再次验证格式
    if [[ -z "$zip_checksum" ]] || [[ ! "$zip_checksum" =~ ^[0-9a-f]{64}$ ]]; then
        log::error "PODSPEC" "Invalid checksum format for $POD_NAME: '$zip_checksum'"
        log::error "PODSPEC" "Checksum must be exactly 64 hexadecimal characters"
        log::error "PODSPEC" "This may indicate that log output was mixed with checksum value"
        log::error "PODSPEC" "Please check calculate_zip_sha256() function for log output redirection"
        exit 1
    fi

    if [[ -n "$zip_checksum" ]]; then
        log::success "PODSPEC" "SHA256 calculated: $zip_checksum"

        # Generate spec.source with checksum
        cat >> "$OUTPUT_PODSPEC" <<EOF_RELEASE

  # ═══════════════════════════════════════════════════════════════════════════
  # GENERATED FOR RELEASE (Binary Distribution - HTTP Zip)
  # Generated by: Scripts/release/generate_podspec.sh
  # Phase B: Unified tier architecture - checksum always from GitHub Release CDN
  # HTTP zip source: Real distribution format (used by all modes)
  # SHA256: Auto-calculated from GitHub Release CDN (source of truth)
  # ═══════════════════════════════════════════════════════════════════════════

  spec.version = "$VERSION"

  spec.source = {
    :http => "$zip_url",
    :type => "zip",
    :sha256 => "$zip_checksum"
  }

EOF_RELEASE
    else
        log::error "PODSPEC" "Failed to calculate SHA256 checksum for $POD_NAME"
        log::error "PODSPEC" "Zip file not accessible:"
        log::error "PODSPEC" "  GitHub Release: $zip_url"
        log::error "PODSPEC" "  Local Build:    $ROOT_DIR/Build/Zips/${POD_NAME}-${VERSION}.zip"
        log::error "PODSPEC" ""
        log::error "PODSPEC" "CRITICAL: Binary distribution pods MUST have SHA256 checksum for CocoaPods validation"
        log::error "PODSPEC" "Please ensure:"
        log::error "PODSPEC" "  1. XCFramework is built: Build/ReleaseArtifacts/XCFrameworks/${POD_NAME}.xcframework"
        log::error "PODSPEC" "  2. Zip is created and uploaded to GitHub Release"
        log::error "PODSPEC" "  3. Or run: Scripts/release/package_and_upload.sh $POD_NAME $VERSION"
        exit 1
    fi
else
    # ═══════════════════════════════════════════════════════════════
    # ADAPTERS: Git+tag source distribution (source-based)
    # ═══════════════════════════════════════════════════════════════
    cat >> "$OUTPUT_PODSPEC" <<EOF_RELEASE

  # ═══════════════════════════════════════════════════════════════════════════
  # GENERATED FOR RELEASE (Source Distribution - Git Tag)
  # Generated by: Scripts/release/generate_podspec.sh
  # Phase B: Unified tier architecture
  # Adapters are source-based per architecture (README.md)
  # ═══════════════════════════════════════════════════════════════════════════

  spec.version = "$VERSION"

  spec.source = {
    git: "https://github.com/ParticleMedia/msp-ios-sdk-public.git",
    tag: spec.version.to_s
  }

EOF_RELEASE
fi

# Add vendored_frameworks for binary distribution pods, source_files for source distribution pods
if is_binary_distribution "$POD_NAME"; then
    # Binary distribution pods: binary XCFrameworks
    if [[ "$POD_NAME" == "MSPSharedLibraries" ]]; then
        # MSPSharedLibraries: includes PrebidMobile, MSPSnapKit, Kingfisher, and OMSDK
        # Kingfisher is required because NovaCore statically embeds Kingfisher code but consumers still need
        # the Kingfisher module for Swift's type system to resolve Kingfisher types at link time
        # OMSDK_Newsbreak1 is unified here to avoid duplicate classes with PrebidMobile
        cat >> "$OUTPUT_PODSPEC" <<'EOF_VENDOR_MULTI'
  spec.vendored_frameworks = [
    "Binary/MSPSharedLibraries.xcframework",
    "ThirdParty/PrebidMobile/PrebidMobile.xcframework",
    "ThirdParty/MSPSnapKit/MSPSnapKit.xcframework",
    "Sources/Core/ThirdParty/Kingfisher/Kingfisher.xcframework",
    "ThirdParty/OMSDK/OMSDK_Newsbreak1.xcframework"
  ]
EOF_VENDOR_MULTI
    elif [[ "$POD_NAME" == "MSPNovaAdapter" ]]; then
        # NovaAdapter: pure binary distribution with embedded NovaCore
        # OMSDK_Newsbreak1 is now provided by MSPSharedLibraries (deduplication)
        # NovaCore uses AVFoundation/AVFAudio which depend on AudioToolbox/CoreAudio
        # CoreAudioTypes was removed from iOS SDK 18+ - types are now available via CoreAudio/AudioToolbox
        # NOTE: SnapKit is provided via MSPSharedLibraries dependency (MSPSnapKit.xcframework)
        #       Do NOT bundle SnapKit separately here to avoid duplicate symbol issues
        cat >> "$OUTPUT_PODSPEC" <<'EOF_VENDOR_NOVA'
  spec.vendored_frameworks = [
    "Binary/MSPNovaAdapter.xcframework",
    "Binary/NovaCore.xcframework"
  ]
  spec.frameworks = 'AVFoundation', 'AVFAudio', 'AudioToolbox', 'CoreAudio'
EOF_VENDOR_NOVA
    elif [[ "$POD_NAME" == "MSPCore" ]]; then
        # MSPCore: binary XCFramework + resource bundle for Config.plist
        # Config.plist is extracted from the framework to Resources/ so CocoaPods
        # can build MSPCoreResources.bundle for the consumer app.
        # Without this, getMSPVersion() returns "" because static_framework
        # causes Bundle(for: MSP.self) to resolve to the main app bundle.
        cat >> "$OUTPUT_PODSPEC" <<'EOF_VENDOR_MSPCORE'
  spec.vendored_frameworks = "Binary/MSPCore.xcframework"
  spec.resource_bundles = {
    'MSPCoreResources' => ['Resources/Config.plist']
  }
EOF_VENDOR_MSPCORE
    else
        # XCFramework name matches pod name (unified naming)
        cat >> "$OUTPUT_PODSPEC" <<EOF_VENDOR_SINGLE
  spec.vendored_frameworks = "Binary/${POD_NAME}.xcframework"
EOF_VENDOR_SINGLE
    fi
else
    # Adapters: source-based distribution (extract source_files from source podspec)
    log::info "PODSPEC" "Adapter detected: extracting source_files from source podspec"
    
    # Extract source_files pattern from source podspec
    # Look for source_files in development mode section
    if grep -q "spec.source_files" "$SOURCE_PODSPEC"; then
        # Extract the source_files line(s) from the source podspec
        # This handles both single-line and multi-line patterns
        awk '
        /spec\.source_files/ {
            print
            if ($0 ~ /\[/ && $0 !~ /\]/) {
                in_array = 1
                next
            }
        }
        in_array {
            print
            if ($0 ~ /\]/) {
                in_array = 0
            }
        }
        ' "$SOURCE_PODSPEC" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
    else
        # Fallback: construct source_files pattern based on adapter name
        # Standard pattern: Sources/Adapters/{AdapterName}/{AdapterName}/**/*.swift
        cat >> "$OUTPUT_PODSPEC" <<EOF_SOURCE_FILES
  spec.source_files = "Sources/Adapters/${POD_NAME}/${POD_NAME}/**/*.swift"
EOF_SOURCE_FILES
    fi
fi

# Close the podspec
cat >> "$OUTPUT_PODSPEC" <<'EOF_FOOTER'

end
EOF_FOOTER

log::success "PODSPEC" "Generated release podspec: $OUTPUT_PODSPEC"
log::info "PODSPEC" "Location: $OUTPUT_PODSPEC"

# ============================================================================
# Validation
# ============================================================================

log::info "PODSPEC" "Validating generated podspec structure..."

if ! grep -q "spec.version.*$VERSION" "$OUTPUT_PODSPEC"; then
    log::error "PODSPEC" "Generated podspec missing correct version"
    exit 1
fi

# Validate podspec structure based on distribution method
if is_binary_distribution "$POD_NAME"; then
    # Core modules must have vendored_frameworks
    if ! grep -q "spec.vendored_frameworks" "$OUTPUT_PODSPEC"; then
        log::error "PODSPEC" "Generated podspec missing vendored_frameworks (core module)"
        exit 1
    fi
else
    # Adapters: check if NovaAdapter (special case: pure binary distribution)
    if [[ "$POD_NAME" == "MSPNovaAdapter" ]]; then
        # NovaAdapter: must have vendored_frameworks only (no source_files)
        if ! grep -q "spec.vendored_frameworks" "$OUTPUT_PODSPEC"; then
            log::error "PODSPEC" "Generated podspec missing vendored_frameworks (NovaAdapter)"
            exit 1
        fi
        if grep -q "spec.source_files" "$OUTPUT_PODSPEC"; then
            log::error "PODSPEC" "Generated podspec should not have source_files (NovaAdapter is pure binary)"
            exit 1
        fi
    else
        # Other adapters must have source_files
        if ! grep -q "spec.source_files" "$OUTPUT_PODSPEC"; then
            log::error "PODSPEC" "Generated podspec missing source_files (adapter)"
            exit 1
        fi
    fi
fi

# Validate source format based on distribution method (all tiers use same format)
if is_binary_distribution "$POD_NAME"; then
    # Binary distribution pods: HTTP binary zip source (all tiers)
    if ! grep -qE "spec.source.*:http|:http =>" "$OUTPUT_PODSPEC"; then
        log::error "PODSPEC" "Generated podspec missing HTTP zip source (binary distribution pod)"
        exit 1
    fi
else
    # Source distribution pods: git+tag source (all tiers)
    if ! grep -qE "git:|:git =>" "$OUTPUT_PODSPEC"; then
        log::error "PODSPEC" "Generated podspec missing git source (source distribution pod)"
        exit 1
    fi
    log::success "PODSPEC" "Podspec structure validated (git+tag source distribution)"
fi

log::info "PODSPEC" "Next: Run 'pod spec lint $OUTPUT_PODSPEC --allow-warnings' to validate"

exit 0
