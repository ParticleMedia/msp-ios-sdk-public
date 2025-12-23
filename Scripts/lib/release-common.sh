#!/bin/bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

# Release Common Library
# Shared functions and configurations for all release scripts
#
# Phase 3 Step 1: Refactored to use modular utils/
# This file now sources utility modules and provides backward compatibility wrappers

# ============================================================================
# ROOT_DIR Calculation
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# UI System Loading (UI-First Rule)
# ============================================================================
# Load UI system in order: colors.sh → ui.sh → logging.sh
# This ensures all logging functions are available before utils modules are loaded

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

# ============================================================================
# Fallback Logging Functions (if UI system not available)
# ============================================================================
# Only define fallbacks if logging functions are not available
if ! command -v log_info &>/dev/null; then
    # Fallback color definitions
    : "${RED:=\033[0;31m}"
    : "${GREEN:=\033[0;32m}"
    : "${YELLOW:=\033[1;33m}"
    : "${BLUE:=\033[0;34m}"
    : "${PURPLE:=\033[0;35m}"
    : "${NC:=\033[0m}"
    
    # Fallback logging functions
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

log_release() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "[RELEASE] $1"
        else
    echo -e "${PURPLE}🚀 $1${NC}"
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

print_section() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo ""
            echo "=== $1 ==="
            echo ""
        else
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
        fi
}

print_subsection() {
        if [[ "${NO_ANSI:-false}" == "true" ]]; then
            echo "--- $1 ---"
        else
    echo -e "${BLUE}--- $1 ---${NC}"
        fi
    }
    
    # Alias log_warn to log_warning for compatibility
    log_warn() {
        log_warning "$@"
    }
fi

# ============================================================================
# Source Utility Modules
# ============================================================================
# Source modules in dependency order (git, version, retry, state, podspec, github, notify)
# Utils modules will source UI system themselves, but release-common.sh has already loaded it

# Source git utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/git.sh" ]]; then
    # shellcheck source=Scripts/release/utils/git.sh
    source "$ROOT_DIR/Scripts/release/utils/git.sh" 2>/dev/null || true
fi

# Source version utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/version.sh" ]]; then
    # shellcheck source=Scripts/release/utils/version.sh
    source "$ROOT_DIR/Scripts/release/utils/version.sh" 2>/dev/null || true
fi

# Source retry utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/retry.sh" ]]; then
    # shellcheck source=Scripts/release/utils/retry.sh
    source "$ROOT_DIR/Scripts/release/utils/retry.sh" 2>/dev/null || true
fi

# Source state utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    # shellcheck source=Scripts/release/utils/state.sh
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi

# Source podspec utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/podspec.sh" ]]; then
    # shellcheck source=Scripts/release/utils/podspec.sh
    source "$ROOT_DIR/Scripts/release/utils/podspec.sh" 2>/dev/null || true
fi

# Source GitHub utilities
if [[ -f "$ROOT_DIR/Scripts/release/utils/github.sh" ]]; then
    # shellcheck source=Scripts/release/utils/github.sh
    source "$ROOT_DIR/Scripts/release/utils/github.sh" 2>/dev/null || true
fi

# ============================================================================
# Release Tier Helpers (Patch M)
# ============================================================================
# Helper functions to determine if we're running in preflight or release tier

is_preflight_tier() {
    # MSP_RELEASE_TIER may be set via env or CLI
    case "${MSP_RELEASE_TIER:-}" in
        preflight|PRELFIGHT|Preflight|PREFLIGHT)
            # Check if preflight is allowed on this branch (Patch M+CONFIG)
            if command -v should_preflight_run &>/dev/null; then
                if ! should_preflight_run; then
                    log_warn "[SKIP] Preflight not allowed on this branch"
                    return 1
                fi
            fi
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_release_tier() {
    if is_preflight_tier; then
        return 1
    fi
    # Check if real publish is allowed on this branch (Patch M+CONFIG)
    if command -v should_real_publish &>/dev/null; then
        if ! should_real_publish; then
            local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
            log_error "[BLOCKED] Real publish not allowed on branch: $branch"
            log_error "[BLOCKED] Check Scripts/release/config/release_config.yaml for branch policy"
            return 1
        fi
    fi
    # treat anything not preflight as "release-like" for now
    return 0
}

