#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# Generate Xcode workspace from workspace.yml
# This script creates msp-ios-sdk.xcworkspace from the workspace.yml specification
# Usage: Scripts/tools/generate-workspace.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"
# shellcheck source=Scripts/lib/ui.sh
source "$ROOT_DIR/Scripts/lib/ui.sh"

init_paths

WORKSPACE_SPEC="$ROOT_DIR/workspace.yml"
WORKSPACE_PATH="$ROOT_DIR/msp-ios-sdk.xcworkspace"
WORKSPACE_DATA="$WORKSPACE_PATH/contents.xcworkspacedata"

if [[ ! -f "$WORKSPACE_SPEC" ]]; then
    log::error "TOOLS" "workspace.yml not found: $WORKSPACE_SPEC"
    log::info "TOOLS" "Run './Scripts/switch-target.sh [spm-release|pods-dev]' first"
    exit 1
fi

log_title "Generating Xcode Workspace"

# Parse workspace.yml to extract project paths
log::step "TOOLS" "Parsing workspace.yml"

# Extract project paths from workspace.yml
PROJECT_PATHS=()
while IFS= read -r line; do
    # Match lines like "path: MSPDemoApp/project.yml" or "path: Pods/Pods.xcodeproj"
    if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
        project_path="${BASH_REMATCH[1]}"
        PROJECT_PATHS+=("$project_path")
    fi
done < <(grep -E "^[[:space:]]*path:" "$WORKSPACE_SPEC" || true)

if [[ ${#PROJECT_PATHS[@]} -eq 0 ]]; then
    log::error "TOOLS" "No projects found in workspace.yml"
    exit 1
fi

log::info "TOOLS" "Found ${#PROJECT_PATHS[@]} project(s) in workspace.yml"

# Create workspace directory
mkdir -p "$WORKSPACE_PATH"

# Generate workspace contents
log::step "TOOLS" "Generating workspace contents"
{
    cat <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
XML
    
    for project_path in "${PROJECT_PATHS[@]}"; do
        # Convert path to group format (relative to workspace)
        if [[ "$project_path" == *.xcodeproj ]]; then
            # Direct .xcodeproj reference
            cat <<XML
   <FileRef
      location = "group:${project_path}">
   </FileRef>
XML
        elif [[ "$project_path" == *.yml ]]; then
            # YAML spec - need to generate project first, then reference it
            project_dir="$(dirname "$project_path")"
            project_name="$(basename "$project_dir")"
            xcodeproj_path="${project_dir}/${project_name}.xcodeproj"
            
            # Check if project exists, if not, it needs to be generated
            if [[ ! -d "$ROOT_DIR/$xcodeproj_path" ]]; then
                log::warn "TOOLS" "Project not found: $xcodeproj_path"
                log::info "TOOLS" "Run 'xcodegen generate --spec $project_path' first"
            fi
            
            cat <<XML
   <FileRef
      location = "group:${xcodeproj_path}">
   </FileRef>
XML
        fi
    done
    
    echo "</Workspace>"
} > "$WORKSPACE_DATA"

log::success "TOOLS" "Workspace generated: $WORKSPACE_PATH"
log::info "TOOLS" "Workspace contains ${#PROJECT_PATHS[@]} project(s)"

