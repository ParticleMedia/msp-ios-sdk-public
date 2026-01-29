#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Podspec Utilities for Release Scripts
# Provides functions for podspec manipulation and validation

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
    : "${RED:=[0;31m}"
    : "${GREEN:=[0;32m}"
    : "${YELLOW:=[1;33m}"
    : "${BLUE:=[0;34m}"
    : "${NC:=[0m}"
    
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


# Source cocoapods.sh for podspec validation and publishing functions
if [[ -f "$ROOT_DIR/Scripts/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$ROOT_DIR/Scripts/lib/cocoapods.sh" 2>/dev/null || true
fi

# Update podspec version
update_podspec_version() {
    local podspec_file="$1"
    local version="$2"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    log_step "Updating version in $podspec_file to $version"
    
    # Create backup
    cp "$podspec_file" "${podspec_file}.backup"
    
    # Update version
    sed -i '' "s|spec\.version.*=.*\".*\"|spec.version = \"${version}\"|g" "$podspec_file"
    
    log_success "Updated version in $podspec_file to $version"
}

# Update podspec source to HTTP zip format
update_podspec_source_to_zip() {
    local podspec_file="$1"
    local version="$2"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    log_step "Updating source in $podspec_file to HTTP zip format"
    
    # Create backup
    cp "$podspec_file" "${podspec_file}.backup"
    
    # Get pod name from podspec file
    local pod_name=$(basename "$podspec_file" .podspec)
    local http_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod_name}-${version}.zip"
    
    # Update source to use HTTP zip format
    sed -i '' "s|spec\.source.*=.*{.*:git.*=>.*\"https://github\.com/.*\.git\".*:tag.*=>.*\"#{spec\.version}\".*}|spec.source = {\n    http: \"${http_url}\",\n    type: \"zip\"\n  }|g" "$podspec_file"
    
    log_success "Updated $podspec_file to use HTTP zip source format"
}

# Update podspec dependencies
update_podspec_dependencies() {
    local podspec_file="$1"
    local dependency_name="$2"
    local version="$3"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    if [[ -z "$dependency_name" || -z "$version" ]]; then
        log_error "Dependency name and version are required"
        return 1
    fi
    
    log_step "Updating $dependency_name dependency to version $version in $podspec_file"
    
    # Update dependency version
    sed -i '' "s|spec\.dependency '$dependency_name'[^,]*|spec.dependency '$dependency_name', '$version'|g" "$podspec_file"
    
    log_success "Updated $dependency_name dependency to version $version in $podspec_file"
}

# Phase R1.9: Private function to execute pod spec lint exactly once (no recursion)
_msp_podspec_lint_once() {
    local podspec_file="$1"

    # Recursion guard: Fail-fast if already inside validation
    if [[ -n "${_MSP_VALIDATE_PODSPEC_GUARD:-}" ]]; then
        log_error "[RECURSION DETECTED] Already inside podspec validation, aborting to prevent infinite loop"
        return 1
    fi

    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi

    # Set recursion guard
    export _MSP_VALIDATE_PODSPEC_GUARD=1

    log_step "Validating podspec: $(basename "$podspec_file")"

    # Execute pod spec lint once (no function calls, no recursion possible)
    # Run with timeout: 30 minutes (1800s)
    # Rationale: Observed 1-5 min, extreme cases up to 20 min (complex deps), 30 min provides safety margin
    local lint_result=0
    if run_with_timeout 1800 pod spec lint "$podspec_file" --allow-warnings 2>&1; then
        log_success "Podspec validation passed: $(basename "$podspec_file")"
        lint_result=0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "❌ TIMEOUT: pod spec lint exceeded 30 minutes for $(basename "$podspec_file")"
            log_error "This usually indicates dependency resolution hanging or network issues"
        else
            log_error "Podspec validation failed: $(basename "$podspec_file")"
        fi
        lint_result=1
    fi

    # Clear recursion guard
    unset _MSP_VALIDATE_PODSPEC_GUARD

    return $lint_result
}

# Validate podspec (public wrapper - calls validate_podspec_with_retry)
validate_podspec() {
    local podspec_file="$1"

    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi

    # Simply call validate_podspec_with_retry (no recursion possible)
    validate_podspec_with_retry "$podspec_file"
}

# Publish podspec (wrapper around publish_podspec from cocoapods.sh)
# Phase R1.15: Private implementation - podspec publishing (prevents recursion)
_msp_podspec_publish_once() {
    local podspec_file="$1"

    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi

    log_step "Publishing podspec: $podspec_file"
    if msp_run_pod_trunk_push "$podspec_file"; then
        log_success "Podspec published: $podspec_file"
        return 0
    else
        log_error "Failed to publish podspec: $podspec_file"
        return 1
    fi
}

# Phase R1.15: Public wrapper (for backward compatibility)
publish_podspec() {
    local podspec_file="$1"

    # Recursion guard (Phase R1.15)
    if [[ "${_MSP_PUBLISH_PODSPEC_GUARD:-0}" == "1" ]]; then
        log_error "[BUG] publish_podspec recursion detected"
        return 1
    fi

    export _MSP_PUBLISH_PODSPEC_GUARD=1
    _msp_podspec_publish_once "$podspec_file"
    local result=$?
    export _MSP_PUBLISH_PODSPEC_GUARD=0

    return $result
}

# Check if pod is available (wrapper around check_pod_availability from cocoapods.sh)
check_pod_available() {
    local pod_name="$1"
    local version="${2:-}"
    
    if [[ -z "$pod_name" ]]; then
        log_error "Pod name is required"
        return 1
    fi
    
    # Use check_pod_availability from cocoapods.sh if available
    if command -v check_pod_availability &>/dev/null; then
        if [[ -n "$version" ]]; then
            check_pod_availability "$pod_name" "$version"
        else
            check_pod_availability "$pod_name"
        fi
    else
        log_step "Checking if pod $pod_name is available"
        if pod search "$pod_name" --simple 2>/dev/null | grep -q "$pod_name"; then
            log_success "Pod $pod_name is available"
            return 0
        else
            log_warning "Pod $pod_name is not available"
            return 1
        fi
    fi
}

# Legacy function names (for backward compatibility)
update_podspec_dependency_version() {
    update_podspec_dependencies "$@"
}

update_podspec_to_zip_format() {
    update_podspec_source_to_zip "$@"
}

# Phase R1.9: Validate podspec with retry logic (calls _msp_podspec_lint_once only)
validate_podspec_with_retry() {
    local podspec="$1"
    local max_attempts=3
    local base_delay=5

    log_step "Validating podspec with retry: $(basename "$podspec")"

    # Call _msp_podspec_lint_once in retry loop (breaks recursion chain)
    if command -v retry_with_backoff &>/dev/null; then
        retry_with_backoff $max_attempts $base_delay "podspec validation" \
            _msp_podspec_lint_once "$podspec"
    else
        _msp_podspec_lint_once "$podspec"
    fi
}

# Publish podspec with retry logic
publish_podspec_with_retry() {
    local podspec="$1"
    local max_attempts=3
    local base_delay=10
    
    log_step "Publishing podspec with retry: $(basename "$podspec")"
    
    # First update the specs repo with retry (if function exists)
    if command -v update_specs_repo &>/dev/null && command -v retry_with_backoff &>/dev/null; then
        if ! retry_with_backoff 3 5 "specs repo update" update_specs_repo; then
            log_warning "Failed to update specs repo, continuing anyway..."
        fi
    elif command -v update_specs_repo &>/dev/null; then
        # Try without retry if retry_with_backoff not available
        update_specs_repo || log_warning "Failed to update specs repo, continuing anyway..."
    fi
    
    # Then publish with retry (Phase R1.15: call private implementation directly)
    if command -v retry_with_backoff &>/dev/null; then
        retry_with_backoff $max_attempts $base_delay "podspec publishing" \
            _msp_podspec_publish_once "$podspec"
    else
        _msp_podspec_publish_once "$podspec"
    fi
}

# Wait for pod availability (wrapper around check_pod_availability from cocoapods.sh)
wait_for_pod_availability() {
    local pod_name="$1"
    local version="${2:-}"
    local max_wait="${3:-300}"  # Default 5 minutes
    local interval="${4:-10}"   # Default 10 seconds
    
    if [[ -z "$pod_name" ]]; then
        log_error "Pod name is required"
        return 1
    fi
    
    # Use check_pod_availability from cocoapods.sh if available
    if command -v check_pod_availability &>/dev/null; then
        if command -v wait_for_condition &>/dev/null; then
            # Use wait_for_condition for polling
            local check_cmd="check_pod_availability $pod_name"
            if [[ -n "$version" ]]; then
                check_cmd="check_pod_availability $pod_name $version"
            fi
            wait_for_condition "$check_cmd" "$max_wait" "$interval" "pod $pod_name availability"
        else
            # Simple polling loop
            local elapsed=0
            while [[ $elapsed -lt $max_wait ]]; do
                if [[ -n "$version" ]]; then
                    check_pod_availability "$pod_name" "$version" && return 0
                else
                    check_pod_availability "$pod_name" && return 0
                fi
                sleep "$interval"
                elapsed=$((elapsed + interval))
            done
            log_error "Pod $pod_name not available after ${max_wait} seconds"
            return 1
        fi
    else
        log_warning "check_pod_availability not available, cannot wait for pod"
        return 1
    fi
}

# Export functions
export -f update_podspec_version update_podspec_source_to_zip update_podspec_dependencies \
export -f msp_run_pod_trunk_push 2>/dev/null || true
    validate_podspec publish_podspec check_pod_available \
    update_podspec_dependency_version update_podspec_to_zip_format \
    validate_podspec_with_retry publish_podspec_with_retry wait_for_pod_availability 2>/dev/null || true


# ============================================================================
# CocoaPods Trunk Push with Tier Awareness (Patch M)
# ============================================================================
msp_run_pod_trunk_push() {
    local spec="$1"
    
    if [[ -z "$spec" ]]; then
        log_error "[PODS] msp_run_pod_trunk_push: spec file is required"
        return 1
    fi

    # Source release-common.sh for config-driven gating
    if [[ -f "$ROOT_DIR/Scripts/lib/release-common.sh" ]]; then
        source "$ROOT_DIR/Scripts/lib/release-common.sh" 2>/dev/null || true
    fi

    # Source config if not already loaded
    if ! command -v should_real_publish &>/dev/null; then
        if [[ -f "$ROOT_DIR/Scripts/release/lib/config.sh" ]]; then
            source "$ROOT_DIR/Scripts/release/lib/config.sh" 2>/dev/null || true
            msp_load_release_config 2>/dev/null || true
        fi
    fi

    # Config-driven gating: skip if pods.enabled is false
    if ! is_enabled "pods.enabled"; then
        log_info "[PODS] [CONFIG] Skipping pod trunk push (config: pods.enabled=false, spec: $spec)"
        log_info "[PODS] [CONFIG] Running pod spec lint instead to validate podspec"

        # Run with timeout: 10 minutes (600s) for quick lint
        # Rationale: Quick lint is fast (10-60s), but 10 min provides safety margin
        if ! run_with_timeout 600 pod spec lint "$spec" --allow-warnings; then
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log_warn "[PODS] pod spec lint TIMED OUT after 10 minutes (config: pods.enabled=false). Treating as non-fatal."
            else
                log_warn "[PODS] pod spec lint failed for $spec (config: pods.enabled=false). Treating as non-fatal."
            fi
            return 0
        fi

        return 0
    fi
    
    # Real release tier behavior - check config (Patch M+CONFIG)
    if ! should_real_publish; then
        local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        log_error "[PODS][BLOCKED] Real pod trunk push not allowed on branch: $branch"
        log_error "[PODS][BLOCKED] Check Scripts/release/config/release_config.yaml for branch policy"
        return 1
    fi
    
    # ============================================================================
    # Idempotency Check: Detect if version already published
    # ============================================================================
    # Strategy: Query CocoaPods trunk to check if version exists
    # Fail-safe: If check fails, proceed with publish (don't skip)
    # ============================================================================
    
    # Extract pod name and version from podspec file
    local pod_name
    local pod_version
    
    if [[ -f "$spec" ]]; then
        # Extract pod name from podspec (spec.name or Pod::Spec.new do |spec|)
        pod_name=$(grep -E "^[[:space:]]*spec\.name[[:space:]]*=" "$spec" | head -1 | sed -E "s/.*spec\.name[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" || \
                   grep -E "^[[:space:]]*Pod::Spec\.new" "$spec" | head -1 | sed -E "s/.*Pod::Spec\.new[[:space:]]+do[[:space:]]+\|[[:space:]]*([^|]+)[[:space:]]*\|.*/\1/" || \
                   basename "$spec" .podspec)
        
        # Extract version from podspec (spec.version)
        pod_version=$(grep -E "^[[:space:]]*spec\.version[[:space:]]*=" "$spec" | head -1 | sed -E "s/.*spec\.version[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" || \
                      grep -E "^[[:space:]]*spec\.version[[:space:]]*=" "$spec" | head -1 | sed -E "s/.*spec\.version[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/")
    else
        log_error "[PODS] Podspec file not found: $spec"
        return 1
    fi
    
    if [[ -z "$pod_name" ]] || [[ -z "$pod_version" ]]; then
        log_warn "[PODS] Could not extract pod name or version from podspec, skipping idempotency check"
        log_warn "[PODS] Pod name: ${pod_name:-<empty>}, Version: ${pod_version:-<empty>}"
    else
        log_info "[PODS] Performing idempotency check: querying CocoaPods trunk for ${pod_name}..."
        
        # Execute pod trunk info and capture output + exit code
        local trunk_info_output
        local trunk_info_exit_code
        
        trunk_info_output=$(pod trunk info "$pod_name" 2>&1)
        trunk_info_exit_code=$?
        
        if [[ $trunk_info_exit_code -eq 0 ]]; then
            # Command succeeded, check if version exists in output
            # Use grep with fixed string to avoid partial matches
            # Example output format from pod trunk info:
            #   - Versions:
            #     - 0.1.0-rc.1 (2025-12-16 04:10:04 UTC)
            #     - 0.1.0-rc.0 (2025-12-15 10:00:00 UTC)
            
            # Match pattern: "- <VERSION> (" to ensure exact version match
            # The space and parenthesis ensure we don't match 0.1.0 when looking for 0.1.0-rc.1
            # Use -- to separate options from pattern to avoid issues with version strings starting with -
            if echo "$trunk_info_output" | grep -- "- ${pod_version} (" >/dev/null 2>&1; then
                log_success "[PODS] ✅ ${pod_name} ${pod_version} already published to CocoaPods trunk"
                log_info "[PODS] Idempotency: Skipping duplicate pod trunk push"
                local publish_timestamp
                publish_timestamp=$(echo "$trunk_info_output" | grep -- "- ${pod_version} (" | head -1 | sed 's/.*(\(.*\))/\1/')
                log_info "[PODS] Published timestamp: ${publish_timestamp:-unknown}"
                return 0
            else
                log_info "[PODS] Version ${pod_version} not found in trunk, proceeding with publish"
            fi
        else
            # Command failed - could be network error, pod doesn't exist yet, or auth issue
            # Fail-safe: Don't skip, proceed with publish attempt
            log_info "[PODS] ⚠️  pod trunk info failed (exit code: ${trunk_info_exit_code})"
            log_info "[PODS] This may be normal for first-time pod publishing or network issues"
            log_info "[PODS] Proceeding with publish attempt (fail-safe behavior)"
        fi
    fi
    
    # Production mode (DRY_RUN=false) - proceed with trunk push
    # Note: MSP_ALLOW_TRUNK_PUSH guard removed - redundant with DRY_RUN control
    log_info "[PODS] Running pod trunk push for $spec"
    log_info "[PODS] Timeout: 30 minutes (1800s)"
    
    # Run with timeout: 30 minutes (1800s)
    # Rationale: Observed 5-15 min, extreme cases up to 25 min, 30 min provides safety margin
    # Use tee to capture output in real-time while also displaying it
    local push_log_file
    push_log_file=$(mktemp "/tmp/pod_trunk_push_${RANDOM}.log")

    # Ensure cleanup on exit (normal or interrupted)
    trap "rm -f '$push_log_file'" EXIT INT TERM

    log_info "[PODS] Executing: pod trunk push \"$spec\" --allow-warnings"
    log_info "[PODS] Output will be captured to: $push_log_file"

    # Run with timeout and capture output in real-time using tee
    # tee outputs to both stdout (for real-time viewing) and file (for later reference)
    # Use PIPESTATUS to get the actual exit code of run_with_timeout, not tee
    run_with_timeout 1800 pod trunk push "$spec" --allow-warnings 2>&1 | tee "$push_log_file"
    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        log_success "[PODS] ✅ Successfully pushed $spec to trunk"
        rm -f "$push_log_file"
        return 0
    elif [[ $exit_code -eq 124 ]]; then
        log_error "[PODS] ❌ TIMEOUT: pod trunk push exceeded 30 minutes"
        log_error "[PODS] This usually indicates:"
        log_error "  1. Network connectivity issues"
        log_error "  2. CocoaPods trunk server is slow or down"
        log_error "  3. Podspec validation is taking too long"
        log_error ""
        log_error "Troubleshooting:"
        log_error "  1. Check network: curl -I https://trunk.cocoapods.org"
        log_error "  2. Check podspec locally: pod spec lint $spec --allow-warnings"
        log_error "  3. Try again in a few minutes (server may be slow)"
        log_error "  4. Review captured output: $push_log_file"
        return 1
    else
        log_error "[PODS] ❌ pod trunk push failed with exit code $exit_code"
        log_error "[PODS] Review captured output for details: $push_log_file"
        return $exit_code
    fi
}

# ============================================================================
# Smart Wait Strategy with User Interaction
# ============================================================================
# Generic intelligent waiting strategy for pod availability
# Handles CDN sync delays (can be 30-40 minutes) with user control
#
# Usage: smart_wait_for_pod_availability <pod_name> <version> [context_description]
#
# Example:
#   smart_wait_for_pod_availability "MSPiOSCore" "0.3.0-rc.1" "before parallel adapter releases"
#
smart_wait_for_pod_availability() {
    local pod_name="$1"
    local version="$2"
    local context="${3:-}"

    # Skip waiting in DRY_RUN mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Skipping pod availability wait for $pod_name $version"
        return 0
    fi

    if [[ -z "$pod_name" || -z "$version" ]]; then
        log_error "Usage: smart_wait_for_pod_availability <pod_name> <version> [context]"
        return 1
    fi

    local context_msg=""
    if [[ -n "$context" ]]; then
        context_msg=" ($context)"
    fi

    log_section "Checking $pod_name $version availability$context_msg"

    # ═══════════════════════════════════════════════════════════════════════════
    # Stage 1: Quick check (3 minutes with longer intervals)
    # ═══════════════════════════════════════════════════════════════════════════
    # Changed from 120s/10s to 180s/30s (6 checks → 6 checks but less overhead)
    # With caching, each check now takes 5-10s instead of 50-60s
    # Total Stage 1 time: ~3 minutes (much faster than before despite longer timeout)
    log_step "Quick check: Is $pod_name $version available? (3 min timeout, 30s intervals)..."

    if wait_for_pod_availability "$pod_name" "$version" 180 30; then
        log_success "✓ $pod_name $version is available!"
        return 0
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # Stage 2: Not available - present options
    # ═══════════════════════════════════════════════════════════════════════════
    log_warn "✗ $pod_name $version not available yet (checked for 3 minutes)"
    echo ""
    log_info "═══════════════════════════════════════════════════════════════════════════"
    log_info "$pod_name $version was recently published. CDN sync can take 5-30 minutes."
    log_info "Context: $context"
    log_info "═══════════════════════════════════════════════════════════════════════════"
    echo ""
    log_info "Options:"
    log_info "  1. Continue waiting (up to 40 more minutes) - Recommended for just-published pods"
    log_info "  2. Try proceeding anyway (may fail if pod not synced)"
    log_info "  3. Exit and retry later (safe choice)"
    echo ""

    local choice

    # CI/Batch mode or non-interactive: auto-select option 1
    # Check if stdin is a TTY (interactive) or if CI/BATCH_MODE is set
    if [[ "${CI:-false}" == "true" ]] || [[ "${BATCH_MODE:-false}" == "true" ]] || ! [[ -t 0 ]]; then
        log_info "[Non-Interactive Mode] Auto-selecting: Continue waiting (option 1)"
        choice="1"
    else
        # Interactive mode: ask user
        read -p "Choose [1/2/3]: " choice
    fi

    case "$choice" in
        1)
            # ═══════════════════════════════════════════════════════════════════════════
            # Stage 3: Long wait (up to 57 more minutes total)
            # ═══════════════════════════════════════════════════════════════════════════
            # Increased from 1620s (27 min) to 3420s (57 min)
            # Total: 180 + 3420 = 3600s (60 minutes)
            # Rationale: Observed 10-25 min, extreme cases up to 40-60 min
            log_info "Continuing to wait for $pod_name $version (up to 57 more minutes)..."
            log_info "CDN propagation can take 10-60 minutes depending on network and load"
            log_info "Checking every 60 seconds. Press Ctrl+C to abort."
            echo ""

            # 57 minutes = 3420 seconds (60 total - 3 already waited)
            if ! wait_for_pod_availability "$pod_name" "$version" 3420 60; then
                log_error "$pod_name $version still not available after 60 minutes total"
                log_error "This is unusual. Please check:"
                log_error "  1. Did $pod_name $version publish succeed?"
                log_error "     Command: pod trunk info $pod_name"
                log_error "  2. Is CocoaPods CDN having issues?"
                log_error "     Check: https://status.cocoapods.org"
                log_error "  3. Try manual check:"
                log_error "     pod repo update && pod search $pod_name | grep $version"
                return 1
            fi

            log_success "✓ $pod_name $version is now available!"
            return 0
            ;;

        2)
            log_warn "Proceeding without $pod_name $version availability confirmation"
            log_warn "Subsequent operations may fail if pod not synced to CDN yet"
            echo ""
            read -p "Press Enter to continue..."
            echo ""
            return 0
            ;;

        3)
            log_info "Exiting. Please retry after CDN sync completes."
            log_info "To check manually: pod search $pod_name | grep $version"
            return 1
            ;;

        *)
            log_error "Invalid choice: $choice"
            return 1
            ;;
    esac
}

# Export the function
export -f smart_wait_for_pod_availability 2>/dev/null || true

