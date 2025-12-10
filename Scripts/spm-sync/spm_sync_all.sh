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
set -euo pipefail

# Orchestrator:
# 1) pod install         (keep CocoaPods as source of truth for versions)
# 2) extract_from_pods   (build ThirdParty/*/*.xcframework from Pods)
# 3) generate_package_swift (rewrite Package.swift for local SPM dev)
# 4) Optionally: validate_xcframeworks + switch-target to SPM

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { echo "[$(basename "$0")] $*"; }
err() { echo "[$(basename "$0") ERROR] $*" >&2; }

main() {
  log "Step 1/3: Running pod install (CocoaPods is the single source of truth for versions)..."
  (cd "$ROOT_DIR" && pod install)

  log "Step 2/3: Extracting third-party SDK xcframeworks from Pods/ → ThirdParty/..."
  "$ROOT_DIR/Scripts/spm-sync/extract_from_pods.sh"

  log "Step 3/3: Generating local-development Package.swift..."
  "$ROOT_DIR/Scripts/spm-sync/generate_package_swift.sh"

  # Optional integration with your existing switch-target system
  if [[ -x "$ROOT_DIR/Scripts/target-switching/validate_xcframeworks.sh" ]]; then
    log "Running validate_xcframeworks.sh..."
    "$ROOT_DIR/Scripts/target-switching/validate_xcframeworks.sh" || err "validate_xcframeworks.sh reported problems."
  fi

  if [[ -x "$ROOT_DIR/Scripts/switch-target.sh" ]]; then
    log "You can now switch to SPM mode with:"
    echo "  $ROOT_DIR/Scripts/switch-target.sh spm-release"
  fi

  log "🎉 Pods → XCFramework → SPM sync complete."
}

main "$@"

