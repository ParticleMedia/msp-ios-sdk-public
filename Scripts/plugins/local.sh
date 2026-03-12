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

# Fix Unicode encoding issues for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Local Development Environment Plugin for MSP iOS SDK build system
# This plugin provides local development optimizations and user-friendly features

# Plugin metadata
readonly PLUGIN_NAME="local"
readonly PLUGIN_VERSION="1.0.0"
readonly PLUGIN_DESCRIPTION="Local Development Environment Plugin"

# Source dependencies (common.sh provides unified logging)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Plugin activation check
is_plugin_active() {
    [[ "$BUILD_ENVIRONMENT" == "local" ]] || [[ -z "$CI" ]]
}

# Plugin initialization
plugin_init() {
    if ! is_plugin_active; then
        return $EXIT_SUCCESS
    fi
    
    log::debug "PLUGIN" "Initializing local development plugin..."
    
    # Configure local development settings
    configure_local_environment
    
    # Setup local optimizations
    setup_local_optimizations
    
    # Setup development helpers
    setup_development_helpers
    
    log::success "PLUGIN" "Local development plugin initialized"
}

# Environment configuration
configure_local_environment() {
    log::step "PLUGIN" "Configuring local development environment..."
    
    # Override settings for local development
    export SKIP_CODE_SIGN=1
    export BUILD_VERBOSE=YES
    export AUTO_CLEANUP_BUILD_ARTIFACTS=NO
    export CLEANUP_DERIVED_DATA=NO
    export ENABLE_BUILD_TIMING=YES
    export STRUCTURED_OUTPUT=NO
    export FORCE_COLOR=1
    export DISABLE_EMOJI=0
    
    # Set comfortable log level
    export LOG_LEVEL=$LOG_LEVEL_DEBUG
    
    # Disable various stats and update checks for faster builds
    export FASTLANE_SKIP_UPDATE_CHECK=1
    export FASTLANE_DISABLE_ANIMATION=1
    export COCOAPODS_DISABLE_STATS=1
    export HOMEBREW_NO_AUTO_UPDATE=1
    
    log::debug "PLUGIN" "Local environment variables configured"
}

# Local optimizations
setup_local_optimizations() {
    log::step "PLUGIN" "Setting up local build optimizations..."
    
    # Use local derived data for faster incremental builds
    export DERIVED_DATA_PATH="${HOME}/Library/Developer/Xcode/DerivedData/MSP-iOS-SDK"
    ensure_directory "$DERIVED_DATA_PATH"
    
    # Setup local caching
    setup_local_caching
    
    # Configure git settings for development
    configure_git_settings
    
    log::success "PLUGIN" "Local optimizations configured"
}

setup_local_caching() {
    log::debug "PLUGIN" "Setting up local caching..."
    
    # CocoaPods cache
    local pods_cache_dir="${HOME}/.msp_pods_cache"
    ensure_directory "$pods_cache_dir"
    export COCOAPODS_CACHE_DIR="$pods_cache_dir"
    
    # Bundle cache
    local bundle_cache_dir="${HOME}/.msp_bundle_cache"
    ensure_directory "$bundle_cache_dir"
    export BUNDLE_CACHE_PATH="$bundle_cache_dir"
    
    # Xcode cache optimizations
    export CLANG_MODULE_CACHE_PATH="${HOME}/Library/Caches/org.llvm.clang/ModuleCache"
    
    log::debug "PLUGIN" "Local caching configured"
}

configure_git_settings() {
    log::debug "PLUGIN" "Configuring git settings for development..."
    
    # Check if git is configured
    if ! git config user.name >/dev/null 2>&1; then
        log::info "PLUGIN" "Git user.name not configured. Consider setting it with: git config --global user.name \"Your Name\""
    fi
    
    if ! git config user.email >/dev/null 2>&1; then
        log::info "PLUGIN" "Git user.email not configured. Consider setting it with: git config --global user.email \"your.email@example.com\""
    fi
    
    # Setup git hooks directory if it doesn't exist
    local hooks_dir=".git/hooks"
    if [[ -d ".git" ]] && [[ ! -d "$hooks_dir" ]]; then
        ensure_directory "$hooks_dir"
        log::debug "PLUGIN" "Created git hooks directory"
    fi
}

# Development helpers
setup_development_helpers() {
    log::step "PLUGIN" "Setting up development helpers..."
    
    # Create helpful aliases
    setup_build_aliases
    
    # Setup IDE integration
    setup_ide_integration
    
    # Create development shortcuts
    create_development_shortcuts
    
    log::success "PLUGIN" "Development helpers configured"
}

