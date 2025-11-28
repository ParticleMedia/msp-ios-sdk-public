#!/bin/bash

# Podspec Utilities for Release Scripts
# Provides functions for podspec manipulation and validation

# ============================================================================
# ROOT_DIR and UI System Loading
# ============================================================================
# Calculate ROOT_DIR if not already set (may be set by parent script)
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

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

# Validate podspec (wrapper around validate_podspec from cocoapods.sh)
validate_podspec() {
    local podspec_file="$1"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    # Use validate_podspec from cocoapods.sh if available
    if command -v validate_podspec &>/dev/null; then
        validate_podspec "$podspec_file"
    else
        log_step "Validating podspec: $podspec_file"
        if pod spec lint "$podspec_file" --quick --allow-warnings >/dev/null 2>&1; then
            log_success "Podspec validation passed: $podspec_file"
            return 0
        else
            log_error "Podspec validation failed: $podspec_file"
            return 1
        fi
    fi
}

# Publish podspec (wrapper around publish_podspec from cocoapods.sh)
publish_podspec() {
    local podspec_file="$1"
    
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec file not found: $podspec_file"
        return 1
    fi
    
    # Use publish_podspec from cocoapods.sh if available
    if command -v publish_podspec &>/dev/null; then
        publish_podspec "$podspec_file"
    else
        log_step "Publishing podspec: $podspec_file"
        if pod trunk push "$podspec_file" --allow-warnings >/dev/null 2>&1; then
            log_success "Podspec published: $podspec_file"
            return 0
        else
            log_error "Failed to publish podspec: $podspec_file"
            return 1
        fi
    fi
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

# Validate podspec with retry logic
validate_podspec_with_retry() {
    local podspec="$1"
    local max_attempts=3
    local base_delay=5
    
    log_step "Validating podspec with retry: $(basename "$podspec")"
    
    if command -v retry_with_backoff &>/dev/null; then
        retry_with_backoff $max_attempts $base_delay "podspec validation" \
            validate_podspec "$podspec"
    else
        validate_podspec "$podspec"
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
    
    # Then publish with retry
    if command -v retry_with_backoff &>/dev/null; then
        retry_with_backoff $max_attempts $base_delay "podspec publishing" \
            publish_podspec "$podspec"
    else
        publish_podspec "$podspec"
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
    validate_podspec publish_podspec check_pod_available \
    update_podspec_dependency_version update_podspec_to_zip_format \
    validate_podspec_with_retry publish_podspec_with_retry wait_for_pod_availability 2>/dev/null || true

