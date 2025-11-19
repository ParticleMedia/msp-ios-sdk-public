#!/usr/bin/env bash
# Source Parity Validator
# Compares CocoaPods target source files with SwiftPM source files
# Ensures 100% consistency between Pods and SPM builds

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to extract source files from Xcode project target
extract_xcode_sources() {
    local project_path="$1"
    local target_name="$2"
    
    if [[ ! -f "$project_path/project.pbxproj" ]]; then
        echo "ERROR: project.pbxproj not found at $project_path" >&2
        return 1
    fi
    
    python3 <<PYTHON_SCRIPT
import os
import re
import sys

project_path = "$project_path"
target_name = "$target_name"
pbxproj_path = os.path.join(project_path, "project.pbxproj")

with open(pbxproj_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Find target by name
target_pattern = rf'/\* {re.escape(target_name)} \*/.*?isa = PBXNativeTarget;.*?name = {re.escape(target_name)};'
target_match = re.search(target_pattern, content, re.DOTALL)

if not target_match:
    print(f"ERROR: Target {target_name} not found", file=sys.stderr)
    sys.exit(1)

target_section = target_match.group(0)

# Find build phases
build_phases_match = re.search(r'buildPhases = \((.*?)\);', target_section, re.DOTALL)
if not build_phases_match:
    print(f"ERROR: Could not find build phases", file=sys.stderr)
    sys.exit(1)

build_phases = build_phases_match.group(1)
phase_refs = re.findall(r'([A-F0-9]{24}) /\* .*? \*/', build_phases)

# Find Sources build phase
sources_phase_id = None
for ref in phase_refs:
    phase_pattern = rf'{ref} /\* Sources \*/.*?isa = PBXSourcesBuildPhase;'
    if re.search(phase_pattern, content, re.DOTALL):
        sources_phase_id = ref
        break

if not sources_phase_id:
    print(f"ERROR: Could not find Sources build phase", file=sys.stderr)
    sys.exit(1)

# Get file references from Sources phase
sources_pattern = rf'{sources_phase_id} /\* Sources \*/.*?files = \((.*?)\);'
sources_match = re.search(sources_pattern, content, re.DOTALL)

if not sources_match:
    print(f"ERROR: Could not find files in Sources phase", file=sys.stderr)
    sys.exit(1)

files_section = sources_match.group(1)
file_refs = re.findall(r'([A-F0-9]{24}) /\* ([^*]+) \*/', files_section)

# Get SRCROOT from project
srcroot_match = re.search(r'SRCROOT = ([^;]+);', content)
srcroot = srcroot_match.group(1).strip().strip('"') if srcroot_match else ""

# Map file references to actual paths
source_files = []
for file_id, file_name in file_refs:
    if not file_name.endswith('.swift'):
        continue
    
    # Find file reference
    file_ref_pattern = rf'{file_id} /\* {re.escape(file_name)} \*/.*?isa = PBXFileReference;.*?path = ([^;]+);'
    file_ref_match = re.search(file_ref_pattern, content, re.DOTALL)
    
    if file_ref_match:
        file_path = file_ref_match.group(1).strip().strip('"')
        
        # Resolve path
        if os.path.isabs(file_path):
            full_path = file_path
        elif srcroot:
            full_path = os.path.join(srcroot, file_path)
        else:
            full_path = os.path.join(project_path, "..", file_path)
        
        normalized = os.path.normpath(full_path)
        if os.path.exists(normalized):
            source_files.append(normalized)

# Print sorted list
for f in sorted(set(source_files)):
    print(f)
PYTHON_SCRIPT
}

# Function to extract source files from SwiftPM package
extract_spm_sources() {
    local package_path="$1"
    local sources_path="${2:-}"
    
    if [[ -z "$sources_path" ]]; then
        # Try to find Sources directory
        if [[ -d "$package_path/Sources" ]]; then
            sources_path="$package_path/Sources"
            # Find first target directory
            local first_target=$(ls "$sources_path" 2>/dev/null | head -1)
            if [[ -n "$first_target" ]]; then
                sources_path="$sources_path/$first_target"
            fi
        else
            sources_path="$package_path"
        fi
    fi
    
    if [[ ! -d "$sources_path" ]]; then
        echo "ERROR: Sources directory not found: $sources_path" >&2
        return 1
    fi
    
    find "$sources_path" -name "*.swift" -type f | sort
}

# Function to normalize paths for comparison
normalize_path() {
    local path="$1"
    # Remove ROOT_DIR prefix and normalize
    echo "$path" | sed "s|^$ROOT_DIR/||" | sed 's|^\./||'
}

# Function to compare two file lists
compare_file_lists() {
    local pods_list="$1"
    local spm_list="$2"
    local module_name="$3"
    
    echo ""
    echo "=== Comparing $module_name ==="
    
    # Normalize both lists
    local pods_normalized=$(echo "$pods_list" | while read -r f; do normalize_path "$f"; done | sort)
    local spm_normalized=$(echo "$spm_list" | while read -r f; do normalize_path "$f"; done | sort)
    
    # Find differences
    local only_in_pods=$(comm -23 <(echo "$pods_normalized") <(echo "$spm_normalized"))
    local only_in_spm=$(comm -13 <(echo "$pods_normalized") <(echo "$spm_normalized"))
    local in_both=$(comm -12 <(echo "$pods_normalized") <(echo "$spm_normalized"))
    
    if [[ -n "$only_in_pods" ]]; then
        echo -e "${RED}✗ Files in CocoaPods but missing in SPM:${NC}"
        echo "$only_in_pods" | while read -r file; do
            echo "  - $file"
            ((ERRORS++))
        done
    fi
    
    if [[ -n "$only_in_spm" ]]; then
        echo -e "${RED}✗ Files in SPM but missing in CocoaPods (ORPHAN/GHOST FILES):${NC}"
        echo "$only_in_spm" | while read -r file; do
            echo "  - $file"
            ((ERRORS++))
        done
    fi
    
    if [[ -z "$only_in_pods" && -z "$only_in_spm" ]]; then
        local count=$(echo "$in_both" | grep -c . || echo "0")
        echo -e "${GREEN}✓ Source parity verified: $count files match${NC}"
    else
        local both_count=$(echo "$in_both" | grep -c . || echo "0")
        echo -e "${YELLOW}Files in both: $both_count${NC}"
    fi
}

# Main validation function
validate_module() {
    local module_name="$1"
    local xcode_project="${2:-$ROOT_DIR/$module_name/$module_name.xcodeproj}"
    local xcode_target="${3:-$module_name}"
    local spm_path="${4:-$ROOT_DIR/$module_name}"
    local spm_sources="${5:-}"
    
    echo ""
    echo "=========================================="
    echo "Validating: $module_name"
    echo "=========================================="
    
    # Extract Xcode sources
    echo "Extracting Xcode project source files..."
    local xcode_sources=$(extract_xcode_sources "$xcode_project" "$xcode_target" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${YELLOW}WARNING: Failed to extract Xcode sources, trying directory-based comparison${NC}" >&2
        echo "$xcode_sources" >&2
        
        # Fallback: use directory listing
        if [[ -d "$spm_path/$module_name" ]]; then
            xcode_sources=$(find "$spm_path/$module_name" -name "*.swift" -type f | sort)
        else
            xcode_sources=$(find "$spm_path" -name "*.swift" -type f | sort)
        fi
        ((WARNINGS++))
    fi
    
    local xcode_count=$(echo "$xcode_sources" | grep -c . || echo "0")
    echo "Found $xcode_count Swift files in Xcode project"
    
    # Extract SPM sources
    echo "Extracting SwiftPM source files..."
    local spm_sources=$(extract_spm_sources "$spm_path" "$spm_sources" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}ERROR: Failed to extract SPM sources${NC}" >&2
        echo "$spm_sources" >&2
        ((ERRORS++))
        return 1
    fi
    
    local spm_count=$(echo "$spm_sources" | grep -c . || echo "0")
    echo "Found $spm_count Swift files in SwiftPM package"
    
    # Compare
    compare_file_lists "$xcode_sources" "$spm_sources" "$module_name"
}

# Validate all modules
echo "=========================================="
echo "Source Parity Validation"
echo "=========================================="
echo ""

# Validate NovaCore (local pod, uses NovaCore.xcodeproj)
validate_module "NovaCore" "$ROOT_DIR/NovaCore/NovaCore.xcodeproj" "NovaCore" "$ROOT_DIR/NovaCore" "NovaCore/NovaCore"

# Validate MSPCore
if [[ -f "$ROOT_DIR/MSPCore/MSPCore.xcodeproj/project.pbxproj" ]]; then
    validate_module "MSPCore" "$ROOT_DIR/MSPCore/MSPCore.xcodeproj" "MSPCore" "$ROOT_DIR/MSPCore" "MSPCore/MSPCore"
fi

# Validate MSPiOSCore
if [[ -f "$ROOT_DIR/MSPiOSCore/MSPiOSCore.xcodeproj/project.pbxproj" ]]; then
    validate_module "MSPiOSCore" "$ROOT_DIR/MSPiOSCore/MSPiOSCore.xcodeproj" "MSPiOSCore" "$ROOT_DIR/MSPiOSCore" "MSPiOSCore/MSPiOSCore"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}✗ Validation FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Validation PASSED${NC}"
    exit 0
fi
