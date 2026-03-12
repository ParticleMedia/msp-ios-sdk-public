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

# Validation and checking functions for MSP iOS SDK build system
# This module provides comprehensive validation for commands, paths, configurations, and build requirements

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../release/lib/config.sh" ]]; then
    # shellcheck source=Scripts/release/lib/config.sh
    source "$(dirname "${BASH_SOURCE[0]}")/../release/lib/config.sh" 2>/dev/null || true
fi

# Required commands for different operations (using functions for bash 3.x compatibility)
get_required_commands() {
    case "$1" in
        "base") echo "bash grep sed awk cut tr" ;;
        "xcode") echo "xcodebuild xcrun xcode-select" ;;
        "cocoapods") echo "pod bundle" ;;
        "git") echo "git" ;;
        "archive") echo "zip unzip tar" ;;
        "github") echo "gh" ;;
        *) echo "" ;;
    esac
}

# Required files for different operations (using functions for bash 3.x compatibility)
get_required_files() {
    case "$1" in
        "ios_project") echo "msp-ios-sdk.xcworkspace Podfile" ;;
        "build_scripts") echo "Scripts/buildiOSCoreXCFramework.sh Scripts/buildNovaXCFramework.sh" ;;
        "fastlane") echo "Gemfile fastlane/Fastfile" ;;
        *) echo "" ;;
    esac
}

# Minimum version requirements (using functions for bash 3.x compatibility)
get_min_version() {
    case "$1" in
        "xcode") echo "15.0" ;;
        "cocoapods") echo "1.12.0" ;;
        "ruby") echo "3.0.0" ;;
        "bundle") echo "2.0.0" ;;
        *) echo "" ;;
    esac
}

# Command validation functions
check_command_exists() {
    local command="$1"
    local description="${2:-$command}"
    
    if command -v "$command" >/dev/null 2>&1; then
        log::debug "VALIDATE" "Command '$command' found: $(command -v "$command")"
        return $EXIT_SUCCESS
    else
        log::error "VALIDATE" "Required command '$description' not found in PATH"
        return $EXIT_COMMAND_NOT_FOUND
    fi
}

check_command_group() {
    local group="$1"
    local commands=$(get_required_commands "$group")
    local failed_commands=()
    
    if [[ -z "$commands" ]]; then
        log::error "VALIDATE" "Unknown command group: $group"
        return $EXIT_VALIDATION_ERROR
    fi

    log::step "VALIDATE" "Checking $group commands..."
    
    # shellcheck disable=SC2086 -- intentional word-splitting: commands is a space-delimited name list
    for command in $commands; do
        if ! check_command_exists "$command" >/dev/null 2>&1; then
            failed_commands+=("$command")
        fi
    done
    
    if [[ ${#failed_commands[@]} -eq 0 ]]; then
        log::success "VALIDATE" "All $group commands available"
        return $EXIT_SUCCESS
    else
        log::error "VALIDATE" "Missing $group commands: ${failed_commands[*]}"
        return $EXIT_COMMAND_NOT_FOUND
    fi
}

# Version validation functions
get_command_version() {
    local command="$1"
    
    case "$command" in
        "xcodebuild")
            xcodebuild -version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1
            ;;
        "pod")
            pod --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+'
            ;;
        "ruby")
            ruby --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1
            ;;
        "bundle")
            bundle --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+'
            ;;
        "swift")
            swift --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' | head -n1
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

check_command_version() {
    local command="$1"
    local min_version="${2:-$(get_min_version "$command")}"
    
    if [[ -z "$min_version" ]]; then
        log::debug "VALIDATE" "No minimum version specified for $command"
        return $EXIT_SUCCESS
    fi
    
    if ! check_command_exists "$command" >/dev/null 2>&1; then
        return $EXIT_COMMAND_NOT_FOUND
    fi
    
    local current_version=$(get_command_version "$command")
    
    if [[ "$current_version" == "unknown" ]]; then
        log::warn "VALIDATE" "Could not determine version for $command"
        return $EXIT_SUCCESS
    fi

    if version_greater_equal "$current_version" "$min_version"; then
        log::debug "VALIDATE" "$command version $current_version meets minimum requirement ($min_version)"
        return $EXIT_SUCCESS
    else
        log::error "VALIDATE" "$command version $current_version is below minimum requirement ($min_version)"
        return $EXIT_VALIDATION_ERROR
    fi
}

