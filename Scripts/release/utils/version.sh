#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Version Utilities for Release Scripts
# Provides version validation, comparison, and manipulation functions

# ============================================================================
# ROOT_DIR and UI System Loading
# ============================================================================
# ============================================
# Unified ROOT_DIR resolution (final version)
# ============================================
if [[ -z "${ROOT_DIR:-}" ]]; then
    # First try Git repo root (most reliable)
    if command -v git >/dev/null 2>&1; then
        git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            ROOT_DIR="$git_root"
        fi
    fi

    # Fallback to walking up from SCRIPT_DIR
    if [[ -z "${ROOT_DIR:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        ROOT_DIR="$SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
    fi
fi

export ROOT_DIR

# Source UI system in order: colors.sh → ui.sh → logging.sh
# Handle NO_ANSI flag by setting NO_COLOR (logging.sh respects NO_COLOR)
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Source colors.sh
if [[ -f "$ROOT_DIR/Scripts/lib/colors.sh" ]]; then
    # shellcheck source=Scripts/lib/colors.sh
    source "$ROOT_DIR/Scripts/lib/colors.sh" 2>/dev/null || true
fi

# Source ui.sh (depends on colors.sh)
if [[ -f "$ROOT_DIR/Scripts/lib/ui.sh" ]]; then
    # shellcheck source=Scripts/lib/ui.sh
    source "$ROOT_DIR/Scripts/lib/ui.sh" 2>/dev/null || true
fi

# Source logging.sh (depends on colors.sh and ui.sh)
if [[ -f "$ROOT_DIR/Scripts/lib/logging.sh" ]]; then
    # shellcheck source=Scripts/lib/logging.sh
    source "$ROOT_DIR/Scripts/lib/logging.sh" 2>/dev/null || true
fi

# Fallback logging functions if UI system not available
if ! command -v log_info &>/dev/null; then
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
        log_warning "$@"
    }
fi

# Validate version format (semantic versioning: X.Y.Z)
validate_version_format() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        return 1
    fi
    
    # Check if version matches semantic versioning pattern (X.Y.Z or X.Y.Z-suffix)
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        return 0
    else
        log_error "Invalid version format: $version (expected X.Y.Z or X.Y.Z-suffix)"
        return 1
    fi
}

# Compare two versions
# Returns: 0 if equal, 1 if version1 > version2, 2 if version1 < version2
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    if [[ -z "$version1" || -z "$version2" ]]; then
        log_error "Both versions are required for comparison"
        return 3
    fi
    
    # Remove suffix for comparison
    local v1_base="${version1%-*}"
    local v2_base="${version2%-*}"
    
    # Split into major.minor.patch
    IFS='.' read -r -a v1_parts <<< "$v1_base"
    IFS='.' read -r -a v2_parts <<< "$v2_base"
    
    # Compare major
    if [[ ${v1_parts[0]} -gt ${v2_parts[0]} ]]; then
        return 1
    elif [[ ${v1_parts[0]} -lt ${v2_parts[0]} ]]; then
        return 2
    fi
    
    # Compare minor
    if [[ ${v1_parts[1]} -gt ${v2_parts[1]} ]]; then
        return 1
    elif [[ ${v1_parts[1]} -lt ${v2_parts[1]} ]]; then
        return 2
    fi
    
    # Compare patch
    if [[ ${v1_parts[2]} -gt ${v2_parts[2]} ]]; then
        return 1
    elif [[ ${v1_parts[2]} -lt ${v2_parts[2]} ]]; then
        return 2
    fi
    
    # Versions are equal
    return 0
}

# Suggest next version based on current version
suggest_next_version() {
    local current_version="$1"
    local bump_type="${2:-patch}"  # patch, minor, or major
    
    if [[ -z "$current_version" ]]; then
        log_error "Current version is required"
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
            log_error "Invalid bump type: $bump_type (expected patch, minor, or major)"
            return 1
            ;;
    esac
}

# Bump patch version (X.Y.Z -> X.Y.Z+1)
bump_patch() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
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
        log_error "Version is required"
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
        log_error "Version is required"
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

# Update Config.plist version
update_config_plist_version() {
    local version="$1"
    local config_plist="MSPCore/MSPCore/Resources/Config.plist"
    
    if [[ ! -f "$config_plist" ]]; then
        log_error "Config.plist not found: $config_plist"
        return 1
    fi
    
    log_step "Updating SDKVersion in Config.plist to $version"
    
    # Create backup
    cp "$config_plist" "${config_plist}.backup"
    
    # Update SDKVersion in Config.plist
    sed -i '' "s|<string>.*</string>|<string>${version}</string>|g" "$config_plist"
    
    log_success "Updated SDKVersion in Config.plist to $version"
}

# Export functions
export -f validate_version_format compare_versions suggest_next_version bump_patch bump_minor bump_major update_config_plist_version 2>/dev/null || true