# Source notification utilities
# Source release config loader (Patch M+CONFIG)
if [[ -f "$ROOT_DIR/Scripts/release/lib/config.sh" ]]; then
    # shellcheck source=Scripts/release/lib/config.sh
    source "$ROOT_DIR/Scripts/release/lib/config.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/Scripts/release/utils/notify.sh" ]]; then
    # shellcheck source=Scripts/release/utils/notify.sh
    source "$ROOT_DIR/Scripts/release/utils/notify.sh" 2>/dev/null || true
fi

# ============================================================================
# Pod Configuration
# ============================================================================
# Pod configurations - Single source of truth
# Order matters: dependencies must be released before dependents
# Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
# Release order based on dependencies (8 pods total: 7 release + MSPiOSCore)
POD_RELEASE_ORDER=(
    "MSPSharedLibraries"    # No dependencies
    "MSPFacebookAdapter"    # Depends on MSPSharedLibraries
    "MSPGoogleAdapter"      # Depends on MSPSharedLibraries
    "NovaAdapter"           # Depends on MSPSharedLibraries (OMSDK via NovaCore)
    "AmazonAdapter"         # Depends on MSPSharedLibraries
    "PrebidAdapter"         # Depends on MSPSharedLibraries
    "MSPCore"               # Depends on MSPSharedLibraries, PrebidAdapter
    "MSPiOSCore"            # No dependencies
)

# All pods to be released
ALL_PODS=("MSPSharedLibraries" "PrebidAdapter" "NovaAdapter" "MSPFacebookAdapter" "MSPGoogleAdapter" "AmazonAdapter" "MSPCore")

# Dependency mapping (using functions instead of associative arrays for bash 3.x compatibility)
# Stage B: MSPOMSDK removed - OMSDK now embedded in NovaCore
get_pod_dependencies_internal() {
    case "$1" in
        "MSPSharedLibraries") echo "" ;;
        "MSPFacebookAdapter") echo "MSPSharedLibraries" ;;
        "MSPGoogleAdapter") echo "MSPSharedLibraries" ;;
        "NovaAdapter") echo "MSPSharedLibraries" ;;  # Stage B: OMSDK via NovaCore
        "AmazonAdapter") echo "MSPSharedLibraries" ;;
        "PrebidAdapter") echo "MSPSharedLibraries" ;;
        "MSPCore") echo "MSPSharedLibraries PrebidAdapter" ;;
        "MSPiOSCore") echo "" ;;
        *) echo "" ;;
    esac
}

# Function to get pod dependencies
get_pod_dependencies() {
    local pod="$1"
    get_pod_dependencies_internal "$pod"
}

