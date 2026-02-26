#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
set -euo pipefail

# ============================================================================
# extract_from_pods.sh
# ============================================================================
# Extracts third-party SDK frameworks from Pods/ and converts them into
# valid .xcframework bundles for SPM binaryTarget consumption.
#
# This script:
#   1. Finds framework slices (device + simulator) inside each Pod
#   2. Uses xcodebuild -create-xcframework to produce a real xcframework
#   3. Outputs to ThirdParty/<SDK>/<SDK>.xcframework
#   4. Validates the resulting xcframework has Info.plist
#
# EXCLUDED SDKs:
#   - PrebidMobile: Uses canonical ThirdParty/PrebidMobile/PrebidMobile.xcframework
#   - GoogleMobileAds: SPM-native, no xcframework extraction needed
# ============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PODS_DIR="$ROOT_DIR/Pods"
DEST_DIR="$ROOT_DIR/ThirdParty"

# ============================================================================
# Logging Functions (use unified system if available)
# ============================================================================

# Source unified color/logging system
if [[ -f "$ROOT_DIR/Scripts/lib/common.sh" ]]; then
    # shellcheck source=Scripts/lib/common.sh
    source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
fi

# Use log::* API if available, otherwise fallback to local functions
if command -v log::info &>/dev/null; then
    log()     { log::info "EXTRACT" "$*"; }
    log_ok()  { log::success "EXTRACT" "$*"; }
    log_warn(){ log::warn "EXTRACT" "$*"; }
    log_err() { log::error "EXTRACT" "$*"; }
else
    # Fallback colors and functions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log()     { echo -e "${BLUE}[extract_from_pods]${NC} $*"; }
    log_ok()  { echo -e "${GREEN}[extract_from_pods] ✔${NC} $*"; }
    log_warn(){ echo -e "${YELLOW}[extract_from_pods] ⚠${NC} $*" >&2; }
    log_err() { echo -e "${RED}[extract_from_pods] ✖${NC} $*" >&2; }
fi

# ============================================================================
# SDK Configuration
# ============================================================================
# Format: "SDK_NAME:POD_NAME:FRAMEWORK_NAME"
# Some pods have different framework names than the pod name itself.

SDK_CONFIGS=(
  "FBAudienceNetwork:FBAudienceNetwork:FBAudienceNetwork"
  "IronSourceSDK:IronSourceSDK:IronSource"
  "InMobiSDK:InMobiSDK:InMobiSDK"
  "MobileFuseSDK:MobileFuseSDK:MobileFuseSDK"
  "OpenWrapSDK:OpenWrapSDK:OpenWrapSDK"
  "AmazonPublisherServicesSDK:AmazonPublisherServicesSDK:DTBiOSSDK"
)

# Mintegral has multiple subspecs that need to be extracted separately
# Each subspec is its own xcframework under Pods/MintegralAdSDK/Fmk/
MINTEGRAL_MODULES=(
  "MTGSDK"
  "MTGSDKBidding"
  "MTGSDKBanner"
  "MTGSDKNewInterstitial"
  "MTGSDKInterstitialVideo"
)

# ============================================================================
# Helper Functions
# ============================================================================

