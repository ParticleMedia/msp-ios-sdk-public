#!/usr/bin/env bash
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
# ROOT_DIR Calculation (using path-helpers.sh)
# ============================================================================
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
# Note: SCRIPT_DIR is NOT set here - this is a library, not an entry script.
# Entry scripts should set their own SCRIPT_DIR after sourcing this file.

# ============================================================================
# UI System Loading (UI-First Rule)
# ============================================================================
# Handle NO_ANSI flag by setting NO_COLOR (logging respects NO_COLOR)
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

if [[ -f "$ROOT_DIR/Scripts/lib/common.sh" ]]; then
    # shellcheck source=Scripts/lib/common.sh
    source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
fi

# ============================================================================
# Fallback Logging Functions (if unified logging system not available)
# ============================================================================
# Only define fallbacks if new logging API is not available
if ! command -v log::info &>/dev/null; then
    # Fallback color definitions
    : "${RED:=\033[0;31m}"
    : "${GREEN:=\033[0;32m}"
    : "${YELLOW:=\033[1;33m}"
    : "${BLUE:=\033[0;34m}"
    : "${PURPLE:=\033[0;35m}"
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

    # Alias log_warn to log_warning for compatibility
    log_warn() {
        log_warning "$@"
    }
fi

# ============================================================================
# UI Helper Functions (always available, not part of fallback)
# ============================================================================
# These functions are used for visual formatting and should always be available
# regardless of whether the unified logging system is loaded

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
        echo -e "${BLUE:-\033[0;34m}--- $1 ---${NC:-\033[0m}"
    fi
}

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
if [[ -f "$ROOT_DIR/Scripts/release/utils/version.sh" ]]; then
    # shellcheck source=Scripts/release/utils/version.sh
    source "$ROOT_DIR/Scripts/release/utils/version.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/Scripts/release/utils/retry.sh" ]]; then
    # shellcheck source=Scripts/release/utils/retry.sh
    source "$ROOT_DIR/Scripts/release/utils/retry.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
    # shellcheck source=Scripts/release/utils/state.sh
    source "$ROOT_DIR/Scripts/release/utils/state.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/Scripts/release/utils/podspec.sh" ]]; then
    # shellcheck source=Scripts/release/utils/podspec.sh
    source "$ROOT_DIR/Scripts/release/utils/podspec.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/Scripts/release/utils/github.sh" ]]; then
    # shellcheck source=Scripts/release/utils/github.sh
    source "$ROOT_DIR/Scripts/release/utils/github.sh" 2>/dev/null || true
fi
# ============================================================================
# Release Mode Helpers (Phase B)
# ============================================================================
# Helper functions to determine if we're running in dry-run or production mode

