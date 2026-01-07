#!/bin/bash
# Asset validation script
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Asset Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check 1: Verify XCFrameworks directory structure
if [ ! -d "Build/XCFrameworks" ]; then
    echo "⚠️  Build/XCFrameworks directory does not exist (will be created during build)"
fi

# Check 2: Verify critical directories exist
critical_dirs=(
    "Sources"
    "Adapters"
    "DemoApp"
)

for dir in "${critical_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir exists"
    else
        echo "❌ $dir NOT FOUND"
        exit 1
    fi
done

# Check 3: Verify podspec files
echo ""
echo "Checking Podspec files..."
for spec in *.podspec; do
    if [ -f "$spec" ]; then
        echo "  ✅ $spec exists"
    fi
done

# Check 4: Verify Package.swift (if using SPM)
if [ -f "Package.swift" ]; then
    echo "  ✅ Package.swift exists"
fi

echo ""
echo "✅ Asset validation passed"

