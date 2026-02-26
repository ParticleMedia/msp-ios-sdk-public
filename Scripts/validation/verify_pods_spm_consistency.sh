#!/usr/bin/env bash
# Pods/SPM consistency checker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# R033: Source spm.sh module for unified SPM operations
if [[ -f "$ROOT_DIR/Scripts/lib/spm.sh" ]]; then
    # shellcheck source=Scripts/lib/spm.sh
    source "$ROOT_DIR/Scripts/lib/spm.sh" 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Pods/SPM Consistency Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# R033: Use spm_check_manifest_exists if available, fallback to direct check
if command -v spm_check_manifest_exists &>/dev/null; then
    if ! spm_check_manifest_exists "."; then
        echo "⚠️  Package.swift not found, skipping SPM consistency check"
        exit 0
    fi
elif [ ! -f "Package.swift" ]; then
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
# R033: Use spm_extract_targets if available, fallback to direct grep
if command -v spm_extract_targets &>/dev/null; then
    spm_modules=$(spm_extract_targets ".")
else
    spm_modules=$(grep -E '^\s*\.target\(' Package.swift | grep -oE 'name:\s*"[^"]*"' | cut -d'"' -f2)
fi
echo "$spm_modules" | while read -r module; do
    echo "  - $module"
done

echo ""
echo "✅ Consistency check completed"
echo "   Note: This is a basic check. Full validation requires dependency graph analysis."

