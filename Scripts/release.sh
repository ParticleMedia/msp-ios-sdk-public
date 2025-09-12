#!/bin/bash

# MSP iOS SDK Enhanced Release Script
# This script provides comprehensive release automation with rollback capabilities

# Script metadata
SCRIPT_VERSION="3.0.0"
SCRIPT_NAME="MSP iOS SDK Release System"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

log_release() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔍 $1${NC}"
    fi
}

print_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
}

# Utility functions
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

ensure_project_root() {
    local project_root=$(get_project_root)
    if [[ "$(pwd)" != "$project_root" ]]; then
        cd "$project_root"
    fi
}

# Framework configurations
MSPIOSSCORE_CONFIG="name=MSPiOSCore;scheme=MSPiOSCore;output_dir=outputMSPiOSCore;deploy_dir=MSPSharedLibraries;xcframework_name=MSPiOSCore.xcframework;source_only=false;podspec=MSPiOSCore/MSPiOSCore.podspec"
NOVACORE_CONFIG="name=NovaCore;scheme=NovaCore;output_dir=outputNova;deploy_dir=NovaAdapter;xcframework_name=NovaCore.xcframework;source_only=false;podspec=NovaCore/NovaCore.podspec"
MSPCORE_CONFIG="name=MSPCore;scheme=MSPCore;output_dir=;deploy_dir=;xcframework_name=;source_only=true;podspec=MSPCore/MSPCore.podspec"

# Supported pods for automatic version updating
SUPPORTED_PODS=("MSPiOSCore" "NovaCore" "MSPCore" "FacebookAdapter" "GoogleAdapter" "NovaAdapter" "MSPSharedLibraries" "PrebidAdapter" "AmazonAdapter" "UnityAdapter" "MintegralAdapter" "MobilefuseAdapter" "PubmaticAdapter" "InmobiAdapter" "MSPOMSDK")

# Parse config value
parse_config_value() {
    local config_string="$1"
    local key="$2"
    echo "$config_string" | grep -o "$key=[^;]*" | cut -d'=' -f2
}

# Load framework config
load_framework_config() {
    local framework_name="$1"
    local config_var="$(echo "$framework_name" | tr '[:lower:]' '[:upper:]')_CONFIG"
    local config_value="${!config_var}"
    
    if [[ -z "$config_value" ]]; then
        # Only log error if not being called from validation (stderr not redirected)
        if [[ -t 2 ]]; then
            log_error "Configuration not found for framework: $framework_name"
        fi
        return 1
    fi
    
    FRAMEWORK_NAME=$(parse_config_value "$config_value" "name")
    FRAMEWORK_SCHEME=$(parse_config_value "$config_value" "scheme")
    FRAMEWORK_OUTPUT_DIR=$(parse_config_value "$config_value" "output_dir")
    FRAMEWORK_DEPLOY_DIR=$(parse_config_value "$config_value" "deploy_dir")
    FRAMEWORK_XCFRAMEWORK_NAME=$(parse_config_value "$config_value" "xcframework_name")
    FRAMEWORK_SOURCE_ONLY=$(parse_config_value "$config_value" "source_only")
    FRAMEWORK_PODSPEC=$(parse_config_value "$config_value" "podspec")
    
    return 0
}

# Validation functions
validate_release_environment() {
    log_step "Validating release environment..."
    
    # Check if we're in the project root
    if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
        log_error "iOS workspace not found. Please run from project root."
        return 1
    fi
    
    # Check for required tools
    local required_tools="git xcodebuild pod"
    for tool in $required_tools; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Check for GitHub CLI if needed
    if [[ "$RELEASE_TO_GITHUB" == "true" ]] && ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) not found but required for GitHub releases"
        return 1
    fi
    
    # Check git status
    if ! git diff-index --quiet HEAD --; then
        log_warn "Git working directory is not clean. Please commit or stash changes."
        if [[ "$FORCE_RELEASE" != "true" ]]; then
            return 1
        fi
    fi
    
    log_success "Release environment validation passed"
    return 0
}

update_podspec_version() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Updating $pod_name podspec version to $version..."
    
    local podspec_file="${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec not found: $podspec_file"
        return 1
    fi
    
    # Update version in podspec
    if sed -i.bak "s/spec\.version.*=.*\".*\"/spec.version      = \"$version\"/" "$podspec_file"; then
        rm -f "${podspec_file}.bak"
        log_success "Updated $pod_name podspec version to $version"
        return 0
    else
        log_error "Failed to update $pod_name podspec version"
        return 1
    fi
}

