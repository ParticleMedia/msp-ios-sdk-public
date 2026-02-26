#!/usr/bin/env bash
# ============================================================================
# SPM Operations Module
# ============================================================================
# Module: spm.sh
# Purpose: Unified Swift Package Manager operations
#
# Functions:
#   - spm_patch_package_swift: Modify Package.swift file
#   - spm_resolve_dependencies: Resolve SPM dependencies
#   - spm_validate_manifest: Validate Package.swift syntax
#   - spm_update_version: Update version in Package.swift
#   - spm_extract_targets: Extract target names from Package.swift
#   - spm_check_manifest_exists: Check if Package.swift exists
#
# Dependencies:
#   - logger.sh (log::* functions)
#   - swift CLI
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SPM_SOURCED:-}" ]] && return 0
readonly _SPM_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

SPM_DEFAULT_PACKAGE_FILE="Package.swift"
SPM_DEFAULT_TIMEOUT=300  # 5 minutes for resolve

# ============================================================================
# spm_check_manifest_exists
# ============================================================================
# Check if Package.swift exists in a directory
#
# Args:
#   $1: directory - Directory to check (default: current directory)
#
# Returns:
#   0 if Package.swift exists, 1 otherwise
# ============================================================================
spm_check_manifest_exists() {
    local directory="${1:-.}"
    local package_file="$directory/$SPM_DEFAULT_PACKAGE_FILE"

    [[ -f "$package_file" ]]
}