is_dry_run_mode() {
    # Phase B: Use DRY_RUN for mode control
    local dry_run="${DRY_RUN:-true}"
    if [[ "$dry_run" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

is_production_mode() {
    # Phase B: Use DRY_RUN for mode control
    local dry_run="${DRY_RUN:-true}"
    if [[ "$dry_run" == "false" ]]; then
        # Check if real publish is allowed on this branch
        if command -v should_real_publish &>/dev/null; then
            if ! should_real_publish; then
                local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
                log::error "RELEASE" "[BLOCKED] Real publish not allowed on branch: $branch"
                log::error "RELEASE" "[BLOCKED] Check Scripts/config/release.yaml for branch policy"
                return 1
            fi
        fi
        return 0
    else
        return 1
    fi
}

# Backward compatibility aliases (deprecated)
is_preflight_tier() {
    is_dry_run_mode
}

is_release_tier() {
    is_production_mode
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

get_pod_dependencies() {
    local pod="$1"
    get_pod_dependencies_internal "$pod"
}

is_valid_pod() {
    local pod="$1"
    for allowed_pod in "${ALLOWED_PODS[@]}"; do
        if [[ "$pod" == "$allowed_pod" ]]; then
            return 0
        fi
    done
    return 1
}

get_release_order_for_pod() {
    local target_pod="$1"
    local order=()

    local deps=$(get_pod_dependencies "$target_pod")
    if [[ -n "$deps" ]]; then
        # shellcheck disable=SC2086 -- intentional word-splitting: deps is a space-delimited name list
        for dep in $deps; do
            if [[ " ${POD_RELEASE_ORDER[@]} " =~ " $dep " ]]; then
                order+=("$dep")
            fi
        done
    fi

    order+=("$target_pod")
    
    echo "${order[@]}"
}

validate_release_order() {
    local pods=("$@")
    local errors=()
    
    for pod in "${pods[@]}"; do
        local deps=$(get_pod_dependencies "$pod")
        if [[ -n "$deps" ]]; then
            # shellcheck disable=SC2086 -- intentional word-splitting: deps is a space-delimited name list
        for dep in $deps; do
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
        log::error "RELEASE" "Release order validation failed:"
        for error in "${errors[@]}"; do
            log::error "RELEASE" "  - $error"
        done
        return 1
    fi
    
    return 0
}

# ============================================================================
# Project Utilities
# ============================================================================
# Note: This file lives at Scripts/lib/release-common.sh, so /../.. goes to project root
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Prefers ROOT_DIR (set by path-helpers.sh) for reliability
ensure_project_root() {
    local project_root="${ROOT_DIR:-$(get_project_root)}"
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root"
    fi
}

# ============================================================================
# Release Notes Generation Functions
# ============================================================================
generate_release_notes_from_git() {
    local version="$1"
    local previous_version="${2:-}"
    local release_type="${3:-Release}"

    log::step "RELEASE" "Generating release notes from git commits"

    if [[ -z "$previous_version" ]]; then
        previous_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    fi

    local release_notes=""
    
    if [[ -n "$previous_version" ]]; then
        release_notes="## ${release_type} ${version}\n\n"
        release_notes+="### Changes since ${previous_version}:\n\n"

        # Get only PR merge commits (squash-merged PRs contain "(#NNN)" in subject)
        local commits=$(git log --oneline --pretty=format:"- %s" --grep='(#' "${previous_version}..HEAD" 2>/dev/null)

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

generate_release_notes_from_template() {
    local version="$1"
    local release_type="${2:-Release}"
    local template_file="${3:-}"

    log::step "RELEASE" "Generating release notes from template"
    
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

generate_simple_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"
    local bullet_points="$3"

    log::step "RELEASE" "Generating simple release notes"
    
    local release_notes="## Release ${version}\n\n"
    release_notes+="### What's New\n"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
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

prompt_for_release_notes() {
    local version="$1"
    local release_type="${2:-Release}"

    log::step "RELEASE" "Prompting for release notes"
    
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
            ((empty_lines++)) || true
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
            local custom_notes="${6:-}"
            if [[ -n "$custom_notes" ]]; then
                generate_simple_release_notes "$version" "$release_type" "$custom_notes"
            else
                log::warn "RELEASE" "No custom notes provided for simple source"
                generate_release_notes_from_template "$version" "$release_type" "$template_file"
            fi
            ;;
        "auto")
            local git_notes=$(generate_release_notes_from_git "$version" "$previous_version" "$release_type")
            if [[ -n "$git_notes" && "$git_notes" != *"No changes detected"* ]]; then
                echo "$git_notes"
            else
                generate_release_notes_from_template "$version" "$release_type" "$template_file"
            fi
            ;;
        *)
            log::warn "RELEASE" "Unknown release notes source: $source"
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

if [[ -f "$ROOT_DIR/Scripts/notify/slack.sh" ]]; then
    # shellcheck source=Scripts/notify/slack.sh
    source "$ROOT_DIR/Scripts/notify/slack.sh"
else
    # Fallback: Define stub functions if module not found
    log::warn "RELEASE" "notify/slack.sh not found - Slack notifications will be disabled"
    send_slack_notification() { log::warn "RELEASE" "Slack notifications disabled (module not found)"; }
    notify_release_success() { :; }
    notify_release_failure() { :; }
    notify_release_warning() { :; }
    notify_release_start() { :; }
    notify_pod_release() { :; }
    notify_release_summary() { :; }
    notify_release_success_with_summary() { :; }
    test_slack_notification() { log::error "RELEASE" "Slack notifications disabled (module not found)"; return 1; }
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
export -f log_info log_success log_warning log_error log_step log_release log_debug print_section print_subsection log_warn 2>/dev/null || true
export -f get_pod_dependencies is_valid_pod get_release_order_for_pod validate_release_order
export -f get_project_root ensure_project_root
export -f generate_release_notes_from_git generate_release_notes_from_template generate_simple_release_notes prompt_for_release_notes get_release_notes
export -f get_environment get_environment_info
export -f update_podspec_dependency_version update_podspec_to_zip_format
export -f is_preflight_tier is_release_tier 2>/dev/null || true

# Note: Functions from utils modules are exported by their respective modules
# Note: Slack notification functions are exported by Scripts/notify/slack.sh
# Note: Functions from utils/notify.sh are exported by that module