update_podspec_repository_url() {
    local pod_name="$1"
    local repository_url="$2"
    
    log_step "Updating $pod_name podspec repository URL to $repository_url..."
    
    local podspec_file="${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec not found: $podspec_file"
        return 1
    fi
    
    # Update repository URL in podspec
    if sed -i.bak "s|spec\.source.*=.*{ :git => \".*\", :tag => \"#{spec\.version}\" }|spec.source       = { :git => \"$repository_url\", :tag => \"#{spec.version}\" }|" "$podspec_file"; then
        rm -f "${podspec_file}.bak"
        log_success "Updated $pod_name podspec repository URL to $repository_url"
        return 0
    else
        log_error "Failed to update $pod_name podspec repository URL"
        return 1
    fi
}

update_podspec_to_github_release() {
    local pod_name="$1"
    local version="$2"
    local repository_url="$3"
    
    log_step "Updating $pod_name podspec to use GitHub release format..."
    
    local podspec_file="${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec not found: $podspec_file"
        return 1
    fi
    
    # Use public repository URL for CocoaPods access
    local public_repo_url="https://github.com/ParticleMedia/msp-ios-sdk-public.git"
    
    # Update podspec to use Git format with public repository
    # Create a temporary file with the new source format
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
  spec.source = {
    git: "$public_repo_url",
    tag: "$version"
  }
EOF
    
    # Use awk to replace the source section
    awk '
    /spec\.source[[:space:]]*=/ && !/spec\.source_files/ {
        in_source = 1
        while ((getline line < "'$temp_file'") > 0) {
            print line
        }
        close("'$temp_file'")
        next
    }
    in_source && /^[[:space:]]*}/ {
        in_source = 0
        next
    }
    !in_source {
        print
    }
    ' "$podspec_file" > "${podspec_file}.new" && mv "${podspec_file}.new" "$podspec_file"
    
    rm -f "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        log_success "Updated $pod_name podspec to use GitHub release format"
        return 0
    else
        log_error "Failed to update $pod_name podspec to GitHub release format"
        return 1
    fi
}

