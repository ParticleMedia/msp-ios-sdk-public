#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Parse Remote Package.swift
# ============================================================================
# Purpose: Download and parse remote Package.swift to extract package name
#          and product names
#
# Usage:   ./parse_remote_package.sh <sandbox_path> <remote_url>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

parse_remote_package() {
    local sandbox="$1"
    local remote_url="$2"
    
    if [[ -z "$sandbox" ]] || [[ -z "$remote_url" ]]; then
        vr_log::error "SPM" "Sandbox path and remote URL required"
        return 1
    fi
    
    mkdir -p "$sandbox/tmp"
    local remote_package_file="$sandbox/tmp/Package.swift.remote"
    
    # Determine if this is a GitHub URL
    local package_url=""
    if [[ "$remote_url" =~ ^https://github.com/([^/]+)/([^/]+) ]]; then
        # GitHub URL: use raw.githubusercontent.com
        local repo_owner="${BASH_REMATCH[1]}"
        local repo_name="${BASH_REMATCH[2]%.git}"
        repo_name="${repo_name#*/}"
        
        # Try to get the default branch or use main/master
        local branch="main"
        if command -v git >/dev/null 2>&1; then
            local default_branch
            default_branch="$(git ls-remote --symref "$remote_url" HEAD 2>/dev/null | grep 'refs/heads/' | sed 's/.*refs\/heads\///' | sed 's/[[:space:]].*//' | head -1 || echo "")"
            if [[ -n "$default_branch" ]]; then
                branch="$default_branch"
            fi
        fi
        
        package_url="https://raw.githubusercontent.com/${repo_owner}/${repo_name}/${branch}/Package.swift"
        vr_log::info "SPM" "[SPM] Detected GitHub repository, using raw URL: $package_url"
    else
        # Non-GitHub URL: try to get default branch and construct raw URL
        vr_log::info "SPM" "[SPM] Non-GitHub repository detected, attempting to determine default branch..."
        local default_branch="main"
        if command -v git >/dev/null 2>&1; then
            local branch_info
            branch_info="$(git ls-remote --symref "$remote_url" HEAD 2>/dev/null | grep 'refs/heads/' | sed 's/.*refs\/heads\///' | head -1 || echo "")"
            if [[ -n "$branch_info" ]]; then
                default_branch="$branch_info"
            fi
        fi
        
        # For non-GitHub, try common patterns
        # Pattern 1: <url>/raw/<branch>/Package.swift
        package_url="${remote_url%.git}/raw/${default_branch}/Package.swift"
        vr_log::info "SPM" "[SPM] Attempting raw URL pattern: $package_url"
    fi
    
    vr_log::info "SPM" "[SPM] Downloading remote Package.swift from: $package_url"
    if ! curl -sSfL "$package_url" -o "$remote_package_file" 2>/dev/null; then
        vr_log::warn "SPM" "[SPM] Failed to download Package.swift from: $package_url"
        # Try alternative: use version tag in URL
        if [[ "$remote_url" =~ ^https://github.com/([^/]+)/([^/]+) ]]; then
            local repo_owner="${BASH_REMATCH[1]}"
            local repo_name="${BASH_REMATCH[2]%.git}"
            repo_name="${repo_name#*/}"
            local version="${MSP_VERIFY_SPM_VERSION:-}"
            if [[ -n "$version" ]]; then
                package_url="https://raw.githubusercontent.com/${repo_owner}/${repo_name}/${version}/Package.swift"
                vr_log::info "SPM" "[SPM] Retrying with version tag: $package_url"
                if curl -sSfL "$package_url" -o "$remote_package_file" 2>/dev/null; then
                    vr_log::info "SPM" "[SPM] Successfully downloaded Package.swift using version tag"
                else
                    vr_log::warn "SPM" "[SPM] Failed to download Package.swift (all attempts failed)"
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    else
        vr_log::info "SPM" "[SPM] Successfully downloaded Package.swift"
    fi
    
    # Parse package name using Python (more reliable than sed/awk for Swift syntax)
    vr_log::info "SPM" "[SPM] Parsing package name and product name..."
    
    local package_name
    local product_name
    
    # Extract package name: name: "package-name"
    # Use temporary Python script to avoid heredoc issues
    local parse_script="$sandbox/tmp/parse_package.py"
    cat > "$parse_script" <<'PYTHON_SCRIPT'
import re
import sys

if len(sys.argv) < 2:
    sys.exit(1)

remote_file = sys.argv[1]
try:
    with open(remote_file, 'r') as f:
        content = f.read()
    
    # Find package name: name: "..." (handle whitespace and newlines)
    match = re.search(r'name:\s*"([^"]+)"', content, re.MULTILINE | re.DOTALL)
    if match:
        print(match.group(1))
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
PYTHON_SCRIPT
    
    package_name="$(python3 "$parse_script" "$remote_package_file" 2>/dev/null || echo "")"
    rm -f "$parse_script"
    
    if [[ -z "$package_name" ]]; then
        vr_log::warn "SPM" "[SPM] Failed to parse package name from remote Package.swift"
        return 1
    fi
    
    # Extract first product name: .library(name: "..."
    cat > "$parse_script" <<'PYTHON_SCRIPT'
import re
import sys

if len(sys.argv) < 2:
    sys.exit(1)

remote_file = sys.argv[1]
try:
    with open(remote_file, 'r') as f:
        content = f.read()
    
    # Find first .library(name: "..." (handle multi-line with re.DOTALL)
    match = re.search(r'\.library\([^)]*name:\s*"([^"]+)"', content, re.MULTILINE | re.DOTALL)
    if match:
        print(match.group(1))
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
PYTHON_SCRIPT
    
    product_name="$(python3 "$parse_script" "$remote_package_file" 2>/dev/null || echo "")"
    rm -f "$parse_script"
    
    if [[ -z "$product_name" ]]; then
        vr_log::warn "SPM" "[SPM] Failed to parse product name from remote Package.swift"
        return 1
    fi
    
    export REMOTE_PACKAGE_NAME="$package_name"
    export REMOTE_PRODUCT_NAME="$product_name"
    
    vr_log::info "SPM" "[SPM] Parsed package name: $package_name"
    vr_log::info "SPM" "[SPM] Parsed product name: $product_name"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_remote_package "$@"
fi
