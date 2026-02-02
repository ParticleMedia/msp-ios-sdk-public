#!/bin/bash

# MSP iOS SDK CI/CD Setup Script
# This script sets up the CI/CD environment with Fastlane and GitHub Actions

set -e

# Get script directory and source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared library modules for consistent functionality
# - colors.sh: Color-coded output functions
# - common.sh: Common utilities and project root management
# - validation.sh: Environment and dependency validation
# - logging.sh: Structured logging functions
source "$SCRIPT_DIR/Scripts/lib/colors.sh"
source "$SCRIPT_DIR/Scripts/lib/common.sh"
source "$SCRIPT_DIR/Scripts/lib/validation.sh"
source "$SCRIPT_DIR/Scripts/lib/logging.sh"

# Function to print colored output (using shared library)
print_step() {
    color_info "🔧 $1"
}

print_success() {
    color_success "✅ $1"
}

print_warning() {
    color_warning "⚠️ $1"
}

print_error() {
    color_error "❌ $1"
}

print_section() {
    color_highlight "═══════════════════════════════════════════════════════════════"
    color_highlight "$1"
    color_highlight "═══════════════════════════════════════════════════════════════"
}

require_path() {
    local path="$1"
    local type="${2:-any}"
    if [[ "$type" == "dir" && ! -d "$path" ]]; then
        print_error "Required directory missing: $path"
        exit 1
    fi
    if [[ "$type" == "file" && ! -f "$path" ]]; then
        print_error "Required file missing: $path"
        exit 1
    fi
    if [[ "$type" == "any" && ! -e "$path" ]]; then
        print_error "Required path missing: $path"
        exit 1
    fi
}

# Check if we're in the right directory
if [ ! -f "Podfile" ]; then
    print_error "This script must be run from the root of the MSP iOS SDK project"
    exit 1
fi

# Ensure we're in the project root
ensure_project_root

print_step "Validating required paths..."
require_path "Scripts" "dir"
require_path "Scripts/lib" "dir"
require_path "Scripts/ci/ci_validate.sh" "file"
require_path "Scripts/tests/run-unit-tests.sh" "file"
require_path ".github/workflows" "dir"
require_path "Examples/MSPDemoApp" "dir"
print_success "Required paths validated"

print_section "MSP iOS SDK CI/CD Setup"
echo "This script will set up the CI/CD environment with Fastlane and GitHub Actions"
echo ""

# Check Ruby version
print_step "Checking Ruby version..."
RUBY_VERSION=$(ruby --version | grep -o 'ruby [0-9]\+\.[0-9]\+' | cut -d' ' -f2)
REQUIRED_RUBY="3.0"

if [ "$(printf '%s\n' "$REQUIRED_RUBY" "$RUBY_VERSION" | sort -V | head -n1)" = "$REQUIRED_RUBY" ]; then
    print_success "Ruby $RUBY_VERSION is compatible (requires $REQUIRED_RUBY+)"
else
    print_warning "Ruby $RUBY_VERSION detected, but $REQUIRED_RUBY+ is recommended"
fi

# Validate environment using shared library
print_step "Validating development environment..."
if validate_development_environment; then
    print_success "Development environment validation passed"
else
    print_warning "Some environment validation issues detected"
fi

# Check if Bundler is installed
print_step "Checking Bundler installation..."
if command -v bundle &> /dev/null; then
    print_success "Bundler is installed"
else
    print_warning "Bundler not found, installing..."
    gem install bundler
fi

# Install Ruby dependencies
print_step "Installing Ruby dependencies..."
if bundle install; then
    print_success "Ruby dependencies installed successfully"
else
    print_error "Failed to install Ruby dependencies"
    exit 1
fi

# Check if Fastlane is working
print_step "Verifying Fastlane installation..."
if bundle exec fastlane --version &> /dev/null; then
    print_success "Fastlane is working correctly"
else
    print_error "Fastlane verification failed"
    exit 1
fi

# Install CocoaPods dependencies
print_step "Installing CocoaPods dependencies..."
if pod install; then
    print_success "CocoaPods dependencies installed successfully"
else
    print_warning "CocoaPods installation had issues, but continuing..."
fi

# Check project status
print_step "Checking project status..."
if bundle exec fastlane status; then
    print_success "Project status check completed"
else
    print_warning "Project status check had issues"
fi

# Create .gitignore entries if needed
print_step "Checking .gitignore configuration..."
if [ -f ".gitignore" ]; then
    if [[ -n "${CI:-}" ]]; then
        print_warning "CI environment detected; skipping .gitignore updates"
    else
        if [[ "${ALLOW_GITIGNORE_UPDATE:-0}" == "1" ]]; then
            if ! grep -q "Gemfile.lock" .gitignore; then
                echo "Gemfile.lock" >> .gitignore
                print_success "Added Gemfile.lock to .gitignore"
            else
                print_success "Gemfile.lock already in .gitignore"
            fi
            if ! grep -q ".bundle/" .gitignore; then
                echo ".bundle/" >> .gitignore
                print_success "Added .bundle/ to .gitignore"
            else
                print_success ".bundle/ already in .gitignore"
            fi
        else
            if ! grep -q "Gemfile.lock" .gitignore; then
                print_warning "Gemfile.lock missing from .gitignore (set ALLOW_GITIGNORE_UPDATE=1 to add)"
            fi
            if ! grep -q ".bundle/" .gitignore; then
                print_warning ".bundle/ missing from .gitignore (set ALLOW_GITIGNORE_UPDATE=1 to add)"
            fi
        fi
    fi
else
    print_warning ".gitignore not found, consider creating one"
fi

# Setup instructions
print_section "Setup Complete!"
log_info "🎉 CI/CD environment setup completed successfully!"

log_info "Next steps:"
log_info "1. Configure GitHub repository secrets (see CI_CD_README.md)"
log_info "2. Push changes to trigger GitHub Actions"
log_info "3. Test the pipeline with a pull request"

log_info "Quick commands:"
log_info "  bundle exec fastlane status          # Check project status"
log_info "  bundle exec fastlane test            # Run tests"
log_info "  bundle exec fastlane build_all       # Build frameworks"
log_info "  bundle exec fastlane --help          # Show all available lanes"

log_info "For detailed documentation, see CI_CD_README.md"

# Check if GitHub Actions directory exists
if [ -d ".github/workflows" ]; then
    print_success "GitHub Actions workflows are configured"
else
    print_warning "GitHub Actions workflows directory not found"
fi

# Check if Fastlane directory exists
if [ -d "fastlane" ]; then
    print_success "Fastlane configuration is set up"
else
    print_warning "Fastlane configuration directory not found"
fi

# Check if Scripts directory and shared libraries exist
if [ -d "Scripts/lib" ]; then
    print_success "Scripts shared libraries are available"
else
    print_warning "Scripts shared libraries directory not found"
fi

print_section "Environment Information"
echo "Ruby version: $(ruby --version)"
echo "Bundler version: $(bundle --version)"
echo "Fastlane version: $(bundle exec fastlane --version)"
echo "CocoaPods version: $(pod --version)"
echo "Xcode version: $(xcodebuild -version | head -n1)"
echo ""

print_success "Setup script completed successfully!"
echo "Your MSP iOS SDK project is now ready for CI/CD automation!"
