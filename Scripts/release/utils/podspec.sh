#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

# Podspec Utilities for Release Scripts
# Provides functions for podspec manipulation and validation

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

# R040d: Source config loader extension for CocoaPods settings
if [[ -f "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" ]]; then
    # shellcheck source=Scripts/lib/config_loader_ext.sh
    source "$ROOT_DIR/Scripts/lib/config_loader_ext.sh" 2>/dev/null || true
    load_cocoapods_config 2>/dev/null || true
fi

# Fallback logging functions if neither logging system loaded
if ! command -v log_info &>/dev/null && ! command -v log::info &>/dev/null; then
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
        log::warn "PODSPEC" "$@"
    }
fi


if [[ -f "$ROOT_DIR/Scripts/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$ROOT_DIR/Scripts/lib/cocoapods.sh" 2>/dev/null || true
fi

update_podspec_version() {
    local podspec_file="$1"
    local version="$2"
    
    if [[ ! -f "$podspec_file" ]]; then
        log::error "PODSPEC" "Podspec file not found: $podspec_file"
        return 1
    fi
    
    log::step "PODSPEC" "Updating version in $podspec_file to $version"

    # Update version (in-place, no backup needed — files are in worktree)
    sed -i '' "s|spec\.version.*=.*\".*\"|spec.version = \"${version}\"|g" "$podspec_file"

    log::success "PODSPEC" "Updated version in $podspec_file to $version"
}

update_podspec_source_to_zip() {
    local podspec_file="$1"
    local version="$2"

    if [[ ! -f "$podspec_file" ]]; then
        log::error "PODSPEC" "Podspec file not found: $podspec_file"
        return 1
    fi

    log::step "PODSPEC" "Updating source in $podspec_file to HTTP zip format"
    
    local pod_name=$(basename "$podspec_file" .podspec)
    local http_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${pod_name}-${version}.zip"
    
    sed -i '' "s|spec\.source.*=.*{.*:git.*=>.*\"https://github\.com/.*\.git\".*:tag.*=>.*\"#{spec\.version}\".*}|spec.source = {\n    http: \"${http_url}\",\n    type: \"zip\"\n  }|g" "$podspec_file"
    
    log::success "PODSPEC" "Updated $podspec_file to use HTTP zip source format"
}

update_podspec_dependencies() {
    local podspec_file="$1"
    local dependency_name="$2"
    local version="$3"
    
    if [[ ! -f "$podspec_file" ]]; then
        log::error "PODSPEC" "Podspec file not found: $podspec_file"
        return 1
    fi
    
    if [[ -z "$dependency_name" || -z "$version" ]]; then
        log::error "PODSPEC" "Dependency name and version are required"
        return 1
    fi
    
    log::step "PODSPEC" "Updating $dependency_name dependency to version $version in $podspec_file"
    
    # Update dependency version
    sed -i '' "s|spec\.dependency '$dependency_name'[^,]*|spec.dependency '$dependency_name', '$version'|g" "$podspec_file"
    
    log::success "PODSPEC" "Updated $dependency_name dependency to version $version in $podspec_file"
}

# Phase R1.9: Private function to execute pod spec lint exactly once (no recursion)
_msp_podspec_lint_once() {
    local podspec_file="$1"

    # Recursion guard: Fail-fast if already inside validation
    if [[ -n "${_MSP_VALIDATE_PODSPEC_GUARD:-}" ]]; then
        log::error "PODSPEC" "[RECURSION DETECTED] Already inside podspec validation, aborting to prevent infinite loop"
        return 1
    fi

    if [[ ! -f "$podspec_file" ]]; then
        log::error "PODSPEC" "Podspec file not found: $podspec_file"
        return 1
    fi

    # Set recursion guard (do NOT export - each process has its own guard)
    _MSP_VALIDATE_PODSPEC_GUARD=1

    log::step "PODSPEC" "Validating podspec: $(basename "$podspec_file")"

    # R040d: Use configurable timeout from cocoapods-config.yaml
    local lint_timeout="${PODS_SPEC_LINT_TIMEOUT:-1800}"

    # Execute pod spec lint once (no function calls, no recursion possible)
    # Rationale: Observed 1-5 min, extreme cases up to 20 min (complex deps), 30 min provides safety margin
    local lint_result=0
    if run_with_timeout "$lint_timeout" pod spec lint "$podspec_file" --allow-warnings 2>&1; then
        log::success "PODSPEC" "Podspec validation passed: $(basename "$podspec_file")"
        lint_result=0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log::error "PODSPEC" "❌ TIMEOUT: pod spec lint exceeded $((lint_timeout/60)) minutes for $(basename "$podspec_file")"
            log::error "PODSPEC" "This usually indicates dependency resolution hanging or network issues"
        else
            log::error "PODSPEC" "Podspec validation failed: $(basename "$podspec_file")"
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
        log::error "PODSPEC" "Podspec file not found: $podspec_file"
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
        log::error "PODSPEC" "Podspec file not found: $podspec_file"
        return 1
    fi

    log::step "PODSPEC" "Publishing podspec: $podspec_file"
    if msp_run_pod_trunk_push "$podspec_file"; then
        log::success "PODSPEC" "Podspec published: $podspec_file"
        return 0
    else
        log::error "PODSPEC" "Failed to publish podspec: $podspec_file"
        return 1
    fi
}

# Phase R1.15: Public wrapper (for backward compatibility)
publish_podspec() {
    local podspec_file="$1"

    # Recursion guard (Phase R1.15)
    if [[ "${_MSP_PUBLISH_PODSPEC_GUARD:-0}" == "1" ]]; then
        log::error "PODSPEC" "[BUG] publish_podspec recursion detected"
        return 1
    fi

    # Guard variables - do NOT export (each process has its own guard)
    _MSP_PUBLISH_PODSPEC_GUARD=1
    _msp_podspec_publish_once "$podspec_file"
    local result=$?
    _MSP_PUBLISH_PODSPEC_GUARD=0

    return $result
}

check_pod_available() {
    local pod_name="$1"
    local version="${2:-}"
    
    if [[ -z "$pod_name" ]]; then
        log::error "PODSPEC" "Pod name is required"
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
        log::step "PODSPEC" "Checking if pod $pod_name is available"
        if pod search "$pod_name" --simple 2>/dev/null | grep -q "$pod_name"; then
            log::success "PODSPEC" "Pod $pod_name is available"
            return 0
        else
            log::warn "PODSPEC" "Pod $pod_name is not available"
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

    log::step "PODSPEC" "Validating podspec with retry: $(basename "$podspec")"

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
    local max_attempts=5
    local base_delay=60
    
    log::step "PODSPEC" "Publishing podspec with retry: $(basename "$podspec")"
    
    # First update the specs repo with retry (if function exists)
    if command -v update_specs_repo &>/dev/null && command -v retry_with_backoff &>/dev/null; then
        if ! retry_with_backoff 3 5 "specs repo update" update_specs_repo; then
            log::warn "PODSPEC" "Failed to update specs repo, continuing anyway..."
        fi
    elif command -v update_specs_repo &>/dev/null; then
        # Try without retry if retry_with_backoff not available
        update_specs_repo || log::warn "PODSPEC" "Failed to update specs repo, continuing anyway..."
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
        log::error "PODSPEC" "Pod name is required"
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
            log::error "PODSPEC" "Pod $pod_name not available after ${max_wait} seconds"
            return 1
        fi
    else
        log::warn "PODSPEC" "check_pod_availability not available, cannot wait for pod"
        return 1
    fi
}

# Export functions
export -f update_podspec_version update_podspec_source_to_zip update_podspec_dependencies \
    validate_podspec publish_podspec check_pod_available \
    update_podspec_dependency_version update_podspec_to_zip_format \
    validate_podspec_with_retry publish_podspec_with_retry wait_for_pod_availability \
    msp_run_pod_trunk_push 2>/dev/null || true


# ============================================================================
# CocoaPods Trunk Push with Tier Awareness (Patch M)
# ============================================================================
msp_run_pod_trunk_push() {
    local spec="$1"
    
    if [[ -z "$spec" ]]; then
        log::error "PODSPEC" "[PODS] msp_run_pod_trunk_push: spec file is required"
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
        log::info "PODSPEC" "[PODS] [CONFIG] Skipping pod trunk push (config: pods.enabled=false, spec: $spec)"
        log::info "PODSPEC" "[PODS] [CONFIG] Running pod spec lint instead to validate podspec"

        # R040d: Use configurable timeout from cocoapods-config.yaml
        local quick_lint_timeout="${PODS_QUICK_LINT_TIMEOUT:-600}"
        # Rationale: Quick lint is fast (10-60s), but 10 min provides safety margin
        if ! run_with_timeout "$quick_lint_timeout" pod spec lint "$spec" --allow-warnings; then
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log::warn "PODSPEC" "[PODS] pod spec lint TIMED OUT after $((quick_lint_timeout/60)) minutes (config: pods.enabled=false). Treating as non-fatal."
            else
                log::warn "PODSPEC" "[PODS] pod spec lint failed for $spec (config: pods.enabled=false). Treating as non-fatal."
            fi
            return 0
        fi

        return 0
    fi
    
    # Real release tier behavior - check config (Patch M+CONFIG)
    if ! should_real_publish; then
        local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        log::error "PODSPEC" "[PODS][BLOCKED] Real pod trunk push not allowed on branch: $branch"
        log::error "PODSPEC" "[PODS][BLOCKED] Check Scripts/config/release.yaml for branch policy"
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
        log::error "PODSPEC" "[PODS] Podspec file not found: $spec"
        return 1
    fi
    
    if [[ -z "$pod_name" ]] || [[ -z "$pod_version" ]]; then
        log::warn "PODSPEC" "[PODS] Could not extract pod name or version from podspec, skipping idempotency check"
        log::warn "PODSPEC" "[PODS] Pod name: ${pod_name:-<empty>}, Version: ${pod_version:-<empty>}"
    else
        log::info "PODSPEC" "[PODS] Performing idempotency check: querying CocoaPods trunk for ${pod_name}..."
        
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
                log::success "PODSPEC" "[PODS] ✅ ${pod_name} ${pod_version} already published to CocoaPods trunk"
                log::info "PODSPEC" "[PODS] Idempotency: Skipping duplicate pod trunk push"
                local publish_timestamp
                publish_timestamp=$(echo "$trunk_info_output" | grep -- "- ${pod_version} (" | head -1 | sed 's/.*(\(.*\))/\1/')
                log::info "PODSPEC" "[PODS] Published timestamp: ${publish_timestamp:-unknown}"
                return 0
            else
                log::info "PODSPEC" "[PODS] Version ${pod_version} not found in trunk, proceeding with publish"
            fi
        else
            # Command failed - could be network error, pod doesn't exist yet, or auth issue
            # Fail-safe: Don't skip, proceed with publish attempt
            log::info "PODSPEC" "[PODS] ⚠️  pod trunk info failed (exit code: ${trunk_info_exit_code})"
            log::info "PODSPEC" "[PODS] This may be normal for first-time pod publishing or network issues"
            log::info "PODSPEC" "[PODS] Proceeding with publish attempt (fail-safe behavior)"
        fi
    fi
    
    # Production mode (DRY_RUN=false) - proceed with trunk push
    # Note: MSP_ALLOW_TRUNK_PUSH guard removed - redundant with DRY_RUN control
    # R040d: Use configurable timeout from cocoapods-config.yaml
    local trunk_push_timeout="${PODS_TRUNK_PUSH_TIMEOUT:-1800}"
    log::info "PODSPEC" "[PODS] Running pod trunk push for $spec"
    log::info "PODSPEC" "[PODS] Timeout: $((trunk_push_timeout/60)) minutes (${trunk_push_timeout}s)"

    # Rationale: Observed 5-15 min, extreme cases up to 25 min, 30 min provides safety margin
    # Use tee to capture output in real-time while also displaying it
    local push_log_file
    push_log_file=$(mktemp "/tmp/pod_trunk_push_${RANDOM}.log")

    # Ensure cleanup on exit (normal or interrupted)
    trap "rm -f '$push_log_file'" EXIT INT TERM

    log::info "PODSPEC" "[PODS] Executing: pod trunk push \"$spec\" --allow-warnings"
    log::info "PODSPEC" "[PODS] Output will be captured to: $push_log_file"

    # Run with timeout and capture output in real-time using tee
    # tee outputs to both stdout (for real-time viewing) and file (for later reference)
    # Use PIPESTATUS to get the actual exit code of run_with_timeout, not tee
    run_with_timeout "$trunk_push_timeout" pod trunk push "$spec" --allow-warnings 2>&1 | tee "$push_log_file"
    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        log::success "PODSPEC" "[PODS] ✅ Successfully pushed $spec to trunk"
        rm -f "$push_log_file"
        return 0
    elif [[ $exit_code -eq 124 ]]; then
        log::error "PODSPEC" "[PODS] ❌ TIMEOUT: pod trunk push exceeded $((trunk_push_timeout/60)) minutes"
        log::error "PODSPEC" "[PODS] This usually indicates:"
        log::error "PODSPEC" "  1. Network connectivity issues"
        log::error "PODSPEC" "  2. CocoaPods trunk server is slow or down"
        log::error "PODSPEC" "  3. Podspec validation is taking too long"
        log::error "PODSPEC" ""
        log::error "PODSPEC" "Troubleshooting:"
        log::error "PODSPEC" "  1. Check network: curl -I https://trunk.cocoapods.org"
        log::error "PODSPEC" "  2. Check podspec locally: pod spec lint $spec --allow-warnings"
        log::error "PODSPEC" "  3. Try again in a few minutes (server may be slow)"
        log::error "PODSPEC" "  4. Review captured output: $push_log_file"
        return 1
    else
        log::error "PODSPEC" "[PODS] ❌ pod trunk push failed with exit code $exit_code"
        log::error "PODSPEC" "[PODS] Review captured output for details: $push_log_file"
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
        log::info "PODSPEC" "DRY RUN: Skipping pod availability wait for $pod_name $version"
        return 0
    fi

    if [[ -z "$pod_name" || -z "$version" ]]; then
        log::error "PODSPEC" "Usage: smart_wait_for_pod_availability <pod_name> <version> [context]"
        return 1
    fi

    local context_msg=""
    if [[ -n "$context" ]]; then
        context_msg=" ($context)"
    fi

    log_section "Checking $pod_name $version availability$context_msg"

    # ═══════════════════════════════════════════════════════════════════════════
    # Stage 1: Quick check (3 minutes, 15s intervals = 12 checks)
    # ═══════════════════════════════════════════════════════════════════════════
    # CDN direct-check is fast (~0.5s), so 15s interval gives responsive feedback.
    # Total Stage 1 time: 3 minutes (180s / 15s = 12 checks).
    log::step "PODSPEC" "Quick check: Is $pod_name $version available? (3 min timeout, 15s intervals)..."

    if wait_for_pod_availability "$pod_name" "$version" 180 15; then
        log::success "PODSPEC" "✓ $pod_name $version is available!"
        return 0
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # Stage 2: Not available yet — auto-continue waiting
    # ═══════════════════════════════════════════════════════════════════════════
    log::warn "PODSPEC" "✗ $pod_name $version not available yet (checked for 3 minutes)"
    log::info "PODSPEC" "$pod_name $version was recently published. CDN sync can take 5-30 minutes."
    if [[ -n "$context" ]]; then
        log::info "PODSPEC" "Context: $context"
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # Stage 3: Long wait (up to 57 more minutes, 60 total; 30s intervals)
    # ═══════════════════════════════════════════════════════════════════════════
    # Rationale: CDN propagation observed 10-25 min, extreme cases up to 60 min.
    # 30s intervals (vs old 60s) gives earlier detection while still being quiet.
    log::info "PODSPEC" "Continuing to wait for $pod_name $version (up to 57 more minutes)..."
    log::info "PODSPEC" "CDN propagation can take 10-60 minutes. Checking every 30 seconds."

    # 57 minutes = 3420 seconds (60 total - 3 already waited)
    if ! wait_for_pod_availability "$pod_name" "$version" 3420 30; then
        log::error "PODSPEC" "$pod_name $version still not available after 60 minutes total"
        log::error "PODSPEC" "This is unusual. Please check:"
        log::error "PODSPEC" "  1. Did $pod_name $version publish succeed?"
        log::error "PODSPEC" "     Command: pod trunk info $pod_name"
        log::error "PODSPEC" "  2. Is CocoaPods CDN having issues?"
        log::error "PODSPEC" "     Check: https://status.cocoapods.org"
        return 1
    fi

    log::success "PODSPEC" "✓ $pod_name $version is now available!"
    return 0
}

# Export the function
export -f smart_wait_for_pod_availability 2>/dev/null || true