setup_build_aliases() {
    log::debug "PLUGIN" "Setting up build aliases..."
    
    # Create temporary alias file
    local alias_file="/tmp/msp_build_aliases.sh"
    
    cat > "$alias_file" << 'EOF'
# MSP iOS SDK Build Aliases
# Source this file to get helpful build shortcuts

# Quick build commands
alias msp-build-core="Scripts/build.sh --framework MSPiOSCore"
alias msp-build-nova="Scripts/build.sh --framework NovaCore"
alias msp-build-all="Scripts/build.sh --framework all"

# Testing shortcuts
alias msp-test-core="Scripts/build.sh --test MSPiOSCore"
alias msp-test-nova="Scripts/build.sh --test NovaCore"
alias msp-test-all="Scripts/build.sh --test all"

# Validation shortcuts
alias msp-validate="Scripts/validate.sh"
alias msp-validate-pods="Scripts/validate.sh --podspecs"

# Cleanup shortcuts
alias msp-clean="Scripts/build.sh --clean"
alias msp-clean-all="Scripts/build.sh --clean-all"

# Status and info
alias msp-status="Scripts/build.sh --status"
alias msp-info="Scripts/build.sh --info"

# Fastlane shortcuts (if available)
if command -v bundle >/dev/null 2>&1; then
    alias fl="bundle exec fastlane"
    alias msp-fl-status="bundle exec fastlane status"
    alias msp-fl-build="bundle exec fastlane build_all"
    alias msp-fl-test="bundle exec fastlane test"
fi
EOF
    
    log::info "PLUGIN" "Build aliases created at $alias_file"
    log::info "PLUGIN" "Source with: source $alias_file"
}

setup_ide_integration() {
    log::debug "PLUGIN" "Setting up IDE integration..."
    
    # Create VS Code settings for better development experience
    if command -v code >/dev/null 2>&1; then
        setup_vscode_integration
    fi
    
    # Create Xcode user data for consistent settings
    setup_xcode_integration
}

setup_vscode_integration() {
    local vscode_dir=".vscode"
    local settings_file="$vscode_dir/settings.json"
    local tasks_file="$vscode_dir/tasks.json"
    
    ensure_directory "$vscode_dir"
    
    # Create VS Code settings if they don't exist
    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" << 'EOF'
{
    "files.associations": {
        "*.sh": "shellscript",
        "*.conf": "properties",
        "Podfile": "ruby",
        "Fastfile": "ruby"
    },
    "shellcheck.enable": true,
    "shellcheck.run": "onType",
    "terminal.integrated.defaultProfile.osx": "zsh",
    "search.exclude": {
        "**/Pods": true,
        "**/DerivedData": true,
        "**/output*": true,
        "**/*.xcarchive": true
    }
}
EOF
        log::debug "PLUGIN" "Created VS Code settings"
    fi
    
    # Create VS Code tasks if they don't exist
    if [[ ! -f "$tasks_file" ]]; then
        cat > "$tasks_file" << 'EOF'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build All Frameworks",
            "type": "shell",
            "command": "Scripts/build.sh",
            "args": ["--framework", "all"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Test All Frameworks",
            "type": "shell",
            "command": "Scripts/build.sh",
            "args": ["--test", "all"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Validate Environment",
            "type": "shell",
            "command": "Scripts/validate.sh",
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Clean Build",
            "type": "shell",
            "command": "Scripts/build.sh",
            "args": ["--clean"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        }
    ]
}
EOF
        log::debug "PLUGIN" "Created VS Code tasks"
    fi
}

setup_xcode_integration() {
    log::debug "PLUGIN" "Setting up Xcode integration..."
    
    # Create shared Xcode schemes if they don't exist
    local shared_schemes_dir="msp-ios-sdk.xcworkspace/xcshareddata/xcschemes"
    if [[ -d "msp-ios-sdk.xcworkspace" ]]; then
        ensure_directory "$shared_schemes_dir"
        log::debug "PLUGIN" "Ensured Xcode shared schemes directory exists"
    fi
    
    # Set Xcode preferences for better development experience
    configure_xcode_preferences
}

