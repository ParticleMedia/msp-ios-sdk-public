#!/usr/bin/env bash

# ============================================================================
# MSP Worktree Safety Guard (Patch K) - Shared Library
# ============================================================================
# This library provides a reusable function to enforce that scripts are run
# in the main repository, not in a Git worktree.
#
# Usage:
#   . "$(git rev-parse --show-toplevel)/Scripts/lib/worktree_guard.sh"
#   msp_enforce_main_repo_or_exit
# ============================================================================

msp_enforce_main_repo_or_exit() {
  if ! command -v git >/dev/null 2>&1; then
    # If git is missing, do nothing (don't block).
    return 0
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Not inside a git work tree, nothing to enforce.
    return 0
  fi

  # Unset environment variables that might interfere with git detection
  unset GIT_DIR GIT_WORK_TREE

  # Get the repository root
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

  # Get the git directory relative to ROOT_DIR
  git_dir="$(git -C "$ROOT_DIR" rev-parse --git-dir 2>/dev/null || true)"

  if [[ -z "$git_dir" ]]; then
    echo "[MSP][FATAL] Not a git repository: $ROOT_DIR" >&2
    exit 1
  fi

  # Check if git_dir matches the worktree pattern (.git/worktrees/*)
  if [[ "$git_dir" == .git/worktrees/* ]]; then
    echo "[MSP][FATAL] This script must be run in the MAIN MSP repo, not in a Git worktree." >&2
    echo "[MSP][FATAL] git_dir=$git_dir" >&2
    exit 1
  fi

  return 0
}
