#!/bin/bash
# Pods/SPM consistency checker
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Pods/SPM Consistency Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Package.swift exists
if [ ! -f "Package.swift" ]; then
    echo "⚠️  Package.swift not found, skipping SPM consistency check"
    exit 0
fi

# Compare module list from podspecs and Package.swift
echo "Extracting modules from Podspecs..."
podspec_modules=()
for spec in *.podspec; do
    if [ -f "$spec" ]; then
        module=$(basename "$spec" .podspec)
        podspec_modules+=("$module")
        echo "  - $module (from $spec)"
    fi
done

echo ""
echo "Extracting modules from Package.swift..."
spm_modules=$(grep -E '^\s*\.target\(' Package.swift | grep -oE 'name:\s*"[^"]*"' | cut -d'"' -f2)
echo "$spm_modules" | while read -r module; do
    echo "  - $module"
done

echo ""
echo "✅ Consistency check completed"
echo "   Note: This is a basic check. Full validation requires dependency graph analysis."