update_swift_version() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Updating $pod_name Swift version strings..."
    
    # Find Swift files in the pod directory
    local swift_files=()
    if [[ -d "$pod_name" ]]; then
        while IFS= read -r -d '' file; do
            swift_files+=("$file")
        done < <(find "$pod_name" -name "*.swift" -print0)
    fi
    
    if [[ ${#swift_files[@]} -eq 0 ]]; then
        log_warn "No Swift files found for $pod_name"
        return 0
    fi
    
    local updated_files=0
    
    for swift_file in "${swift_files[@]}"; do
        local file_updated=false
        
        # Update MSPCore version property
        if [[ "$pod_name" == "MSPCore" ]] && [[ "$swift_file" == *"MSPHelper.swift" ]]; then
            if sed -i.bak "s|public let version = \".*\"|public let version = \"$version\"|" "$swift_file"; then
                file_updated=true
                rm -f "${swift_file}.bak"
            fi
        fi
        
        # Update getSDKVersion() functions in adapters
        if [[ "$swift_file" == *"Adapter.swift" ]]; then
            # Update getSDKVersion() return statements
            if sed -i.bak "s|return \"[^\"]*\"|return \"$version\"|g" "$swift_file"; then
                file_updated=true
                rm -f "${swift_file}.bak"
            fi
        fi
        
        if [[ "$file_updated" == true ]]; then
            ((updated_files++))
            log_info "Updated version in: $swift_file"
        fi
    done
    
    if [[ $updated_files -gt 0 ]]; then
        log_success "Updated version strings in $updated_files Swift files for $pod_name"
        return 0
    else
        log_warn "No version strings found to update in $pod_name Swift files"
        return 0
    fi
}

validate_pod_name() {
    local pod_name="$1"
    
    if [[ -z "$pod_name" ]]; then
        log_error "Pod name is required"
        return 1
    fi
    
    # Check if pod is in supported list
    local is_supported=false
    for pod in "${SUPPORTED_PODS[@]}"; do
        if [[ "$pod" == "$pod_name" ]]; then
            is_supported=true
            break
        fi
    done
    
    if [[ "$is_supported" != "true" ]]; then
        log_error "Unsupported pod: $pod_name. Supported pods: ${SUPPORTED_PODS[*]}"
        return 1
    fi
    
    # Check if podspec exists
    local podspec_file="${pod_name}.podspec"
    if [[ ! -f "$podspec_file" ]]; then
        log_error "Podspec not found: $podspec_file"
        return 1
    fi
    
    # Try to load framework config (for build configuration)
    # Use a subshell to prevent the function from causing the script to exit
    if (load_framework_config "$pod_name" 2>/dev/null); then
        log_info "Loaded framework config for $pod_name"
    else
        log_info "No framework config found for $pod_name, using default settings"
        FRAMEWORK_SOURCE_ONLY="true"
        FRAMEWORK_PODSPEC="$podspec_file"
    fi
    
    log_success "Pod validation passed: $pod_name"
    return 0
}

validate_version() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        return 1
    fi
    
    # Check version format (semantic versioning)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        log_error "Invalid version format: $version. Expected format: X.Y.Z[-prerelease][+build]"
        return 1
    fi
    
    # Check if version already exists
    if git tag -l | grep -q "^$version$"; then
        log_warn "Version $version already exists as a git tag, continuing with existing tag"
        # Don't return 1, just continue with the existing tag
    fi
    
    log_success "Version validation passed: $version"
    return 0
}

validate_repository_url() {
    local repository_url="$1"
    
    if [[ -z "$repository_url" ]]; then
        log_error "Repository URL is required"
        return 1
    fi
    
    # Check if it's a valid GitHub URL
    if [[ ! "$repository_url" =~ ^https://github\.com/[^/]+/[^/]+\.git$ ]]; then
        log_error "Invalid repository URL format: $repository_url. Expected: https://github.com/owner/repo.git"
        return 1
    fi
    
    log_success "Repository URL validation passed: $repository_url"
    return 0
}

# Build functions
is_source_only_pod() {
    local pod_name="$1"
    
    # Check if it's in the source-only list
    local source_only_pods=("MSPCore" "FacebookAdapter" "GoogleAdapter" "NovaAdapter" "MSPSharedLibraries" "PrebidAdapter" "AmazonAdapter" "UnityAdapter" "MintegralAdapter" "MobilefuseAdapter" "PubmaticAdapter" "InmobiAdapter" "MSPOMSDK")
    for source_pod in "${source_only_pods[@]}"; do
        if [[ "$pod_name" == "$source_pod" ]]; then
            return 0
        fi
    done
    
    # Check framework config
    if load_framework_config "$pod_name" 2>/dev/null; then
        if [[ "$FRAMEWORK_SOURCE_ONLY" == "true" ]]; then
            return 0
        fi
    fi
    
    return 1
}

build_framework_for_release() {
    local framework_name="$1"
    
    # Check if this is a source-only pod
    if is_source_only_pod "$framework_name"; then
        log_info "Framework $framework_name is source-only, skipping build"
        return 0
    fi
    
    log_step "Building $framework_name for release..."
    
    if ! load_framework_config "$framework_name"; then
        return 1
    fi
    
    # Use the unified build script
    if [[ -f "Scripts/build.sh" ]]; then
        if ./Scripts/build.sh --framework "$framework_name" --skip-code-sign; then
            log_success "Framework $framework_name built successfully"
            return 0
        else
            log_error "Failed to build framework $framework_name"
            return 1
        fi
    else
        # Fallback to individual build scripts
        case "$framework_name" in
            "MSPiOSCore")
                if [[ -f "Scripts/buildiOSCoreXCFramework.sh" ]]; then
                    SKIP_CODE_SIGN=1 ./Scripts/buildiOSCoreXCFramework.sh
                    return $?
                fi
                ;;
            "NovaCore")
                if [[ -f "Scripts/buildNovaXCFramework.sh" ]]; then
                    SKIP_CODE_SIGN=1 ./Scripts/buildNovaXCFramework.sh
                    return $?
                fi
                ;;
        esac
    fi
    
    log_error "No build method found for $framework_name"
    return 1
}

# Podspec validation and publishing
validate_podspec() {
    local pod_name="$1"
    
    log_step "Validating podspec for $pod_name..."
    
    # Check if validation should be skipped
    if [[ "$skip_validation" == "true" ]]; then
        log_info "Skipping podspec validation (--skip-validation flag)"
        return 0
    fi
    
    # Try to load framework config, but don't fail if it doesn't exist
    if load_framework_config "$pod_name" 2>/dev/null; then
        local podspec_path="$FRAMEWORK_PODSPEC"
    else
        # Use default podspec path for unsupported pods
        local podspec_path="${pod_name}.podspec"
    fi
    
    if [[ ! -f "$podspec_path" ]]; then
        log_error "Podspec not found: $podspec_path"
        return 1
    fi
    
    # Validate podspec
    if pod spec lint "$podspec_path" --allow-warnings --skip-import-validation; then
        log_success "Podspec validation passed: $pod_name"
        return 0
    else
        log_error "Podspec validation failed: $pod_name"
        return 1
    fi
}

publish_to_cocoapods() {
    local pod_name="$1"
    local version="$2"
    local repository_url="$3"
    
    log_step "Publishing $pod_name version $version to CocoaPods..."
    
    # Try to load framework config, but don't fail if it doesn't exist
    local podspec_path
    if load_framework_config "$pod_name" 2>/dev/null; then
        podspec_path="$FRAMEWORK_PODSPEC"
    else
        # Use default podspec path for unsupported pods
        podspec_path="${pod_name}.podspec"
    fi
    
    # Check if user is authenticated with CocoaPods trunk
    if ! pod trunk me >/dev/null 2>&1; then
        log_error "Not authenticated with CocoaPods trunk. Cannot publish to CocoaPods."
        log_info "To authenticate:"
        log_info "1. Run: pod trunk register your-email@company.com 'Your Name'"
        log_info "2. Check your email and click the verification link"
        log_info "3. Run: pod trunk me (to verify authentication)"
        return 1
    fi
    
    # Use the working 0.0.1-migration approach: Git format with complete podspec
    # Create a temporary podspec with Git format and complete content
    # Use the correct filename that matches the spec name
    local temp_podspec="${pod_name}.podspec"
    cp "$podspec_path" "$temp_podspec"
    
    # Clean up the podspec (remove extra blank lines at the beginning)
    sed -i.bak '/^$/N;/^\\n$/d' "$temp_podspec"
    rm -f "${temp_podspec}.bak"
    
    # Convert to Git format for CocoaPods publishing
    # Use the correct filename that matches the spec name
    local temp_podspec="${pod_name}.podspec"
    cp "$podspec_path" "$temp_podspec"
    
    # Clean up the podspec (remove extra blank lines at the beginning)
    sed -i.bak '/^$/N;/^\\n$/d' "$temp_podspec"
    rm -f "${temp_podspec}.bak"
    
    # Convert to Git format for CocoaPods publishing
    # Use the public repository URL for CocoaPods access
    local git_repo_url="https://github.com/ParticleMedia/msp-ios-sdk-public.git"
    sed -i.bak "/spec\.source = {/,/}/c\\
  spec.source = { :git => \"$git_repo_url\", :tag => \"$version\" }" "$temp_podspec"
    rm -f "${temp_podspec}.bak"
    
    # Add missing required sections to make it complete like 0.0.1-migration
    add_complete_podspec_sections "$temp_podspec" "$pod_name"
    
    # Publish to CocoaPods trunk
    if pod trunk push "$temp_podspec" --allow-warnings; then
        log_success "Successfully published $pod_name version $version to CocoaPods"
        rm -f "$temp_podspec"
        return 0
    else
        log_error "Failed to publish $pod_name version $version to CocoaPods"
        log_info "Debug: Temporary podspec saved as $temp_podspec for inspection"
        return 1
    fi
}

# Function to add complete podspec sections based on 0.0.1-migration working format
add_complete_podspec_sections() {
    local podspec_file="$1"
    local pod_name="$2"
    
    log_step "Adding complete podspec sections for $pod_name..."
    
    # Add required sections before the end statement
    local temp_file=$(mktemp)
    
    # Get pod-specific dependencies
    local dependencies=""
    case "$pod_name" in
        "AmazonAdapter")
            dependencies="spec.dependency 'Google-Mobile-Ads-SDK', \"~> 12.0\"
  spec.dependency \"AmazonPublisherServicesSDK\", \"4.5.5\"
  spec.dependency \"AmazonPublisherServicesAdMobAdapter\", \"2.2.0\"
  spec.dependency 'MSPSharedLibraries'"
            ;;
        "FacebookAdapter"|"GoogleAdapter"|"NovaAdapter")
            dependencies="spec.dependency 'Google-Mobile-Ads-SDK', \"~> 12.0\"
  spec.dependency 'MSPSharedLibraries'"
            ;;
        "MSPCore")
            dependencies="spec.dependency 'MSPSharedLibraries'
  spec.dependency 'PrebidAdapter'"
            ;;
        "PrebidAdapter")
            dependencies="spec.dependency 'MSPSharedLibraries'"
            ;;
        "MSPSharedLibraries")
            dependencies=""
            ;;
        *)
            dependencies="spec.dependency 'MSPSharedLibraries'"
            ;;
    esac
    
    cat > "$temp_file" << EOF

  spec.ios.deployment_target = '13.0'

  spec.source_files  = "${pod_name}/${pod_name}/**/*.{h,m,swift}"
  spec.exclude_files = "Classes/Exclude"

  $dependencies

  spec.pod_target_xcconfig = { 'VALID_ARCHS' => 'x86_64 armv7 arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  spec.static_framework = true

end
EOF
    
    # Insert the content before the final 'end'
    sed -i.bak '/^end$/d' "$podspec_file"
    cat "$temp_file" >> "$podspec_file"
    rm -f "$temp_file" "${podspec_file}.bak"
    
    log_success "Added complete podspec sections for $pod_name"
}

