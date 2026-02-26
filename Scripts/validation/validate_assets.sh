#!/usr/bin/env bash
# Asset validation script - Enhanced version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# R033: Source spm.sh module for unified SPM operations
if [[ -f "$ROOT_DIR/Scripts/lib/spm.sh" ]]; then
    # shellcheck source=Scripts/lib/spm.sh
    source "$ROOT_DIR/Scripts/lib/spm.sh" 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Asset Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ═══════════════════════════════════════════════════════════
# Check 1: Verify critical directories exist
# ═══════════════════════════════════════════════════════════
echo "Checking critical directories..."
critical_dirs=(
    "Sources"
    "Sources/Core"
    "Sources/Adapters"
    "Sources/Common"
    "Scripts"
)

echo ""
echo "Checking DemoApp layout..."
demoapp_candidates=(
    "DemoApp"
    "MSPDemoApp"
    "Examples/MSPDemoApp"
)

demoapp_found=false
for candidate in "${demoapp_candidates[@]}"; do
    if [ -d "$candidate" ]; then
        echo "  ✅ $candidate exists"
        demoapp_found=true
        break
    fi
done

if [ "$demoapp_found" = false ]; then
    echo "  ❌ DemoApp directory not found (expected one of: ${demoapp_candidates[*]})"
    exit 1
fi

echo ""
echo "Checking critical directories..."

for dir in "${critical_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir exists"
    else
        echo "  ❌ $dir NOT FOUND"
        exit 1
    fi
done

# ═══════════════════════════════════════════════════════════
# Check 2: Verify all podspec files are valid
# ═══════════════════════════════════════════════════════════
echo ""
echo "Checking Podspec files..."
podspec_count=0
for spec in *.podspec; do
    if [ -f "$spec" ]; then
        echo "  ✅ $spec exists"
        podspec_count=$((podspec_count + 1))

        # Verify podspec syntax (basic check)
        if ! grep -q "Pod::Spec.new" "$spec"; then
            echo "  ❌ $spec has invalid syntax (missing Pod::Spec.new)"
            exit 1
        fi
    fi
done

if [ "$podspec_count" -eq 0 ]; then
    echo "  ❌ No podspec files found"
    exit 1
fi

echo "  Found $podspec_count podspec files"

# ═══════════════════════════════════════════════════════════
# Check 3: Verify Package.swift (if using SPM)
# ═══════════════════════════════════════════════════════════
echo ""
echo "Checking Swift Package Manager files..."
# R033: Use spm_check_manifest_exists if available
if command -v spm_check_manifest_exists &>/dev/null; then
    if spm_check_manifest_exists "."; then
        echo "  ✅ Package.swift exists"

        # R033: Use spm_validate_manifest for validation
        if command -v spm_validate_manifest &>/dev/null; then
            if ! spm_validate_manifest "." 2>/dev/null; then
                echo "  ❌ Package.swift has invalid syntax"
                exit 1
            fi
        else
            # Fallback to basic grep check
            if ! grep -q "import PackageDescription" "Package.swift"; then
                echo "  ❌ Package.swift has invalid syntax"
                exit 1
            fi
        fi

        # Check if Package.swift defines any products
        if ! grep -q "products:" "Package.swift"; then
            echo "  ⚠️  Package.swift has no products defined"
        fi
    else
        echo "  ⚠️  Package.swift not found (SPM not configured)"
    fi
elif [ -f "Package.swift" ]; then
    echo "  ✅ Package.swift exists"

    # Verify Package.swift syntax (basic check)
    if ! grep -q "import PackageDescription" "Package.swift"; then
        echo "  ❌ Package.swift has invalid syntax"
        exit 1
    fi

    # Check if Package.swift defines any products
    if ! grep -q "products:" "Package.swift"; then
        echo "  ⚠️  Package.swift has no products defined"
    fi
else
    echo "  ⚠️  Package.swift not found (SPM not configured)"
fi

# ═══════════════════════════════════════════════════════════
# Check 4: Verify resource assets (images, bundles, etc.)
# ═══════════════════════════════════════════════════════════
echo ""
echo "Checking resource assets..."

# Check for .xcassets directories
xcassets_count=$(find . -name "*.xcassets" -type d 2>/dev/null | wc -l | xargs)
if [ "$xcassets_count" -gt 0 ]; then
    echo "  ✅ Found $xcassets_count asset catalogs"

    # Verify each asset catalog has Contents.json
    find . -name "*.xcassets" -type d | while read -r asset_catalog; do
        if [ -f "$asset_catalog/Contents.json" ]; then
            echo "    ✅ $asset_catalog has valid Contents.json"
        else
            echo "    ❌ $asset_catalog is missing Contents.json"
            exit 1
        fi
    done
else
    echo "  ⚠️  No asset catalogs found (*.xcassets)"
fi

# Check for .bundle resources
bundle_count=$(find . -name "*.bundle" -type d 2>/dev/null | wc -l | xargs)
if [ "$bundle_count" -gt 0 ]; then
    echo "  ✅ Found $bundle_count resource bundles"
else
    echo "  ℹ️  No resource bundles found (*.bundle)"
fi

# ═══════════════════════════════════════════════════════════
# Check 5: Verify script files have executable permissions
# ═══════════════════════════════════════════════════════════
echo ""
echo "Checking script file permissions..."
script_count=0
non_executable_count=0

find Scripts -name "*.sh" -type f | while read -r script; do
    script_count=$((script_count + 1))
    if [ -x "$script" ]; then
        : # Script is executable, continue
    else
        echo "  ⚠️  $script is not executable"
        non_executable_count=$((non_executable_count + 1))
    fi
done

if [ "$non_executable_count" -gt 0 ]; then
    echo "  ⚠️  Found $non_executable_count non-executable scripts"
    echo "  Run: find Scripts -name '*.sh' -type f -exec chmod +x {} \\;"
fi

# ═══════════════════════════════════════════════════════════
# Check 6: Verify XCFramework structure (if exists)
# ═══════════════════════════════════════════════════════════
echo ""
echo "Checking XCFramework structure..."
if [ -d "Build/ReleaseArtifacts/XCFrameworks" ]; then
    xcframework_count=$(find Build/ReleaseArtifacts/XCFrameworks -name "*.xcframework" -type d 2>/dev/null | wc -l | xargs)

    if [ "$xcframework_count" -gt 0 ]; then
        echo "  ✅ Found $xcframework_count XCFrameworks"

        # Verify each XCFramework has Info.plist
        find Build/ReleaseArtifacts/XCFrameworks -name "*.xcframework" -type d | while read -r xcf; do
            if [ -f "$xcf/Info.plist" ]; then
                echo "    ✅ $(basename "$xcf") has valid Info.plist"
            else
                echo "    ❌ $(basename "$xcf") is missing Info.plist"
                exit 1
            fi
        done
    else
        echo "  ℹ️  No XCFrameworks found (will be built during CI)"
    fi
else
    echo "  ℹ️  Build/ReleaseArtifacts/XCFrameworks directory does not exist (will be created during build)"
fi

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Asset validation completed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
