#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Version Utilities for Release Scripts
# Provides version validation, comparison, and manipulation functions

# ============================================================================
# ROOT_DIR and UI System Loading (using path-helpers.sh)
# ============================================================================
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"

# Handle NO_ANSI flag by setting NO_COLOR
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Source common.sh which provides unified logging via logger.sh
if [[ -f "$ROOT_DIR/Scripts/lib/common.sh" ]]; then
    # shellcheck source=Scripts/lib/common.sh
    source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
fi

# Fallback logging functions if UI system not available
if ! command -v log::info &>/dev/null; then
    : "${RED:=\033[0;31m}"
    : "${GREEN:=\033[0;32m}"
    : "${YELLOW:=\033[1;33m}"
    : "${BLUE:=\033[0;34m}"
    : "${NC:=\033[0m}"
    
    log_info() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[INFO] $1"
        else
            echo -e "${BLUE}ℹ️  $1${NC}"
        fi
    }
    
    log_success() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[SUCCESS] $1"
        else
            echo -e "${GREEN}✅ $1${NC}"
        fi
    }
    
    log_warning() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[WARN] $1"
        else
            echo -e "${YELLOW}⚠️  $1${NC}"
        fi
    }
    
    log_error() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[ERROR] $1" >&2
        else
            echo -e "${RED}❌ $1${NC}" >&2
        fi
    }
    
    log_step() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[STEP] $1"
        else
            echo -e "${BLUE}🔧 $1${NC}"
        fi
    }
    
    log_debug() {
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            if [[ "${NO_ANSI:-false}" == "true" ]]; then
                echo "[DEBUG] $1"
            else
                echo -e "${BLUE}🔍 $1${NC}"
            fi
        fi
    }
    
    log_warn() {
        log::warn "VERSION" "$@"
    }
fi

validate_version_format() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log::error "VERSION" "Version is required"
        return 1
    fi
    
    # Check if version matches semantic versioning pattern (X.Y.Z or X.Y.Z-suffix)
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        return 0
    else
        log::error "VERSION" "Invalid version format: $version (expected X.Y.Z or X.Y.Z-suffix)"
        return 1
    fi
}

# Compare two versions
# Returns: 0 if equal, 1 if version1 > version2, 2 if version1 < version2
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    if [[ -z "$version1" || -z "$version2" ]]; then
        log::error "VERSION" "Both versions are required for comparison"
        return 3
    fi
    
    local v1_base="${version1%-*}"
    local v2_base="${version2%-*}"
    
    IFS='.' read -r -a v1_parts <<< "$v1_base"
    IFS='.' read -r -a v2_parts <<< "$v2_base"
    
    if [[ ${v1_parts[0]} -gt ${v2_parts[0]} ]]; then
        return 1
    elif [[ ${v1_parts[0]} -lt ${v2_parts[0]} ]]; then
        return 2
    fi
    
    if [[ ${v1_parts[1]} -gt ${v2_parts[1]} ]]; then
        return 1
    elif [[ ${v1_parts[1]} -lt ${v2_parts[1]} ]]; then
        return 2
    fi
    
    if [[ ${v1_parts[2]} -gt ${v2_parts[2]} ]]; then
        return 1
    elif [[ ${v1_parts[2]} -lt ${v2_parts[2]} ]]; then
        return 2
    fi
    
    # Versions are equal
    return 0
}

suggest_next_version() {
    local current_version="$1"
    local bump_type="${2:-patch}"  # patch, minor, or major
    
    if [[ -z "$current_version" ]]; then
        log::error "VERSION" "Current version is required"
        return 1
    fi
    
    case "$bump_type" in
        "patch")
            bump_patch "$current_version"
            ;;
        "minor")
            bump_minor "$current_version"
            ;;
        "major")
            bump_major "$current_version"
            ;;
        *)
            log::error "VERSION" "Invalid bump type: $bump_type (expected patch, minor, or major)"
            return 1
            ;;
    esac
}