# GitHub release functions
create_github_release() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Creating GitHub release for $pod_name version $version..."
    
    # Check if GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        log_warn "GitHub CLI not available. Skipping GitHub release creation."
        return 0
    fi
    
    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        log_warn "GitHub CLI not authenticated. Skipping GitHub release creation."
        return 0
    fi
    
    # Create release
    local release_title="$pod_name v$version"
    local release_notes="Release of $pod_name version $version"
    
    if gh release create "$version" --title "$release_title" --notes "$release_notes"; then
        log_success "GitHub release created: $version"
        return 0
    else
        log_error "Failed to create GitHub release: $version"
        return 1
    fi
}

create_github_release_with_zip() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Creating GitHub release with zip for $pod_name version $version..."
    
    # Check if GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        log_warn "GitHub CLI not available. Skipping GitHub release creation."
        return 0
    fi
    
    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        log_warn "GitHub CLI not authenticated. Skipping GitHub release creation."
        return 0
    fi
    
    # Create zip file for the pod
    local zip_name="${pod_name}-${version}.zip"
    local source_dir="$pod_name"
    
    if [[ -d "$source_dir" ]]; then
        if zip -r "$zip_name" "$source_dir" -x "*.DS_Store" "*.git*" "*.xcuserstate" "*.xcworkspace/xcuserdata/*" "*.xcodeproj/xcuserdata/*" "*.xcodeproj/project.xcworkspace/xcuserdata/*"; then
            # Create release with zip file
            local release_title="$pod_name v$version"
            local release_notes="Release of $pod_name version $version"
            
            if gh release create "$version" "$zip_name" --title "$release_title" --notes "$release_notes"; then
                log_success "GitHub release created with zip: $version"
                rm -f "$zip_name"
                return 0
            else
                log_error "Failed to create GitHub release: $version"
                rm -f "$zip_name"
                return 1
            fi
        else
            log_error "Failed to create zip file: $zip_name"
            return 1
        fi
    else
        log_warn "Source directory not found: $source_dir"
        return 0
    fi
}