# Function to check if pod is valid
is_valid_pod() {
    local pod="$1"
    for allowed_pod in "${ALLOWED_PODS[@]}"; do
        if [[ "$pod" == "$allowed_pod" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to get release order for a specific pod
get_release_order_for_pod() {
    local target_pod="$1"
    local order=()
    
    # Add dependencies first
    local deps=$(get_pod_dependencies "$target_pod")
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            if [[ " ${POD_RELEASE_ORDER[@]} " =~ " $dep " ]]; then
                order+=("$dep")
            fi
        done
    fi
    
    # Add the target pod
    order+=("$target_pod")
    
    echo "${order[@]}"
}

# Function to validate release order
validate_release_order() {
    local pods=("$@")
    local errors=()
    
    for pod in "${pods[@]}"; do
        local deps=$(get_pod_dependencies "$pod")
        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                # Check if dependency comes before the pod in the release order
                local pod_index=-1
                local dep_index=-1
                
                for i in "${!POD_RELEASE_ORDER[@]}"; do
                    if [[ "${POD_RELEASE_ORDER[$i]}" == "$pod" ]]; then
                        pod_index=$i
                    fi
                    if [[ "${POD_RELEASE_ORDER[$i]}" == "$dep" ]]; then
                        dep_index=$i
                    fi
                done
                
                if [[ $dep_index -gt $pod_index ]]; then
                    errors+=("$pod depends on $dep, but $dep comes after $pod in release order")
                fi
            done
        fi
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Release order validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    return 0
}

# ============================================================================
# Project Utilities
# ============================================================================
# Function to get project root
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# Function to ensure project root
ensure_project_root() {
    local project_root=$(get_project_root)
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root"
    fi
}

# ============================================================================
# Release Notes Generation Functions
# ============================================================================
# Generate release notes from git commits
generate_release_notes_from_git() {
    local version="$1"
    local previous_version="${2:-}"
    local release_type="${3:-Release}"
    
    log_step "Generating release notes from git commits"
    
    # Get the previous tag if not provided
    if [[ -z "$previous_version" ]]; then
        previous_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    fi
    
    # Generate release notes
    local release_notes=""
    
    if [[ -n "$previous_version" ]]; then
        release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### Changes since ${previous_version}:\n\n"
        
        # Get commits since previous version
        local commits=$(git log --oneline --pretty=format:"- %s (%h)" "${previous_version}..HEAD" 2>/dev/null)
        
        if [[ -n "$commits" ]]; then
            release_notes+="$commits"
        else
            release_notes+="- No changes detected"
        fi
    else
        release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### Initial release\n\n"
        release_notes+="- First release of ${release_type}"
    fi
    
    echo "$release_notes"
}

# Generate release notes from template
generate_release_notes_from_template() {
    local version="$1"
    local release_type="${2:-Release}"
    local template_file="${3:-}"
    
    log_step "Generating release notes from template"
    
    if [[ -n "$template_file" && -f "$template_file" ]]; then
        # Use custom template
        local release_notes=$(cat "$template_file")
        # Replace placeholders
        release_notes=$(echo "$release_notes" | sed "s/{{VERSION}}/$version/g")
        release_notes=$(echo "$release_notes" | sed "s/{{RELEASE_TYPE}}/$release_type/g")
        release_notes=$(echo "$release_notes" | sed "s/{{DATE}}/$(date '+%Y-%m-%d')/g")
        echo "$release_notes"
    else
        # Use default template
        local release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### What's New\n"
        release_notes+="- Bug fixes and improvements\n"
        release_notes+="- Performance optimizations\n"
        release_notes+="- Enhanced stability\n\n"
        release_notes+="### Technical Details\n"
        release_notes+="- Version: ${version}\n"
        release_notes+="- Release Date: $(date '+%Y-%m-%d')\n"
        release_notes+="- Environment: $(get_environment_info)"
        echo "$release_notes"
    fi
}

# Generate simple release notes from bullet points
generate_simple_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    local bullet_points="$3"
    
    log_step "Generating simple release notes"
    
    local release_notes="## Release ${version}\n\n"
    release_notes+="### What's New\n"
    
    # Process bullet points - each line becomes a bullet point
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Remove leading dashes or bullets if present
            line=$(echo "$line" | sed 's/^[-•]\s*//')
            release_notes+="- ${line}\n"
        fi
    done <<< "$bullet_points"
    
    release_notes+="\n### Technical Details\n"
    release_notes+="- Version: ${version}\n"
    release_notes+="- Release Date: $(date '+%Y-%m-%d')\n"
    release_notes+="- Environment: $(get_environment_info)"
    
    echo "$release_notes"
}

# Prompt user for release notes
prompt_for_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    
    log_step "Prompting for release notes"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📝 Release Notes for ${release_type} ${version}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Please enter release notes (press Enter twice when done):"
    echo ""
    
    local release_notes=""
    local line
    local empty_lines=0
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            ((empty_lines++))
            if [[ $empty_lines -ge 2 ]]; then
                break
            fi
        else
            empty_lines=0
        fi
        
        if [[ -n "$release_notes" ]]; then
            release_notes+="\n$line"
        else
            release_notes="$line"
        fi
    done
    
    echo ""
    echo "Release notes captured:"
    echo "───────────────────────────────────────────────────────────────────"
    echo -e "$release_notes"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""
    
    echo "$release_notes"
}

# Get release notes from various sources
get_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    local source="${3:-auto}"
    local template_file="${4:-}"
    local previous_version="${5:-}"
    
    case "$source" in
        "git")
            generate_release_notes_from_git "$version" "$previous_version" "$release_type"
            ;;
        "template")
            generate_release_notes_from_template "$version" "$release_type" "$template_file"
            ;;
        "prompt")
            prompt_for_release_notes "$version" "$release_type"
            ;;
        "simple")
            # Use custom release notes as bullet points
            local custom_notes="${6:-}"
            if [[ -n "$custom_notes" ]]; then
                generate_simple_release_notes "$version" "$release_type" "$custom_notes"
            else
                log_warning "No custom notes provided for simple source"
                generate_release_notes_from_template "$version" "$release_type" "$template_file"
            fi
            ;;
        "auto")
            # Try git first, then fall back to template
            local git_notes=$(generate_release_notes_from_git "$version" "$previous_version" "$release_type")
            if [[ -n "$git_notes" && "$git_notes" != *"No changes detected"* ]]; then
                echo "$git_notes"
            else
                generate_release_notes_from_template "$version" "$release_type" "$template_file"
            fi
            ;;
        *)
            log_warning "Unknown release notes source: $source"
            generate_release_notes_from_template "$version" "$release_type" "$template_file"
            ;;
    esac
}