# Path validation functions
check_path_exists() {
    local path="$1"
    local description="${2:-$path}"
    local type="${3:-any}" # file, directory, any
    
    case "$type" in
        "file")
            if [[ -f "$path" ]]; then
                log::debug "VALIDATE" "File exists: $path"
                return $EXIT_SUCCESS
            else
                log::error "VALIDATE" "Required file not found: $description ($path)"
                return $EXIT_VALIDATION_ERROR
            fi
            ;;
        "directory")
            if [[ -d "$path" ]]; then
                log::debug "VALIDATE" "Directory exists: $path"
                return $EXIT_SUCCESS
            else
                log::error "VALIDATE" "Required directory not found: $description ($path)"
                return $EXIT_VALIDATION_ERROR
            fi
            ;;
        *)
            if [[ -e "$path" ]]; then
                log::debug "VALIDATE" "Path exists: $path"
                return $EXIT_SUCCESS
            else
                log::error "VALIDATE" "Required path not found: $description ($path)"
                return $EXIT_VALIDATION_ERROR
            fi
            ;;
    esac
}

check_file_group() {
    local group="$1"
    local files=$(get_required_files "$group")
    local failed_files=()
    
    if [[ -z "$files" ]]; then
        log::error "VALIDATE" "Unknown file group: $group"
        return $EXIT_VALIDATION_ERROR
    fi

    log::step "VALIDATE" "Checking $group files..."
    
    # shellcheck disable=SC2086 -- intentional word-splitting: files is a space-delimited path list
    for file in $files; do
        if ! check_path_exists "$file" "$file" "file" >/dev/null 2>&1; then
            failed_files+=("$file")
        fi
    done
    
    if [[ ${#failed_files[@]} -eq 0 ]]; then
        log::success "VALIDATE" "All $group files found"
        return $EXIT_SUCCESS
    else
        log::error "VALIDATE" "Missing $group files: ${failed_files[*]}"
        return $EXIT_VALIDATION_ERROR
    fi
}

# Permission validation functions
check_file_permissions() {
    local file="$1"
    local required_perms="$2" # r, w, x, rw, rx, wx, rwx
    
    if [[ ! -e "$file" ]]; then
        log::error "VALIDATE" "Cannot check permissions: file does not exist: $file"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local has_read has_write has_execute
    
    [[ -r "$file" ]] && has_read=true || has_read=false
    [[ -w "$file" ]] && has_write=true || has_write=false
    [[ -x "$file" ]] && has_execute=true || has_execute=false
    
    case "$required_perms" in
        "r") $has_read ;;
        "w") $has_write ;;
        "x") $has_execute ;;
        "rw") $has_read && $has_write ;;
        "rx") $has_read && $has_execute ;;
        "wx") $has_write && $has_execute ;;
        "rwx") $has_read && $has_write && $has_execute ;;
        *)
            log::error "VALIDATE" "Invalid permission specification: $required_perms"
            return $EXIT_VALIDATION_ERROR
            ;;
    esac

    local result=$?
    if [[ $result -eq 0 ]]; then
        log::debug "VALIDATE" "File $file has required permissions: $required_perms"
    else
        log::error "VALIDATE" "File $file missing required permissions: $required_perms"
    fi
    
    return $result
}

make_executable() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log::error "VALIDATE" "Cannot make executable: file does not exist: $file"
        return $EXIT_VALIDATION_ERROR
    fi

    if ! check_file_permissions "$file" "x" >/dev/null 2>&1; then
        log::step "VALIDATE" "Making $file executable..."
        if chmod +x "$file"; then
            log::success "VALIDATE" "Made $file executable"
            return $EXIT_SUCCESS
        else
            log::error "VALIDATE" "Failed to make $file executable"
            return $EXIT_VALIDATION_ERROR
        fi
    else
        log::debug "VALIDATE" "$file is already executable"
        return $EXIT_SUCCESS
    fi
}

