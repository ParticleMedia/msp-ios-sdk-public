#!/bin/bash
# Minimal Podspec Generator for Release Mode Only
#
# Purpose: Generate release podspecs with correct binary paths
# Scope: ONLY used in MSP_RELEASE_TIER=release
# Input: Existing repo podspec + XCFramework paths
# Output: Build/ReleasePodspecs/*.podspec

set -e

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

# ============================================================================
# Configuration
# ============================================================================

# Output directory for generated podspecs
GENERATED_PODSPECS_DIR="$ROOT_DIR/Build/ReleasePodspecs"

# Core modules (binary XCFrameworks) vs Adapters (source-based)
# This classification matches the architecture documented in README.md
# Note: NovaCore is not included here - it's embedded via vendored_frameworks, not published separately
CORE_MODULES=("MSPSharedLibraries" "MSPCore" "MSPiOSCore" "MSPOMSDK")

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
    log_error "Source podspec not found: $SOURCE_PODSPEC"
    exit 1
fi

# Check if this is a core module or adapter
if is_core_module "$POD_NAME"; then
    # Core modules require XCFrameworks (binary distribution)
    XCFRAMEWORK_PATH="$ROOT_DIR/Build/XCFrameworks/${POD_NAME}.xcframework"
    
    if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
        log_error "XCFramework not found: $XCFRAMEWORK_PATH"
        log_error "Run pre-release setup (Step 0) first to build XCFrameworks"
        exit 1
    fi
    log_info "Core module detected: $POD_NAME (binary XCFramework required)"
else
    # Adapters are source-based (no XCFramework required)
    log_info "Adapter detected: $POD_NAME (source-based, skipping XCFramework check)"
fi

# ============================================================================
# Generate Release Podspec
# ============================================================================

log_info "Generating release podspec for $POD_NAME v$VERSION"

# Create output directory
mkdir -p "$GENERATED_PODSPECS_DIR"

OUTPUT_PODSPEC="$GENERATED_PODSPECS_DIR/${POD_NAME}.podspec"

# ============================================================================
# Extract metadata from source podspec using awk/sed
# ============================================================================

log_info "Parsing source podspec: $SOURCE_PODSPEC"