# ============================================================================
# Slack Notification Functions (Extracted to notify/slack.sh)
# ============================================================================
# Phase 1 Refactoring: Slack functions have been extracted to a dedicated module.
# This source statement provides backward compatibility.
# See: Scripts/notify/slack.sh for the implementation.

# Source the Slack notification module
if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
else
    # Fallback: Define stub functions if module not found
    log_warning "notify/slack.sh not found - Slack notifications will be disabled"
    send_slack_notification() { log_warning "Slack notifications disabled (module not found)"; }
    notify_release_success() { :; }
    notify_release_failure() { :; }
    notify_release_warning() { :; }
    notify_release_start() { :; }
    notify_pod_release() { :; }
    notify_release_summary() { :; }
    notify_release_success_with_summary() { :; }
    test_slack_notification() { log_error "Slack notifications disabled (module not found)"; return 1; }
fi

# Backward compatibility: Re-export environment functions
# These are now defined in notify/slack.sh but may be used by other scripts
get_environment() {
    get_slack_environment
}

get_environment_info() {
    get_slack_environment_info
}

# ============================================================================
# Backward Compatibility Wrappers
# ============================================================================
# Legacy function names for functions moved to utils modules

# Podspec functions (now in utils/podspec.sh)
update_podspec_dependency_version() {
    update_podspec_dependencies "$@"
}

update_podspec_to_zip_format() {
    update_podspec_source_to_zip "$@"
}

# ============================================================================
# Export Functions
# ============================================================================
# Export logging functions
export -f log_info log_success log_warning log_error log_step log_release log_debug print_section print_subsection log_warn 2>/dev/null || true

# Export pod configuration functions
export -f get_pod_dependencies is_valid_pod get_release_order_for_pod validate_release_order

# Export project utilities
export -f get_project_root ensure_project_root

# Export release notes functions
export -f generate_release_notes_from_git generate_release_notes_from_template generate_simple_release_notes prompt_for_release_notes get_release_notes

# Export environment functions (backward compatibility wrappers)
export -f get_environment get_environment_info

# Export legacy podspec functions (backward compatibility)
export -f update_podspec_dependency_version update_podspec_to_zip_format
export -f is_preflight_tier is_release_tier 2>/dev/null || true

# Note: Functions from utils modules are exported by their respective modules
# Note: Slack notification functions are exported by Scripts/notify/slack.sh
# Note: Functions from utils/notify.sh are exported by that module