# Xcode and iOS development validation
validate_xcode_installation() {
    log::step "VALIDATE" "Validating Xcode installation..."

    if ! check_command_exists "xcode-select" "Xcode command line tools"; then
        return $EXIT_VALIDATION_ERROR
    fi

    local xcode_path
    xcode_path=$(xcode-select -p 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$xcode_path" ]]; then
        log::error "VALIDATE" "Xcode path not set. Run: sudo xcode-select --install"
        return $EXIT_VALIDATION_ERROR
    fi

    if ! check_command_version "xcodebuild"; then
        return $EXIT_VALIDATION_ERROR
    fi

    local ios_sdk_path
    ios_sdk_path=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ ! -d "$ios_sdk_path" ]]; then
        log::error "VALIDATE" "iOS SDK not found"
        return $EXIT_VALIDATION_ERROR
    fi

    local ios_sim_sdk_path
    ios_sim_sdk_path=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ ! -d "$ios_sim_sdk_path" ]]; then
        log::error "VALIDATE" "iOS Simulator SDK not found"
        return $EXIT_VALIDATION_ERROR
    fi

    log::success "VALIDATE" "Xcode installation validated"
    log::debug "VALIDATE" "Xcode path: $xcode_path"
    log::debug "VALIDATE" "iOS SDK: $ios_sdk_path"
    log::debug "VALIDATE" "iOS Simulator SDK: $ios_sim_sdk_path"

    return $EXIT_SUCCESS
}

validate_cocoapods_installation() {
    log::step "VALIDATE" "Validating CocoaPods installation..."

    if ! check_command_group "cocoapods"; then
        return $EXIT_VALIDATION_ERROR
    fi

    if ! check_command_version "pod"; then
        return $EXIT_VALIDATION_ERROR
    fi

    if ! bundle exec pod repo list >/dev/null 2>&1; then
        log::warn "VALIDATE" "CocoaPods specs repo may need updating"
    fi

    log::success "VALIDATE" "CocoaPods installation validated"
    return $EXIT_SUCCESS
}

validate_ruby_environment() {
    log::step "VALIDATE" "Validating Ruby environment..."

    if ! check_command_version "ruby"; then
        return $EXIT_VALIDATION_ERROR
    fi

    if ! check_command_version "bundle"; then
        return $EXIT_VALIDATION_ERROR
    fi

    if [[ -f "Gemfile" ]]; then
        if [[ -f "Gemfile.lock" ]]; then
            if ! bundle check >/dev/null 2>&1; then
                log::warn "VALIDATE" "Bundle dependencies need updating. Run: bundle install"
            fi
        else
            log::warn "VALIDATE" "Gemfile.lock not found. Run: bundle install"
        fi
    fi

    log::success "VALIDATE" "Ruby environment validated"
    return $EXIT_SUCCESS
}

# Project-specific validation
validate_project_structure() {
    log::step "VALIDATE" "Validating project structure..."

    if ! check_file_group "ios_project"; then
        return $EXIT_VALIDATION_ERROR
    fi

    local essential_dirs=(
        "MSPCore"
        "MSPiOSCore"
        "NovaCore"
        "Scripts"
    )

    for dir in "${essential_dirs[@]}"; do
        if ! check_path_exists "$dir" "$dir directory" "directory"; then
            return $EXIT_VALIDATION_ERROR
        fi
    done

    if ! check_file_group "build_scripts"; then
        return $EXIT_VALIDATION_ERROR
    fi

    for script in Scripts/buildiOSCoreXCFramework.sh Scripts/buildNovaXCFramework.sh Scripts/makeBuild.sh; do
        if [[ -f "$script" ]]; then
            make_executable "$script"
        fi
    done

    log::success "VALIDATE" "Project structure validated"
    return $EXIT_SUCCESS
}

validate_build_environment() {
    log::step "VALIDATE" "Validating build environment..."

    if ! check_command_group "base"; then
        return $EXIT_VALIDATION_ERROR
    fi

    if ! validate_xcode_installation; then
        return $EXIT_VALIDATION_ERROR
    fi

    if [[ -f "Podfile" ]]; then
        if ! validate_cocoapods_installation; then
            return $EXIT_VALIDATION_ERROR
        fi
    fi

    if [[ -f "Gemfile" ]]; then
        if ! validate_ruby_environment; then
            return $EXIT_VALIDATION_ERROR
        fi
    fi

    log::success "VALIDATE" "Build environment validated"
    return $EXIT_SUCCESS
}