upload_release_assets() {
    local pod_name="$1"
    local version="$2"
    
    log_step "Uploading release assets for $pod_name version $version..."
    
    if ! command -v gh >/dev/null 2>&1; then
        log_warn "GitHub CLI not available. Skipping asset upload."
        return 0
    fi
    
    # Create source distribution
    local source_dir="$pod_name"
    local zip_name="${pod_name}-${version}.zip"
    
    if [[ -d "$source_dir" ]]; then
        if zip -r "$zip_name" "$source_dir" -x "*.DS_Store" "*.git*" "*.xcuserstate" "*.xcworkspace/xcuserdata/*" "*.xcodeproj/xcuserdata/*" "*.xcodeproj/project.xcworkspace/xcuserdata/*"; then
            # Upload to GitHub release
            if gh release upload "$version" "$zip_name"; then
                log_success "Uploaded $zip_name to GitHub release"
                rm -f "$zip_name"
                return 0
            else
                log_error "Failed to upload $zip_name to GitHub release"
                rm -f "$zip_name"
                return 1
            fi
        else
            log_error "Failed to create source distribution: $zip_name"
            return 1
        fi
    else
        log_warn "Source directory not found: $source_dir"
        return 0
    fi
}

# Git operations
create_git_tag() {
    local pod_name="$1"
    local version="$2"
    local message="$3"
    
    # Use simple version tag (like 0.0.1-migration approach)
    local tag_name="$version"
    
    # Check if tag already exists
    if git tag -l | grep -q "^$tag_name$"; then
        log_warn "Git tag already exists: $tag_name, using existing tag"
        return 0
    fi
    
    log_step "Creating git tag: $tag_name"
    
    if git tag -a "$tag_name" -m "$message"; then
        log_success "Git tag created: $tag_name"
        return 0
    else
        log_error "Failed to create git tag: $tag_name"
        return 1
    fi
}