# Extract key metadata fields from source podspec
extract_field() {
    local field="$1"
    local file="$2"
    grep -m 1 "spec\\.${field}" "$file" | head -1
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

# Extract xcconfig (multiline handling)
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
' "$SOURCE_PODSPEC" >> "$OUTPUT_PODSPEC"

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
' "$SOURCE_PODSPEC" >> "$OUTPUT_PODSPEC"

# Extract dependencies
# NovaAdapter: filter out NovaCore, MSPOMSDK, MSPiOSCore dependencies (embedded)
if [[ "$POD_NAME" == "NovaAdapter" ]]; then
    grep "spec\\.dependency" "$SOURCE_PODSPEC" | grep -vE "(NovaCore|MSPOMSDK|MSPiOSCore)" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
elif is_core_module "$POD_NAME"; then
    # Core modules: keep all dependencies
    grep "spec\\.dependency" "$SOURCE_PODSPEC" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
else
    # Other adapters: filter out MSPiOSCore dependency (embedded in MSPSharedLibraries)
    grep "spec\\.dependency" "$SOURCE_PODSPEC" | grep -v "MSPiOSCore" >> "$OUTPUT_PODSPEC" 2>/dev/null || true
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
if grep -qE "spec\\.dependency.*'(MSPiOSCore|MSPSharedLibraries|MSPPrebidAdapter|PrebidAdapter)'" "$OUTPUT_PODSPEC"; then
    log_info "Adding version numbers to MSP internal dependencies (version: $VERSION)"
    
    # Transform dependency declarations (aligned with legacy update_adapter_podspec_dependencies):
    #   spec.dependency 'MSPiOSCore'          → spec.dependency 'MSPiOSCore', '$VERSION'
    #   spec.dependency 'MSPSharedLibraries'  → spec.dependency 'MSPSharedLibraries', '$VERSION'
    #   spec.dependency 'MSPPrebidAdapter'    → spec.dependency 'MSPPrebidAdapter', '$VERSION'
    #   spec.dependency 'PrebidAdapter'       → spec.dependency 'PrebidAdapter', '$VERSION' (legacy name)
    
    # Step 1: Remove any existing version constraints first (cleanup, aligned with legacy)
    sed -i "" -E "s/(spec\\.dependency[[:space:]]+'(MSPiOSCore|MSPSharedLibraries|MSPPrebidAdapter|PrebidAdapter)')[^#\n]*/\\1/g" "$OUTPUT_PODSPEC"
    
    # Step 2: Add the new version (ensures consistency)
    sed -i "" -E "s/(spec\\.dependency[[:space:]]+'(MSPiOSCore|MSPSharedLibraries|MSPPrebidAdapter|PrebidAdapter)')/\\1, '$VERSION'/g" "$OUTPUT_PODSPEC"
    
    log_success "Updated MSP internal dependencies to version $VERSION"
fi

# MSPOMSDK: Keep without version constraint (aligned with legacy behavior)
if grep -q "spec\\.dependency.*'MSPOMSDK'" "$OUTPUT_PODSPEC"; then
    log_info "MSPOMSDK dependency found - keeping without version constraint (legacy behavior)"
    # Remove any version constraint from MSPOMSDK (should not be in release podspec anyway due to filtering)
    sed -i "" -E "s/(spec\\.dependency[[:space:]]+'MSPOMSDK')[^#\n]*/\\1/g" "$OUTPUT_PODSPEC"
fi

# Add release-specific configuration
# Core modules: HTTP binary zip distribution (Stage A)
# Adapters: git+tag source distribution (source-based architecture)
if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
    if is_core_module "$POD_NAME"; then
        # Core modules: HTTP binary zip distribution (decoupled from git tags)
        zip_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${VERSION}/${POD_NAME}-${VERSION}.zip"
        cat >> "$OUTPUT_PODSPEC" <<EOF_RELEASE

  # ═══════════════════════════════════════════════════════════════════════════
  # GENERATED FOR RELEASE (Binary Distribution - HTTP Zip)
  # Generated by: Scripts/release/generate_podspec.sh
  # Stage A: HTTP binary distribution (no git tag dependency)
  # ═══════════════════════════════════════════════════════════════════════════

  spec.version = "$VERSION"

  spec.source = {
    :http => "$zip_url",
    :type => "zip"
  }

EOF_RELEASE
    else
        # Adapters: git+tag source distribution (source-based architecture)
        cat >> "$OUTPUT_PODSPEC" <<EOF_RELEASE

  # ═══════════════════════════════════════════════════════════════════════════
  # GENERATED FOR RELEASE (Source Distribution - Git Tag)
  # Generated by: Scripts/release/generate_podspec.sh
  # Adapters are source-based per architecture (README.md)
  # ═══════════════════════════════════════════════════════════════════════════

  spec.version = "$VERSION"

  spec.source = {
    git: "https://github.com/ParticleMedia/msp-ios-sdk-public.git",
    tag: spec.version.to_s
  }

EOF_RELEASE
    fi
else
    # Preflight/test tiers: Keep git+tag source for validation
    cat >> "$OUTPUT_PODSPEC" <<EOF_RELEASE

  # ═══════════════════════════════════════════════════════════════════════════
  # GENERATED FOR RELEASE (Binary Distribution)
  # Generated by: Scripts/release/generate_podspec.sh
  # ═══════════════════════════════════════════════════════════════════════════

  spec.version = "$VERSION"

  spec.source = {
    git: "https://github.com/ParticleMedia/msp-ios-sdk-public.git",
    tag: spec.version.to_s
  }

EOF_RELEASE
fi

# Add vendored_frameworks for core modules, source_files for adapters
if is_core_module "$POD_NAME"; then
    # Core modules: binary XCFrameworks
    if [[ "$POD_NAME" == "MSPSharedLibraries" ]]; then
        # MSPSharedLibraries: includes PrebidMobile only (MSPiOSCore is now a separate dependency)
        cat >> "$OUTPUT_PODSPEC" <<'EOF_VENDOR_MULTI'
  spec.vendored_frameworks = [
    "Binary/MSPSharedLibraries.xcframework",
    "ThirdParty/PrebidMobile/PrebidMobile.xcframework"
  ]
EOF_VENDOR_MULTI
    else
        cat >> "$OUTPUT_PODSPEC" <<EOF_VENDOR_SINGLE
  spec.vendored_frameworks = "Binary/${POD_NAME}.xcframework"
EOF_VENDOR_SINGLE
    fi
else
    # Adapters: check if NovaAdapter (special case: pure binary distribution)
    if [[ "$POD_NAME" == "NovaAdapter" ]]; then
        # NovaAdapter: pure binary distribution (vendored_frameworks only)
        log_info "NovaAdapter detected: pure binary distribution with embedded NovaCore"
        
        # Add vendored_frameworks for NovaAdapter + NovaCore
        cat >> "$OUTPUT_PODSPEC" <<'EOF_VENDOR_NOVA'
  spec.vendored_frameworks = [
    "Binary/NovaAdapter.xcframework",
    "Binary/NovaCore.xcframework"
  ]
EOF_VENDOR_NOVA
    else
        # Other adapters: source-based distribution (extract source_files from source podspec)
        log_info "Adapter detected: extracting source_files from source podspec"
        
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
fi

# Close the podspec
cat >> "$OUTPUT_PODSPEC" <<'EOF_FOOTER'

end
EOF_FOOTER

log_success "Generated release podspec: $OUTPUT_PODSPEC"
log_info "Location: $OUTPUT_PODSPEC"

# ============================================================================
# Validation
# ============================================================================

log_info "Validating generated podspec structure..."

if ! grep -q "spec.version.*$VERSION" "$OUTPUT_PODSPEC"; then
    log_error "Generated podspec missing correct version"
    exit 1
fi

# Validate podspec structure based on module type
if is_core_module "$POD_NAME"; then
    # Core modules must have vendored_frameworks
    if ! grep -q "spec.vendored_frameworks" "$OUTPUT_PODSPEC"; then
        log_error "Generated podspec missing vendored_frameworks (core module)"
        exit 1
    fi
else
    # Adapters: check if NovaAdapter (special case: pure binary distribution)
    if [[ "$POD_NAME" == "NovaAdapter" ]]; then
        # NovaAdapter: must have vendored_frameworks only (no source_files)
        if ! grep -q "spec.vendored_frameworks" "$OUTPUT_PODSPEC"; then
            log_error "Generated podspec missing vendored_frameworks (NovaAdapter)"
            exit 1
        fi
        if grep -q "spec.source_files" "$OUTPUT_PODSPEC"; then
            log_error "Generated podspec should not have source_files (NovaAdapter is pure binary)"
            exit 1
        fi
    else
        # Other adapters must have source_files
        if ! grep -q "spec.source_files" "$OUTPUT_PODSPEC"; then
            log_error "Generated podspec missing source_files (adapter)"
            exit 1
        fi
    fi
fi

# Validate source format based on release tier and module type
if [[ "${MSP_RELEASE_TIER:-}" == "release" ]]; then
    if is_core_module "$POD_NAME"; then
        # Core modules: HTTP binary zip source
        if ! grep -qE "spec.source.*:http|:http =>" "$OUTPUT_PODSPEC"; then
            log_error "Generated podspec missing HTTP zip source (release tier, core module)"
            exit 1
        fi
        log_success "Podspec structure validated (HTTP binary distribution)"
    else
        # Adapters: git+tag source (check for git: or :git => inside spec.source block)
        if ! grep -qE "git:|:git =>" "$OUTPUT_PODSPEC"; then
            log_error "Generated podspec missing git source (release tier, adapter)"
            exit 1
        fi
        log_success "Podspec structure validated (git+tag source distribution)"
    fi
else
    # Preflight/test tiers: git+tag source for all modules
    if ! grep -qE "git:|:git =>" "$OUTPUT_PODSPEC"; then
        log_error "Generated podspec missing git source (preflight/test tier)"
        exit 1
    fi
    log_success "Podspec structure validated (git source)"
fi

log_info "Next: Run 'pod spec lint $OUTPUT_PODSPEC --allow-warnings' to validate"

exit 0
