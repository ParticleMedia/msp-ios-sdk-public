#!/usr/bin/env bash
# ============================================================================
# TestFlight Prerequisite Validation
# ============================================================================
# Checks all tools, credentials, and workspace state before attempting a build.
# Fails fast with actionable error messages.
#
# Exports:
#   tf_validate_prerequisites - Run all pre-flight checks
# ============================================================================

# Module guard
[[ -n "${_TF_VALIDATE_SOURCED:-}" ]] && return 0
_TF_VALIDATE_SOURCED=1

tf_validate_prerequisites() {
    log::info "TF-VALIDATE" "Running pre-flight checks..."
    local errors=0

    # --- Tool checks ---
    local required_tools=("xcodebuild" "git")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log::error "TF-VALIDATE" "Required tool not found: $tool"
            ((errors++)) || true
        fi
    done

    # fastlane via bundler
    if ! bundle exec fastlane --version >/dev/null 2>&1; then
        log::error "TF-VALIDATE" "fastlane not available via bundler — run 'bundle install'"
        ((errors++)) || true
    fi

    # --- ASC credential checks (skip in dry-run — only needed for upload) ---
    if [[ "${DRY_RUN_MODE:-false}" != "true" ]]; then
        if [[ -z "${ASC_KEY_ID:-}" ]]; then
            log::error "TF-VALIDATE" "ASC_KEY_ID environment variable is not set"
            ((errors++)) || true
        fi

        if [[ -z "${ASC_ISSUER_ID:-}" ]]; then
            log::error "TF-VALIDATE" "ASC_ISSUER_ID environment variable is not set"
            ((errors++)) || true
        fi

        if [[ -z "${ASC_KEY_PATH:-}" ]]; then
            log::error "TF-VALIDATE" "ASC_KEY_PATH environment variable is not set"
            ((errors++)) || true
        elif [[ ! -f "${ASC_KEY_PATH}" ]]; then
            log::error "TF-VALIDATE" "ASC .p8 key file not found: ${ASC_KEY_PATH}"
            ((errors++)) || true
        fi
    else
        log::info "TF-VALIDATE" "Skipping ASC credential checks (dry-run mode)"
    fi

    # --- Workspace check ---
    if [[ ! -f "$ROOT_DIR/${TF_WORKSPACE:-msp-ios-sdk.xcworkspace}/contents.xcworkspacedata" ]]; then
        log::error "TF-VALIDATE" "Workspace not found: $ROOT_DIR/${TF_WORKSPACE:-msp-ios-sdk.xcworkspace}"
        log::error "TF-VALIDATE" "Run 'pod install' first"
        ((errors++)) || true
    fi

    # --- Clean git state (warning only) ---
    if command -v git >/dev/null 2>&1; then
        if [[ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null)" ]]; then
            log::warn "TF-VALIDATE" "Working directory has uncommitted changes"
        fi
    fi

    # --- Result ---
    if [[ $errors -gt 0 ]]; then
        log::error "TF-VALIDATE" "Pre-flight check failed with $errors error(s)"
        return "${EXIT_VALIDATION_ERROR}"
    fi

    log::success "TF-VALIDATE" "All pre-flight checks passed"
    return 0
}