configure_xcode_preferences() {
    log::debug "PLUGIN" "Configuring Xcode preferences..."
    
    # Create a temporary script to set Xcode preferences
    local xcode_prefs_script="/tmp/configure_xcode.sh"
    
    cat > "$xcode_prefs_script" << 'EOF'
#!/bin/bash
# Configure Xcode preferences for MSP iOS SDK development

# Enable additional warnings
defaults write com.apple.dt.Xcode DVTTextShowInvisibleCharacters -bool true
defaults write com.apple.dt.Xcode DVTTextShowPageGuide -bool true

# Improve build performance
defaults write com.apple.dt.Xcode DVTTextIndentUsingTabs -bool false
defaults write com.apple.dt.Xcode DVTTextIndentWidth -int 4

# Enable useful debugging options
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks -int 8

echo "Xcode preferences configured for MSP iOS SDK development"
EOF
    
    chmod +x "$xcode_prefs_script"
    log::info "PLUGIN" "Xcode configuration script created at $xcode_prefs_script"
    log::info "PLUGIN" "Run to apply: $xcode_prefs_script"
}

create_development_shortcuts() {
    log::debug "PLUGIN" "Creating development shortcuts..."
    
    # Create a development menu script
    local dev_menu_script="dev_menu.sh"
    
    cat > "$dev_menu_script" << 'EOF'
#!/bin/bash
# MSP iOS SDK Development Menu

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    MSP iOS SDK Development Menu                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Build Commands:"
echo "  1) Build MSPiOSCore only"
echo "  2) Build NovaCore only" 
echo "  3) Build all frameworks"
echo "  4) Clean and rebuild all"
echo ""
echo "Test Commands:"
echo "  5) Run MSPiOSCore tests"
echo "  6) Run NovaCore tests"
echo "  7) Run all tests"
echo ""
echo "Validation Commands:"
echo "  8) Validate environment"
echo "  9) Validate all podspecs"
echo " 10) Check build status"
echo ""
echo "Utility Commands:"
echo " 11) Clean build artifacts"
echo " 12) Update CocoaPods"
echo " 13) Show environment info"
echo ""
echo " 0) Exit"
echo ""

read -p "Select an option (0-13): " choice

case $choice in
    1) Scripts/build.sh --framework MSPiOSCore ;;
    2) Scripts/build.sh --framework NovaCore ;;
    3) Scripts/build.sh --framework all ;;
    4) Scripts/build.sh --clean-all && Scripts/build.sh --framework all ;;
    5) Scripts/build.sh --test MSPiOSCore ;;
    6) Scripts/build.sh --test NovaCore ;;
    7) Scripts/build.sh --test all ;;
    8) Scripts/validate.sh ;;
    9) Scripts/validate.sh --podspecs ;;
    10) Scripts/build.sh --status ;;
    11) Scripts/build.sh --clean ;;
    12) if ! bundle exec pod install --repo-update; then
        echo "Primary pod install failed, trying with GitHub source backup..."
        cp Podfile Podfile.backup
        cat > Podfile.temp << 'EOF2'
# Fallback Podfile with GitHub source
source 'https://github.com/CocoaPods/Specs.git'
source 'https://cdn.cocoapods.org/'
EOF2
        grep -v \"^source \" Podfile.backup >> Podfile.temp
        if bundle exec pod install --podfile=Podfile.temp --no-repo-update; then
            echo "Pod install succeeded with GitHub source backup"
            mv Podfile.temp Podfile
            rm -f Podfile.backup
        else
            echo "Pod install failed even with GitHub source backup"
            mv Podfile.backup Podfile
            rm -f Podfile.temp
    fi
    fi
    ;;
    *) echo "Invalid option" ;;
esac
EOF
    
    chmod +x "$dev_menu_script"
    log::info "PLUGIN" "Development menu created: ./$dev_menu_script"
}

# Build customizations for local development
customize_build_for_local() {
    log::debug "PLUGIN" "Customizing build process for local development..."
    
    # Enable additional debugging output
    export XCODE_XCCONFIG_FILE="Scripts/config/local.xcconfig"
    
    # Create local xcconfig if it doesn't exist
    create_local_xcconfig
    
    # Setup build notifications (macOS only)
    if [[ "$(uname)" == "Darwin" ]]; then
        setup_build_notifications
    fi
}

create_local_xcconfig() {
    local xcconfig_file="Scripts/config/local.xcconfig"
    local xcconfig_dir
    xcconfig_dir=$(dirname "$xcconfig_file")
    
    ensure_directory "$xcconfig_dir"
    
    if [[ ! -f "$xcconfig_file" ]]; then
        cat > "$xcconfig_file" << 'EOF'
// Local Development Build Configuration for MSP iOS SDK

// Debugging
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
GCC_OPTIMIZATION_LEVEL = 0
SWIFT_OPTIMIZATION_LEVEL = -Onone
ENABLE_TESTABILITY = YES

// Performance (for faster local builds)
COMPILER_INDEX_STORE_ENABLE = NO
SWIFT_COMPILATION_MODE = singlefile

// Code signing (disabled for local development)
CODE_SIGN_IDENTITY = 
CODE_SIGNING_REQUIRED = NO
CODE_SIGNING_ALLOWED = NO

// Build settings
ONLY_ACTIVE_ARCH = YES
SKIP_INSTALL = NO
ENABLE_BITCODE = NO

// Warnings and analysis
CLANG_ANALYZER_NONNULL = YES
CLANG_WARN_DOCUMENTATION_COMMENTS = YES
CLANG_WARN_STRICT_PROTOTYPES = YES
GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR
GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE
EOF
        log::debug "PLUGIN" "Created local Xcode configuration: $xcconfig_file"
    fi
}