# Bump patch version (X.Y.Z -> X.Y.Z+1)
bump_patch() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log::error "VERSION" "Version is required"
        return 1
    fi
    
    # Remove suffix if present
    local base_version="${version%-*}"
    local suffix="${version#*-}"
    
    # Split into parts
    IFS='.' read -r -a parts <<< "$base_version"
    
    # Increment patch
    local new_patch=$((parts[2] + 1))
    local new_version="${parts[0]}.${parts[1]}.${new_patch}"
    
    # Add suffix back if it existed
    if [[ "$version" == *"-"* ]]; then
        new_version="${new_version}-${suffix}"
    fi
    
    echo "$new_version"
}

# Bump minor version (X.Y.Z -> X.Y+1.0)
bump_minor() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log::error "VERSION" "Version is required"
        return 1
    fi
    
    # Remove suffix if present
    local base_version="${version%-*}"
    local suffix="${version#*-}"
    
    # Split into parts
    IFS='.' read -r -a parts <<< "$base_version"
    
    # Increment minor, reset patch
    local new_minor=$((parts[1] + 1))
    local new_version="${parts[0]}.${new_minor}.0"
    
    # Add suffix back if it existed
    if [[ "$version" == *"-"* ]]; then
        new_version="${new_version}-${suffix}"
    fi
    
    echo "$new_version"
}

# Bump major version (X.Y.Z -> X+1.0.0)
bump_major() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log::error "VERSION" "Version is required"
        return 1
    fi
    
    # Remove suffix if present
    local base_version="${version%-*}"
    local suffix="${version#*-}"
    
    # Split into parts
    IFS='.' read -r -a parts <<< "$base_version"
    
    # Increment major, reset minor and patch
    local new_major=$((parts[0] + 1))
    local new_version="${new_major}.0.0"
    
    # Add suffix back if it existed
    if [[ "$version" == *"-"* ]]; then
        new_version="${new_version}-${suffix}"
    fi
    
    echo "$new_version"
}

update_config_plist_version() {
    local version="$1"
    
    # Find Config.plist dynamically (more robust than hardcoded path)
    local config_plist
    config_plist=$(find "${ROOT_DIR:-.}" -path "*/MSPCore/MSPCore/Resources/Config.plist" -type f 2>/dev/null | head -1)
    
    if [[ -z "$config_plist" ]]; then
        # Fallback to expected path relative to ROOT_DIR
        config_plist="${ROOT_DIR:-.}/Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
    fi
    
    if [[ ! -f "$config_plist" ]]; then
        log::error "VERSION" "Config.plist not found"
        log::error "VERSION" "Searched pattern: */MSPCore/MSPCore/Resources/Config.plist"
        log::error "VERSION" "Expected location: Sources/Core/MSPCore/MSPCore/Resources/Config.plist"
        log::error "VERSION" "ROOT_DIR: ${ROOT_DIR:-<not set>}"
        return 1
    fi
    
    log::info "VERSION" "Found Config.plist: $config_plist"
    
    log::step "VERSION" "Updating SDKVersion in Config.plist to $version"
    
    # Update SDKVersion in Config.plist (atomic: write to temp, verify, then move)
    local temp_plist="${config_plist}.tmp.$$"
    sed "s|<string>.*</string>|<string>${version}</string>|g" "$config_plist" > "$temp_plist"

    if grep -q "<string>${version}</string>" "$temp_plist"; then
        mv "$temp_plist" "$config_plist"
        log::success "VERSION" "Updated SDKVersion in Config.plist to $version"
    else
        rm -f "$temp_plist"
        log::error "VERSION" "Failed to update Config.plist — version string not found in output"
        return 1
    fi
}

# Export functions
export -f validate_version_format compare_versions suggest_next_version bump_patch bump_minor bump_major update_config_plist_version 2>/dev/null || true


