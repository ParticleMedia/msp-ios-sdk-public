#!/bin/bash
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
# Path resolution utilities for MSP iOS SDK build system
# Provides standardized functions for determining script and repository paths

# Get the directory where the current script is located
get_script_dir() {
    local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    cd "$(dirname "$script_path")" && pwd
}

# Get the repository root directory
# Usage: ROOT_DIR=$(get_repo_root)
get_repo_root() {
    local script_dir
    script_dir=$(get_script_dir)
    
    # Navigate up from Scripts/ to repo root
    # Works for: Scripts/*, Scripts/*/*, Scripts/*/*/*
    if [[ "$script_dir" == *"/Scripts" ]]; then
        # Script is directly in Scripts/
        cd "$script_dir/.." && pwd
    elif [[ "$script_dir" == *"/Scripts/"* ]]; then
        # Script is in a subdirectory of Scripts/
        local depth
        depth=$(echo "$script_dir" | tr -cd '/' | wc -c)
        depth=$((depth - 1))  # Subtract 1 for Scripts/ itself
        local up_path=""
        for ((i=0; i<depth; i++)); do
            up_path="../$up_path"
        done
        cd "$script_dir/$up_path" && pwd
    else
        # Fallback: try to find repo root by looking for .git or Podfile
        local current="$script_dir"
        while [[ "$current" != "/" ]]; do
            if [[ -f "$current/.git/config" ]] || [[ -f "$current/Podfile" ]]; then
                echo "$current"
                return 0
            fi
            current="$(dirname "$current")"
        done
        # If not found, assume script is in Scripts/ and go up one level
        cd "$script_dir/.." && pwd
    fi
}

# Initialize standard path variables
# Usage: init_paths
# Sets: SCRIPT_DIR, ROOT_DIR
init_paths() {
    if [[ -z "${SCRIPT_DIR:-}" ]]; then
        export SCRIPT_DIR
        SCRIPT_DIR=$(get_script_dir)
    fi
    
    if [[ -z "${ROOT_DIR:-}" ]]; then
        export ROOT_DIR
        ROOT_DIR=$(get_repo_root)
    fi

    init_release_artifacts_paths
    ensure_release_artifacts_layout
}

# Initialize release artifacts path variables (canonical build outputs)
init_release_artifacts_paths() {
    if [[ -z "${RELEASE_ARTIFACTS_DIR:-}" ]]; then
        export RELEASE_ARTIFACTS_DIR="$ROOT_DIR/Build/ReleaseArtifacts"
    fi
    if [[ -z "${RELEASE_XCFRAMEWORKS_DIR:-}" ]]; then
        export RELEASE_XCFRAMEWORKS_DIR="$RELEASE_ARTIFACTS_DIR/XCFrameworks"
    fi
    if [[ -z "${RELEASE_ARCHIVES_DIR:-}" ]]; then
        export RELEASE_ARCHIVES_DIR="$RELEASE_ARTIFACTS_DIR/Archives"
    fi
    if [[ -z "${RELEASE_ZIPS_DIR:-}" ]]; then
        export RELEASE_ZIPS_DIR="$RELEASE_ARTIFACTS_DIR/Zips"
    fi
    if [[ -z "${RELEASE_BINARY_DIR:-}" ]]; then
        export RELEASE_BINARY_DIR="$RELEASE_ARTIFACTS_DIR/Binary"
    fi
    if [[ -z "${RELEASE_THIRDPARTY_DIR:-}" ]]; then
        export RELEASE_THIRDPARTY_DIR="$RELEASE_ARTIFACTS_DIR/ThirdParty"
    fi
}

# Ensure release artifacts directories exist
ensure_release_artifacts_layout() {
    init_release_artifacts_paths

    mkdir -p \
        "$RELEASE_XCFRAMEWORKS_DIR" \
        "$RELEASE_ARCHIVES_DIR" \
        "$RELEASE_ZIPS_DIR" \
        "$RELEASE_BINARY_DIR" \
        "$RELEASE_THIRDPARTY_DIR"
}
# Validate that we're in the MSP iOS SDK repository
# Usage: validate_repo_root [ROOT_DIR]
# Returns: 0 if valid, 1 if invalid
validate_repo_root() {
    local root="${1:-${ROOT_DIR:-}}"
    
    if [[ -z "$root" ]]; then
        return 1
    fi
    
    # Check for repository markers
    if [[ -f "$root/.git/config" ]] || [[ -f "$root/Podfile" ]]; then
        return 0
    fi
    
    return 1
}