push_git_tag() {
    local pod_name="$1"
    local version="$2"
    
    # Use simple version tag (like 0.0.1-migration approach)
    local tag_name="$version"
    
    log_step "Pushing git tag: $tag_name"
    
    # Push to private repository first
    if git push origin "$tag_name" 2>/dev/null; then
        log_success "Git tag pushed to private repo: $tag_name"
    elif git push origin "$tag_name" 2>&1 | grep -q "already exists"; then
        log_warn "Git tag already exists in private repo: $tag_name, continuing"
    else
        log_error "Failed to push git tag to private repo: $tag_name"
        return 1
    fi
    
    # Push to public repository for CocoaPods access
    if git remote get-url public >/dev/null 2>&1; then
        if git push public "$tag_name" 2>/dev/null; then
            log_success "Git tag pushed to public repo: $tag_name"
        elif git push public "$tag_name" 2>&1 | grep -q "already exists"; then
            log_warn "Git tag already exists in public repo: $tag_name, continuing"
        else
            log_warn "Failed to push git tag to public repo: $tag_name"
        fi
    else
        log_info "Adding public repository remote..."
        if git remote add public https://github.com/ParticleMedia/msp-ios-sdk-public.git; then
            if git push public "$tag_name" 2>/dev/null; then
                log_success "Git tag pushed to public repo: $tag_name"
            elif git push public "$tag_name" 2>&1 | grep -q "already exists"; then
                log_warn "Git tag already exists in public repo: $tag_name, continuing"
            else
                log_warn "Failed to push git tag to public repo: $tag_name"
            fi
        else
            log_warn "Failed to add public repository remote"
        fi
    fi
    
    return 0
}

# Rollback functions
rollback_release() {
    local pod_name="$1"
    local version="$2"
    local reason="$3"
    
    # Use simple version tag (like 0.0.1-migration approach)
    local tag_name="$version"
    
    log_error "Rolling back release: $pod_name version $version"
    log_error "Reason: $reason"
    
    # Delete git tag
    if git tag -d "$tag_name" 2>/dev/null; then
        log_info "Deleted local git tag: $tag_name"
    fi
    
    # Push deletion to remote
    if git push origin ":refs/tags/$tag_name" 2>/dev/null; then
        log_info "Deleted remote git tag: $tag_name"
    fi
    
    # Delete from public repository if it exists
    if git remote get-url public >/dev/null 2>&1; then
        if git push public ":refs/tags/$tag_name" 2>/dev/null; then
            log_info "Deleted public git tag: $tag_name"
        fi
    fi
    
    # Delete GitHub release if it exists
    if command -v gh >/dev/null 2>&1; then
        if gh release delete "$tag_name" --yes 2>/dev/null; then
            log_info "Deleted GitHub release: $tag_name"
        fi
    fi
    
    log_warn "Release rollback completed. Manual cleanup may be required."
}

# Backup and restore functions
create_backup() {
    local backup_dir="/tmp/release_backup_$(date +%Y%m%d_%H%M%S)"
    
    log_step "Creating release backup: $backup_dir" >&2
    
    mkdir -p "$backup_dir"
    
    # Backup important files
    local backup_files="Podfile.lock Scripts/buildiOSCoreXCFramework.sh Scripts/buildNovaXCFramework.sh"
    for file in $backup_files; do
        if [[ -f "$file" ]]; then
            cp "$file" "$backup_dir/"
            log_debug "Backed up: $file"
        fi
    done
    
    # Backup built frameworks
    if [[ -d "MSPSharedLibraries/MSPiOSCore.xcframework" ]]; then
        cp -R "MSPSharedLibraries/MSPiOSCore.xcframework" "$backup_dir/"
    fi
    
    if [[ -d "NovaAdapter/NovaCore.xcframework" ]]; then
        cp -R "NovaAdapter/NovaCore.xcframework" "$backup_dir/"
    fi
    
    echo "$backup_dir"
}

restore_backup() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    log_step "Restoring from backup: $backup_dir"
    
    # Restore files
    for file in "$backup_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            cp "$file" "./$filename"
            log_debug "Restored: $filename"
        fi
    done
    
    # Restore frameworks
    if [[ -d "$backup_dir/MSPiOSCore.xcframework" ]]; then
        cp -R "$backup_dir/MSPiOSCore.xcframework" "MSPSharedLibraries/"
    fi
    
    if [[ -d "$backup_dir/NovaCore.xcframework" ]]; then
        cp -R "$backup_dir/NovaCore.xcframework" "NovaAdapter/"
    fi
    
    log_success "Backup restoration completed"
    return 0
}