# ============================================================================
# spm_validate_manifest
# ============================================================================
# Validate Package.swift syntax and structure
#
# Args:
#   $1: package_path - Path to Package.swift (or directory containing it)
#
# Returns:
#   0 if valid, 1 if invalid
#   Prints validation errors to stderr
# ============================================================================
spm_validate_manifest() {
    local package_path="${1:-$SPM_DEFAULT_PACKAGE_FILE}"

    # If path is a directory, append Package.swift
    if [[ -d "$package_path" ]]; then
        package_path="$package_path/$SPM_DEFAULT_PACKAGE_FILE"
    fi

    if [[ ! -f "$package_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Package.swift not found: $package_path"
        else
            echo "ERROR: Package.swift not found: $package_path" >&2
        fi
        return 1
    fi

    local errors=()

    # Check for PackageDescription import
    if ! grep -q "import PackageDescription" "$package_path"; then
        errors+=("Missing 'import PackageDescription'")
    fi

    # Check for Package declaration
    if ! grep -q "let package = Package(" "$package_path"; then
        errors+=("Missing Package declaration")
    fi

    # Check for name
    if ! grep -q 'name:' "$package_path"; then
        errors+=("Missing package name")
    fi

    # Check for products (warning only)
    if ! grep -q 'products:' "$package_path"; then
        if command -v log::warn &>/dev/null; then
            log::warn "SPM" "Package.swift has no products defined"
        fi
    fi

    # Try to parse with swift (if available)
    if command -v swift &>/dev/null; then
        if ! swift package dump-package --package-path "$(dirname "$package_path")" &>/dev/null; then
            errors+=("Swift parser failed - check syntax")
        fi
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Package.swift validation failed:"
            for err in "${errors[@]}"; do
                log::error "SPM" "  - $err"
            done
        else
            echo "ERROR: Package.swift validation failed:" >&2
            for err in "${errors[@]}"; do
                echo "  - $err" >&2
            done
        fi
        return 1
    fi

    return 0
}

# ============================================================================
# spm_extract_targets
# ============================================================================
# Extract target names from Package.swift
#
# Args:
#   $1: package_path - Path to Package.swift (or directory containing it)
#
# Output:
#   Prints target names, one per line
# ============================================================================
spm_extract_targets() {
    local package_path="${1:-$SPM_DEFAULT_PACKAGE_FILE}"

    # If path is a directory, append Package.swift
    if [[ -d "$package_path" ]]; then
        package_path="$package_path/$SPM_DEFAULT_PACKAGE_FILE"
    fi

    if [[ ! -f "$package_path" ]]; then
        return 1
    fi

    # Extract target names using grep and sed
    grep -E '^\s*\.target\(' "$package_path" 2>/dev/null | \
        grep -oE 'name:\s*"[^"]*"' | \
        cut -d'"' -f2 || true

    # Also extract binaryTarget names
    grep -E '^\s*\.binaryTarget\(' "$package_path" 2>/dev/null | \
        grep -oE 'name:\s*"[^"]*"' | \
        cut -d'"' -f2 || true
}

# ============================================================================
# spm_resolve_dependencies
# ============================================================================
# Resolve SPM dependencies
#
# Args:
#   $1: package_path - Path to directory containing Package.swift
#   $2: timeout - Timeout in seconds (default: 300)
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
spm_resolve_dependencies() {
    local package_path="${1:-.}"
    local timeout="${2:-$SPM_DEFAULT_TIMEOUT}"

    if [[ ! -d "$package_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Directory not found: $package_path"
        fi
        return 1
    fi

    if [[ ! -f "$package_path/$SPM_DEFAULT_PACKAGE_FILE" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Package.swift not found in: $package_path"
        fi
        return 1
    fi

    if command -v log::step &>/dev/null; then
        log::step "SPM" "Resolving SPM dependencies..."
    fi

    local resolve_cmd
    if command -v timeout &>/dev/null; then
        resolve_cmd="timeout $timeout swift package resolve --package-path \"$package_path\""
    else
        resolve_cmd="swift package resolve --package-path \"$package_path\""
    fi

    if eval "$resolve_cmd" 2>&1; then
        if command -v log::success &>/dev/null; then
            log::success "SPM" "Dependencies resolved successfully"
        fi
        return 0
    else
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Failed to resolve dependencies"
        fi
        return 1
    fi
}

# ============================================================================
# spm_patch_package_swift
# ============================================================================
# Modify Package.swift with specified changes
#
# Args:
#   $1: package_path - Path to Package.swift
#   $2: target_name - Target to modify
#   $3: change_type - Type of change (url, checksum, path)
#   $4: new_value - New value to set
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
spm_patch_package_swift() {
    local package_path="$1"
    local target_name="$2"
    local change_type="$3"
    local new_value="$4"

    if [[ ! -f "$package_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Package.swift not found: $package_path"
        fi
        return 1
    fi

    # Backup original
    local backup_path="${package_path}.bak.$$"
    cp "$package_path" "$backup_path"

    local success=false

    case "$change_type" in
        url)
            # Replace url in binaryTarget
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|url: \"[^\"]*\".*// $target_name|url: \"$new_value\" // $target_name|g" "$package_path" && success=true
            else
                sed -i "s|url: \"[^\"]*\".*// $target_name|url: \"$new_value\" // $target_name|g" "$package_path" && success=true
            fi
            ;;
        checksum)
            # Replace checksum in binaryTarget
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|checksum: \"[^\"]*\".*// $target_name|checksum: \"$new_value\" // $target_name|g" "$package_path" && success=true
            else
                sed -i "s|checksum: \"[^\"]*\".*// $target_name|checksum: \"$new_value\" // $target_name|g" "$package_path" && success=true
            fi
            ;;
        path)
            # Replace path in binaryTarget
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|path: \"[^\"]*\".*// $target_name|path: \"$new_value\" // $target_name|g" "$package_path" && success=true
            else
                sed -i "s|path: \"[^\"]*\".*// $target_name|path: \"$new_value\" // $target_name|g" "$package_path" && success=true
            fi
            ;;
        *)
            if command -v log::error &>/dev/null; then
                log::error "SPM" "Unknown change type: $change_type"
            fi
            rm -f "$backup_path"
            return 1
            ;;
    esac

    if [[ "$success" == "true" ]]; then
        rm -f "$backup_path"
        if command -v log::success &>/dev/null; then
            log::success "SPM" "Updated $target_name $change_type in Package.swift"
        fi
        return 0
    else
        # Restore backup
        mv "$backup_path" "$package_path"
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Failed to update Package.swift"
        fi
        return 1
    fi
}

# ============================================================================
# spm_update_version
# ============================================================================
# Update version in Package.swift or related files
#
# Args:
#   $1: package_dir - Directory containing Package.swift
#   $2: new_version - New version string
#
# Returns:
#   0 on success, 1 on failure
# ============================================================================
spm_update_version() {
    local package_dir="$1"
    local new_version="$2"

    if [[ ! -d "$package_dir" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Directory not found: $package_dir"
        fi
        return 1
    fi

    local package_file="$package_dir/$SPM_DEFAULT_PACKAGE_FILE"

    if [[ ! -f "$package_file" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SPM" "Package.swift not found in: $package_dir"
        fi
        return 1
    fi

    # Version can be in different formats, try common patterns
    local patterns=(
        "s/version: \"[0-9.]*\"/version: \"$new_version\"/g"
        "s/\.version([[:space:]]*=[[:space:]]*\"[0-9.]*\")/.version = \"$new_version\"/g"
    )

    local updated=false
    for pattern in "${patterns[@]}"; do
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if sed -i '' "$pattern" "$package_file" 2>/dev/null; then
                updated=true
            fi
        else
            if sed -i "$pattern" "$package_file" 2>/dev/null; then
                updated=true
            fi
        fi
    done

    if [[ "$updated" == "true" ]]; then
        if command -v log::success &>/dev/null; then
            log::success "SPM" "Updated version to $new_version"
        fi
        return 0
    else
        if command -v log::warn &>/dev/null; then
            log::warn "SPM" "No version pattern found to update"
        fi
        return 0  # Not necessarily an error
    fi
}