validate_configuration() {
    log::step "VALIDATE" "Validating configuration..."

    local skip_code_sign=$(get_env_bool SKIP_CODE_SIGN false)
    if [[ "$skip_code_sign" == "true" ]]; then
        log::info "VALIDATE" "Code signing disabled (development mode)"
    else
        log::info "VALIDATE" "Code signing enabled (production mode)"

        # In production mode, we might want to check for signing certificates
        # This is optional and can be implemented based on specific needs
    fi

    local config="${CONFIGURATION:-Release}"
    case "$config" in
        "Debug"|"Release")
            log::debug "VALIDATE" "Build configuration: $config"
            ;;
        *)
            log::warn "VALIDATE" "Unusual build configuration: $config"
            ;;
    esac

    local deployment_target="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
    if version_greater_equal "$deployment_target" "15.0"; then
        log::debug "VALIDATE" "iOS deployment target: $deployment_target"
    else
        log::warn "VALIDATE" "iOS deployment target $deployment_target may be too low"
    fi

    log::success "VALIDATE" "Configuration validated"
    return $EXIT_SUCCESS
}

validate_all() {
    local validation_failed=false

    print_section "Environment Validation"

    validate_project_structure || validation_failed=true
    validate_build_environment || validation_failed=true
    validate_configuration || validation_failed=true

    if [[ "$validation_failed" == "true" ]]; then
        log::error "VALIDATE" "Environment validation failed"
        return $EXIT_VALIDATION_ERROR
    else
        log::success "VALIDATE" "Environment validation completed successfully"
        return $EXIT_SUCCESS
    fi
}

validate_essential() {
    log::step "VALIDATE" "Running essential validation checks..."

    if ! check_path_exists "msp-ios-sdk.xcworkspace" "iOS workspace" "file"; then
        return $EXIT_VALIDATION_ERROR
    fi

    local essential_commands=("xcodebuild" "bash")
    for cmd in "${essential_commands[@]}"; do
        if ! check_command_exists "$cmd"; then
            return $EXIT_VALIDATION_ERROR
        fi
    done

    log::success "VALIDATE" "Essential validation completed"
    return $EXIT_SUCCESS
}

# ============================================================================
# Branch Validation for Release Operations
# ============================================================================
# Centralized branch validation logic to ensure DRY principle
# Used by both safety.sh and modular.sh
# ============================================================================
validate_release_branch() {
    local dry_run="${DRY_RUN:-true}"

    # Only validate in production mode
    if [[ "$dry_run" != "false" ]]; then
        return 0
    fi

    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    if command -v msp_resolve_branch_for_policy &>/dev/null; then
        local resolved_branch
        resolved_branch="$(msp_resolve_branch_for_policy "$current_branch")"
        if [[ -n "$resolved_branch" && "$resolved_branch" != "$current_branch" ]]; then
            log::info "VALIDATE" "[BRANCH_VALIDATION] Effective branch for policy checks: $resolved_branch"
            current_branch="$resolved_branch"
        fi
    fi

    if [[ -z "$current_branch" ]]; then
        log::error "VALIDATE" "[BRANCH_VALIDATION] Cannot determine current Git branch"
        return 1
    fi

    log::info "VALIDATE" "[BRANCH_VALIDATION] Validating branch: $current_branch"

    if ! command -v msp_get_branch_policy_value &>/dev/null; then
        log::error "VALIDATE" "[BRANCH_VALIDATION] Branch policy loader unavailable"
        return 1
    fi

    local allow_real_publish
    allow_real_publish="$(msp_get_branch_policy_value "allow_real_publish" "$current_branch" 2>/dev/null || echo "false")"

    if [[ "$allow_real_publish" == "true" ]]; then
        log::info "VALIDATE" "[BRANCH_VALIDATION] ✓ Branch '$current_branch' is allowed for release by branch_policy"
        return 0
    fi

    log::error "VALIDATE" "[BRANCH_VALIDATION] Production mode cannot run on branch '$current_branch'"
    log::error "VALIDATE" "[BRANCH_VALIDATION] Check Scripts/config/release.yaml -> branch_policy.rules"
    return 1
}

# Export validation functions
export -f check_command_exists check_command_group
export -f get_command_version check_command_version
export -f check_path_exists check_file_group
export -f check_file_permissions make_executable
export -f validate_xcode_installation validate_cocoapods_installation validate_ruby_environment
export -f validate_project_structure validate_build_environment validate_configuration
export -f validate_all validate_essential
export -f validate_release_branch