# Main release function
perform_release() {
    local pod_name="$1"
    local version="$2"
    local backup_dir=""
    
    print_section "Starting Release Process"
    log_release "Releasing $pod_name version $version"
    
    # Create backup
    backup_dir=$(create_backup)
    
    # Validate everything
    if ! validate_release_environment; then
        rollback_release "$pod_name" "$version" "Environment validation failed"
        return 1
    fi
    
    if ! validate_pod_name "$pod_name"; then
        rollback_release "$pod_name" "$version" "Pod validation failed"
        return 1
    fi
    
    if ! validate_version "$version"; then
        rollback_release "$pod_name" "$version" "Version validation failed"
        return 1
    fi
    
    # Validate repository URL if provided
    if [[ -n "$repository_url" ]] && ! validate_repository_url "$repository_url"; then
        rollback_release "$pod_name" "$version" "Repository URL validation failed"
        return 1
    fi
    
    # Auto-update podspec version
    if ! update_podspec_version "$pod_name" "$version"; then
        rollback_release "$pod_name" "$version" "Podspec version update failed"
        return 1
    fi
    
    # Auto-update Swift version strings
    if ! update_swift_version "$pod_name" "$version"; then
        rollback_release "$pod_name" "$version" "Swift version update failed"
        return 1
    fi
    
    # Auto-update podspec repository URL if provided
    if [[ -n "$repository_url" ]]; then
        if [[ "$use_github_release" == "true" ]]; then
            if ! update_podspec_to_github_release "$pod_name" "$version" "$repository_url"; then
                rollback_release "$pod_name" "$version" "Podspec GitHub release format update failed"
                return 1
            fi
        else
            if ! update_podspec_repository_url "$pod_name" "$repository_url"; then
                rollback_release "$pod_name" "$version" "Podspec repository URL update failed"
                return 1
            fi
        fi
    fi
    
    # Build framework
    if ! build_framework_for_release "$pod_name"; then
        rollback_release "$pod_name" "$version" "Build failed"
        return 1
    fi
    
    # Validate podspec
    if ! validate_podspec "$pod_name"; then
        rollback_release "$pod_name" "$version" "Podspec validation failed"
        return 1
    fi
    
    # Create git tag
    local tag_message="Release $pod_name version $version"
    if ! create_git_tag "$pod_name" "$version" "$tag_message"; then
        rollback_release "$pod_name" "$version" "Git tag creation failed"
        return 1
    fi
    
    # Push git tag
    if ! push_git_tag "$pod_name" "$version"; then
        rollback_release "$pod_name" "$version" "Git tag push failed"
        return 1
    fi
    
    # Create GitHub release
    if [[ "$use_github_release" == "true" ]]; then
        if ! create_github_release_with_zip "$pod_name" "$version"; then
            log_warn "GitHub release with zip creation failed, but continuing with other steps"
        fi
    else
        if ! create_github_release "$pod_name" "$version"; then
            log_warn "GitHub release creation failed, but continuing with other steps"
        fi
    fi
    
    # Upload release assets
    if ! upload_release_assets "$pod_name" "$version"; then
        log_warn "Asset upload failed, but continuing with other steps"
    fi
    
    # Publish to CocoaPods (if enabled)
    if [[ "$publish_cocoapods" == "true" ]]; then
        if ! publish_to_cocoapods "$pod_name" "$version" "$repository_url"; then
            rollback_release "$pod_name" "$version" "CocoaPods publishing failed"
            return 1
        fi
    else
        log_info "Skipping CocoaPods publishing (PUBLISH_TO_COCOAPODS=false)"
    fi
    
    # Cleanup backup
    if [[ -d "$backup_dir" ]]; then
        rm -rf "$backup_dir"
        log_debug "Cleaned up backup: $backup_dir"
    fi
    
    print_section "Release Completed Successfully"
    log_success "🎉 $pod_name version $version has been released!"
    log_info "Git tag: $version"
    log_info "GitHub release: $version"
    if [[ "$publish_cocoapods" == "true" ]]; then
        log_info "CocoaPods: Published"
    fi
    
    return 0
}

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Enhanced release script for MSP iOS SDK with rollback capabilities.

USAGE:
    $0 [OPTIONS] POD_NAME VERSION

OPTIONS:
    --help, -h                    Show this help message
    --version, -v                 Show version information
    --dry-run                     Show what would be released without executing
    --force                       Force release even with uncommitted changes
    --skip-build                  Skip building frameworks
    --skip-validation             Skip podspec validation
    --skip-cocoapods              Skip CocoaPods publishing
    --skip-github                 Skip GitHub release creation
    --repository URL              Set repository URL for podspec source
    --github-release              Use GitHub releases with zip files (like 0.0.1-migration)
    --publish-cocoapods           Enable CocoaPods publishing
    --backup                      Create backup before release
    --restore BACKUP_DIR          Restore from backup directory
    --rollback POD_NAME VERSION   Rollback a specific release
    --verbose                     Enable verbose output

ENVIRONMENT VARIABLES:
    COCOAPODS_TRUNK_TOKEN         CocoaPods trunk token for publishing
    GITHUB_TOKEN                  GitHub token for releases
    FORCE_RELEASE                 Force release even with validation issues
    PUBLISH_TO_COCOAPODS          Enable CocoaPods publishing (default: false)

