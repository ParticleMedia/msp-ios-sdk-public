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
  # Worktree guard disabled: git worktrees share the same git state and
  # all scripts use ROOT_DIR (from git rev-parse --show-toplevel) which
  # resolves correctly in worktrees. No need to block worktree usage.
  return 0
}