# Safety check: ensure path is under ThirdParty/
safe_rm_rf() {
  local target="$1"
  if [[ "$target" != "$DEST_DIR"/* ]]; then
    log_err "SAFETY: Refusing to delete path outside ThirdParty/: $target"
    exit 1
  fi
  if [[ -e "$target" ]]; then
    log "Cleaning: $target"
    rm -rf "$target"
  fi
}

# Find .xcframework directory inside a pod (some pods already provide xcframeworks)
find_xcframework_in_pod() {
  local pod_dir="$1"
  local framework_name="$2"
  
  if [[ ! -d "$pod_dir" ]]; then
    return 1
  fi
  
  # Look for exact xcframework name first
  local exact_match
  exact_match="$(find "$pod_dir" -type d -name "${framework_name}.xcframework" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$exact_match" && -d "$exact_match" ]]; then
    echo "$exact_match"
    return 0
  fi
  
  # Fallback: find any .xcframework
  local any_match
  any_match="$(find "$pod_dir" -type d -name "*.xcframework" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$any_match" && -d "$any_match" ]]; then
    echo "$any_match"
    return 0
  fi
  
  return 1
}

# Validate xcframework has required structure
validate_xcframework() {
  local xcframework_path="$1"
  
  if [[ ! -d "$xcframework_path" ]]; then
    log_err "XCFramework does not exist: $xcframework_path"
    return 1
  fi
  
  if [[ ! -f "$xcframework_path/Info.plist" ]]; then
    log_err "XCFramework missing Info.plist: $xcframework_path"
    return 1
  fi
  
  # Check for at least one slice
  local slice_count
  slice_count=$(find "$xcframework_path" -maxdepth 1 -type d -name "ios-*" | wc -l | tr -d ' ')
  if [[ "$slice_count" -lt 1 ]]; then
    log_err "XCFramework has no iOS slices: $xcframework_path"
    return 1
  fi
  
  return 0
}

# Create xcframework from device and simulator frameworks
create_xcframework() {
  local sdk_name="$1"
  local device_framework="$2"
  local simulator_framework="$3"
  local output_xcframework="$4"
  
  local args=()
  
  if [[ -n "$device_framework" && -d "$device_framework" ]]; then
    args+=(-framework "$device_framework")
  fi
  
  if [[ -n "$simulator_framework" && -d "$simulator_framework" ]]; then
    args+=(-framework "$simulator_framework")
  fi
  
  if [[ ${#args[@]} -eq 0 ]]; then
    log_err "No valid framework slices found for $sdk_name"
    return 1
  fi
  
  args+=(-output "$output_xcframework")
  
  log "Creating xcframework: xcodebuild -create-xcframework ..."
  
  if ! xcodebuild -create-xcframework "${args[@]}" 2>&1; then
    log_err "Failed to create xcframework for $sdk_name"
    return 1
  fi
  
  return 0
}

# Copy existing xcframework (when pod already provides one)
copy_xcframework() {
  local sdk_name="$1"
  local src_xcframework="$2"
  local dest_xcframework="$3"
  
  log "Copying existing xcframework for $sdk_name"
  log "  From: $src_xcframework"
  log "  To:   $dest_xcframework"
  
  cp -R "$src_xcframework" "$dest_xcframework"
  
  return 0
}

# Process a single SDK
process_sdk() {
  local sdk_name="$1"
  local pod_name="$2"
  local framework_name="$3"
  
  local pod_dir="$PODS_DIR/$pod_name"
  local sdk_dest_dir="$DEST_DIR/$sdk_name"
  local output_xcframework="$sdk_dest_dir/${sdk_name}.xcframework"
  
  log "━━━ Processing: $sdk_name (Pod: $pod_name, Framework: $framework_name)"
  
  # Check if pod exists
  if [[ ! -d "$pod_dir" ]]; then
    log::warn "SPM" "Pod directory not found: $pod_dir"
    log::warn "SPM" "Run 'pod install' first, or check SDK_CONFIGS configuration."
    return 1
  fi
  
  # Clean destination directory
  safe_rm_rf "$sdk_dest_dir"
  mkdir -p "$sdk_dest_dir"
  
  # Strategy 1: Check if pod already provides .xcframework
  local existing_xcframework
  existing_xcframework="$(find_xcframework_in_pod "$pod_dir" "$framework_name" || true)"
  
  if [[ -n "$existing_xcframework" ]]; then
    log "Found existing xcframework: $existing_xcframework"
    copy_xcframework "$sdk_name" "$existing_xcframework" "$output_xcframework"
    
    if validate_xcframework "$output_xcframework"; then
      log_ok "Successfully installed $sdk_name (copied existing xcframework)"
      return 0
    else
      log_err "Copied xcframework is invalid for $sdk_name"
      return 1
    fi
  fi
  
  # Strategy 2: Build xcframework from .framework slices
  log "No existing xcframework found. Looking for .framework slices..."
  
  # Look for device framework (typically in a path containing arm64 or iphoneos)
  local device_framework=""
  local simulator_framework=""
  
  # Find all .framework directories
  local frameworks
  frameworks=$(find "$pod_dir" -type d -name "${framework_name}.framework" 2>/dev/null || true)
  
  if [[ -z "$frameworks" ]]; then
    # Try finding any .framework
    frameworks=$(find "$pod_dir" -type d -name "*.framework" 2>/dev/null || true)
  fi
  
  if [[ -z "$frameworks" ]]; then
    log_err "No .framework found in $pod_dir"
    return 1
  fi
  
  # Analyze each framework to determine if it's device or simulator
  while IFS= read -r fw_path; do
    [[ -z "$fw_path" ]] && continue
    
    # Get the binary inside the framework
    local fw_name
    fw_name=$(basename "$fw_path" .framework)
    local binary_path="$fw_path/$fw_name"
    
    if [[ ! -f "$binary_path" ]]; then
      # Try Versions/A/ structure
      binary_path="$fw_path/Versions/A/$fw_name"
    fi
    
    if [[ ! -f "$binary_path" ]]; then
      log::warn "SPM" "No binary found in $fw_path"
      continue
    fi
    
    # Check architectures using lipo
    local archs
    archs=$(lipo -info "$binary_path" 2>/dev/null | sed 's/.*are: //' | sed 's/.*is architecture: //' || true)
    
    log "  Framework: $fw_path"
    log "  Architectures: $archs"
    
    # Determine slice type based on path or architecture
    if [[ "$fw_path" == *"simulator"* ]] || [[ "$fw_path" == *"iphonesimulator"* ]] || [[ "$archs" == *"x86_64"* && "$archs" != *"arm64"* ]]; then
      simulator_framework="$fw_path"
      log "  → Simulator slice"
    elif [[ "$fw_path" == *"device"* ]] || [[ "$fw_path" == *"iphoneos"* ]] || [[ "$archs" == "arm64" ]]; then
      device_framework="$fw_path"
      log "  → Device slice"
    else
      # If only one framework and it's fat, use it as-is
      if [[ -z "$device_framework" ]]; then
        device_framework="$fw_path"
        log "  → Using as device slice (fat binary or unknown)"
      fi
    fi
  done <<< "$frameworks"
  
  # Create xcframework
  if [[ -z "$device_framework" && -z "$simulator_framework" ]]; then
    log_err "Could not identify any valid framework slices for $sdk_name"
    return 1
  fi
  
  if ! create_xcframework "$sdk_name" "$device_framework" "$simulator_framework" "$output_xcframework"; then
    return 1
  fi
  
  # Validate result
  if validate_xcframework "$output_xcframework"; then
    log_ok "Successfully created $sdk_name xcframework"
    return 0
  else
    log_err "Created xcframework is invalid for $sdk_name"
    return 1
  fi
}

# ============================================================================
# Mintegral Multi-Module Extraction
# ============================================================================

process_mintegral_modules() {
  local mintegral_pod_dir="$PODS_DIR/MintegralAdSDK/Fmk"
  local mintegral_dest_dir="$DEST_DIR/MintegralAdSDK"
  
  log ""
  log "━━━ Processing Mintegral Multi-Module SDK"
  
  if [[ ! -d "$mintegral_pod_dir" ]]; then
    log::warn "SPM" "Mintegral Pod directory not found: $mintegral_pod_dir"
    return 1
  fi
  
  # Clean and recreate destination
  safe_rm_rf "$mintegral_dest_dir"
  mkdir -p "$mintegral_dest_dir"
  
  local mintegral_success=0
  local mintegral_fail=0
  
  for module in "${MINTEGRAL_MODULES[@]}"; do
    local src_xcframework="$mintegral_pod_dir/${module}.xcframework"
    local dest_xcframework="$mintegral_dest_dir/${module}.xcframework"
    
    log "  Processing: $module"
    
    if [[ -d "$src_xcframework" ]]; then
      # Copy the xcframework
      cp -R "$src_xcframework" "$dest_xcframework"
      
      # Validate
      if [[ -f "$dest_xcframework/Info.plist" ]]; then
        log_ok "  Installed $module.xcframework"
        ((mintegral_success++)) || true
      else
        log_err "  $module.xcframework missing Info.plist"
        ((mintegral_fail++)) || true
      fi
    else
      log_err "  $module.xcframework not found at $src_xcframework"
      ((mintegral_fail++)) || true
    fi
  done
  
  log ""
  log "  Mintegral modules: $mintegral_success succeeded, $mintegral_fail failed"
  
  if [[ $mintegral_fail -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  log "============================================================================"
  log "ThirdParty SDK XCFramework Extraction"
  log "============================================================================"
  log ""
  log "Repository: $ROOT_DIR"
  log "Pods Dir:   $PODS_DIR"
  log "Output Dir: $DEST_DIR"
  log ""
  
  # Check Pods directory exists
  if [[ ! -d "$PODS_DIR" ]]; then
    log_err "Pods directory not found: $PODS_DIR"
    log_err "Run 'pod install' first."
    exit 1
  fi
  
  mkdir -p "$DEST_DIR"
  
  # Log skipped SDKs
  log "━━━ Skipped SDKs"
  log "Skipping PrebidMobile — using canonical ThirdParty/PrebidMobile/PrebidMobile.xcframework"
  log "Skipping GoogleMobileAds — SPM-native (uses swift-package-manager-google-mobile-ads)"
  log ""
  
  # Process each SDK
  local success_count=0
  local fail_count=0
  local failed_sdks=()
  
  # Process Mintegral multi-module SDK first
  if process_mintegral_modules; then
    ((success_count++)) || true
  else
    ((fail_count++)) || true
    failed_sdks+=("MintegralAdSDK")
  fi
  
  for config in "${SDK_CONFIGS[@]}"; do
    # Parse config: "SDK_NAME:POD_NAME:FRAMEWORK_NAME"
    local sdk_name="${config%%:*}"
    local rest="${config#*:}"
    local pod_name="${rest%%:*}"
    local framework_name="${rest##*:}"
    
    log ""
    if process_sdk "$sdk_name" "$pod_name" "$framework_name"; then
      ((success_count++)) || true
    else
      ((fail_count++)) || true
      failed_sdks+=("$sdk_name")
    fi
  done
  
  # Summary
  log ""
  log "============================================================================"
  log "Extraction Summary"
  log "============================================================================"
  log ""
  log "Successful: $success_count"
  log "Failed:     $fail_count"
  
  if [[ ${#failed_sdks[@]} -gt 0 ]]; then
    log ""
    log::warn "SPM" "Failed SDKs:"
    for sdk in "${failed_sdks[@]}"; do
      log::warn "SPM" "  - $sdk"
    done
  fi
  
  log ""
  log "━━━ Output Directory Contents"
  find "$DEST_DIR" -maxdepth 3 -name "*.xcframework" -type d | sort | while read -r xc; do
    if [[ -f "$xc/Info.plist" ]]; then
      log_ok "$xc"
    else
      log::warn "SPM" "$xc (missing Info.plist)"
    fi
  done
  
  log ""
  if [[ $fail_count -eq 0 ]]; then
    log_ok "All SDK xcframeworks extracted successfully!"
    exit 0
  else
    log_err "Some SDK extractions failed. Check logs above."
    exit 1
  fi
}

main "$@"
