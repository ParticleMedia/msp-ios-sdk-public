#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

# Retry Utilities for Release Scripts
# Provides retry logic with exponential backoff and condition waiting

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
        log::warn "RETRY" "$@"
    }
fi

retry() {
    local max_attempts="$1"
    local delay="$2"
    local command_name="${3:-command}"
    shift 3
    local command=("$@")
    
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log::debug "RETRY" "Attempt $attempt/$max_attempts: $command_name"
        
        if "${command[@]}"; then
            log::success "RETRY" "$command_name succeeded on attempt $attempt"
            return 0
        else
            log::warn "RETRY" "$command_name failed (attempt $attempt/$max_attempts)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                log::info "RETRY" "Retrying $command_name in ${delay} seconds..."
                sleep "$delay"
            fi
        fi
        
        ((attempt++)) || true
    done
    
    log::error "RETRY" "$command_name failed after $max_attempts attempts"
    return 1
}

retry_with_backoff() {
    local max_attempts="$1"
    local base_delay="$2"
    local command_name="$3"
    shift 3
    local command=("$@")
    
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log::debug "RETRY" "Attempt $attempt/$max_attempts: $command_name"
        
        if "${command[@]}"; then
            log::success "RETRY" "$command_name succeeded on attempt $attempt"
            return 0
        else
            log::warn "RETRY" "$command_name failed (attempt $attempt/$max_attempts)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                # Exponential backoff: base_delay * 2^(attempt-1)
                local delay=$((base_delay * (1 << (attempt - 1))))
                log::info "RETRY" "Retrying $command_name in ${delay} seconds..."
                sleep $delay
            fi
        fi
        
        ((attempt++)) || true
    done
    
    log::error "RETRY" "$command_name failed after $max_attempts attempts"
    return 1
}

wait_for_condition() {
    local condition_command="$1"
    local timeout="${2:-300}"  # Default 5 minutes
    local interval="${3:-5}"    # Default 5 seconds
    local description="${4:-condition}"
    
    local elapsed=0
    
    log::step "RETRY" "Waiting for $description (timeout: ${timeout}s, interval: ${interval}s)"
    
    while [[ $elapsed -lt $timeout ]]; do
        if eval "$condition_command"; then
            log::success "RETRY" "$description is now true"
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            log::info "RETRY" "Still waiting for $description... (${elapsed}s elapsed)"
        fi
    done
    
    log::warning "RETRY" "$description did not become true within ${timeout} seconds"
    return 1
}

# Export functions
export -f retry retry_with_backoff wait_for_condition 2>/dev/null || true