POD NAMES:
    MSPiOSCore                    MSP iOS Core framework
    NovaCore                      Nova Core framework
    MSPCore                       MSP Core framework
    FacebookAdapter               Facebook Adapter (source-only)
    GoogleAdapter                 Google Adapter (source-only)
    NovaAdapter                   Nova Adapter (source-only)
    MSPSharedLibraries            MSP Shared Libraries (source-only)
    PrebidAdapter                 Prebid Adapter (source-only)

EXAMPLES:
    # Release MSPiOSCore version 1.2.3
    $0 MSPiOSCore 1.2.3
    
    # Dry run release
    $0 --dry-run MSPiOSCore 1.2.3
    
    # Release with CocoaPods publishing
    PUBLISH_TO_COCOAPODS=true $0 MSPiOSCore 1.2.3
    
    # Force release with uncommitted changes
    $0 --force MSPiOSCore 1.2.3
    
    # Rollback a release
    $0 --rollback MSPiOSCore 1.2.3

EOF
}

show_version() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Enhanced Release Features:
- Comprehensive validation and error handling
- Automatic rollback on failure
- Backup and restore capabilities
- GitHub release integration
- CocoaPods publishing support
- Git tag management
- Dry-run mode for testing

Supported Pods:
- MSPiOSCore
- NovaCore
- MSPCore

EOF
}

# Main execution
main() {
    # Ensure we're in the project root
    ensure_project_root
    
    # Parse arguments
    local pod_name=""
    local version=""
    local dry_run_mode=false
    local force_mode=false
    local skip_build=false
    local skip_validation=false
    local skip_cocoapods=false
    local skip_github=false
    local publish_cocoapods=true
    local backup_mode=false
    local restore_backup_dir=""
    local rollback_mode=false
    local rollback_pod=""
    local rollback_version=""
    local repository_url="https://github.com/ParticleMedia/msp-ios-sdk.git"
    local use_github_release="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            --force)
                force_mode=true
                export FORCE_RELEASE=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --skip-cocoapods)
                skip_cocoapods=true
                shift
                ;;
            --skip-github)
                skip_github=true
                shift
                ;;
            --repository)
                repository_url="$2"
                shift 2
                ;;
            --github-release)
                use_github_release="true"
                shift
                ;;
            --publish-cocoapods)
                publish_cocoapods=true
                export PUBLISH_TO_COCOAPODS=true
                shift
                ;;
            --backup)
                backup_mode=true
                shift
                ;;
            --restore)
                restore_backup_dir="$2"
                shift 2
                ;;
            --rollback)
                rollback_mode=true
                rollback_pod="$2"
                rollback_version="$3"
                shift 3
                ;;
            --verbose)
                set -x
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$pod_name" ]]; then
                    pod_name="$1"
                elif [[ -z "$version" ]]; then
                    version="$1"
                fi
                shift
                ;;
        esac
    done
    
    print_section "MSP iOS SDK Release System"
    log_info "Version: $SCRIPT_VERSION"
    
    # Handle special modes
    if [[ "$backup_mode" == "true" ]]; then
        local backup_dir=$(create_backup)
        log_success "Backup created: $backup_dir"
        exit 0
    fi
    
    if [[ -n "$restore_backup_dir" ]]; then
        if restore_backup "$restore_backup_dir"; then
            log_success "Backup restored successfully"
            exit 0
        else
            log_error "Backup restoration failed"
            exit 1
        fi
    fi
    
    if [[ "$rollback_mode" == "true" ]]; then
        if [[ -z "$rollback_pod" ]] || [[ -z "$rollback_version" ]]; then
            log_error "Rollback requires both pod name and version"
            exit 1
        fi
        rollback_release "$rollback_pod" "$rollback_version" "Manual rollback"
        exit 0
    fi
    
    # Check required arguments
    if [[ -z "$pod_name" ]] || [[ -z "$version" ]]; then
        log_error "Pod name and version are required"
        show_help
        exit 1
    fi
    
    # Show dry run
    if [[ "$dry_run_mode" == "true" ]]; then
        print_section "Dry Run - What Would Be Released"
        log_info "Pod: $pod_name"
        log_info "Version: $version"
        log_info "Skip build: $skip_build"
        log_info "Skip validation: $skip_validation"
        log_info "Skip CocoaPods: $skip_cocoapods"
        log_info "Skip GitHub: $skip_github"
        log_info "Repository URL: $repository_url"
        log_info "Publish to CocoaPods: $publish_cocoapods"
        log_info "Force mode: $force_mode"
        exit 0
    fi
    
    # Perform release
    if perform_release "$pod_name" "$version"; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"