setup_build_notifications() {
    log::debug "PLUGIN" "Setting up build notifications..."
    
    # Create notification helper script
    local notify_script="/tmp/msp_notify.sh"
    
    cat > "$notify_script" << 'EOF'
#!/bin/bash
# Build notification helper for MSP iOS SDK

notify_build_success() {
    osascript -e 'display notification "Build completed successfully" with title "MSP iOS SDK" sound name "Glass"'
}

notify_build_failure() {
    osascript -e 'display notification "Build failed" with title "MSP iOS SDK" sound name "Basso"'
}

notify_test_success() {
    osascript -e 'display notification "Tests passed" with title "MSP iOS SDK" sound name "Glass"'
}

notify_test_failure() {
    osascript -e 'display notification "Tests failed" with title "MSP iOS SDK" sound name "Basso"'
}

case "$1" in
    build-success) notify_build_success ;;
    build-failure) notify_build_failure ;;
    test-success) notify_test_success ;;
    test-failure) notify_test_failure ;;
esac
EOF
    
    chmod +x "$notify_script"
    export BUILD_NOTIFICATION_SCRIPT="$notify_script"
}

# Performance monitoring for local development
monitor_local_performance() {
    if [[ "$BUILD_VERBOSE" == "YES" ]]; then
        log::debug "PLUGIN" "Starting local performance monitoring..."
        
        # Monitor build times
        export BUILD_START_TIME=$(date +%s)
        
        # Setup completion callback
        trap 'report_local_build_completion' EXIT
    fi
}

report_local_build_completion() {
    if [[ -n "$BUILD_START_TIME" ]]; then
        local build_duration=$(($(date +%s) - BUILD_START_TIME))
        local formatted_duration
        formatted_duration=$(format_duration $build_duration)
        
        log::info "PLUGIN" "Local build completed in $formatted_duration"
        
        # Show system resource usage
        if command -v top >/dev/null 2>&1; then
            local memory_pressure
            memory_pressure=$(top -l 1 -s 0 | grep "PhysMem" | cut -d: -f2 | xargs)
            log::debug "PLUGIN" "Memory usage: $memory_pressure"
        fi
    fi
}

# Plugin cleanup
plugin_cleanup() {
    if ! is_plugin_active; then
        return $EXIT_SUCCESS
    fi
    
    log::debug "PLUGIN" "Cleaning up local development plugin..."
    
    # Remove temporary files
    local temp_files=(
        "/tmp/msp_build_aliases.sh"
        "/tmp/configure_xcode.sh"
        "/tmp/msp_notify.sh"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
    done
    
    # Report build completion if notifications are enabled
    if [[ -n "$BUILD_NOTIFICATION_SCRIPT" ]] && [[ -f "$BUILD_NOTIFICATION_SCRIPT" ]]; then
        "$BUILD_NOTIFICATION_SCRIPT" "build-success" 2>/dev/null || true
    fi
    
    log::debug "PLUGIN" "Local development plugin cleanup completed"
}

# Plugin command handlers
handle_plugin_command() {
    local command="$1"
    shift
    
    case "$command" in
        "dev-menu")
            exec ./dev_menu.sh
            ;;
        "aliases")
            cat /tmp/msp_build_aliases.sh 2>/dev/null || echo "Aliases not available. Run build script first."
            ;;
        "configure-xcode")
            /tmp/configure_xcode.sh 2>/dev/null || echo "Xcode configuration script not available."
            ;;
        "performance")
            monitor_local_performance
            ;;
        *)
            log::warn "PLUGIN" "Unknown local plugin command: $command"
            return $EXIT_GENERAL_ERROR
            ;;
    esac
}

# Export plugin functions
export -f is_plugin_active plugin_init plugin_cleanup handle_plugin_command
export -f configure_local_environment setup_local_optimizations setup_development_helpers
export -f customize_build_for_local monitor_local_performance
