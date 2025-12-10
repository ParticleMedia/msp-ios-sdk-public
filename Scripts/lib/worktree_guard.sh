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

  # Derive repo root; if unavailable, do nothing.
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$MSP_REPO_ROOT" ]; then
    return 0
  fi

  # Normalize paths and compare COMMON_DIR vs GIT_DIR to detect worktrees.
  MSP_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  MSP_GIT_DIR="$(git rev-parse --absolute-git-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null || true)"

  if [ -z "$MSP_COMMON_DIR" ] || [ -z "$MSP_GIT_DIR" ]; then
    return 0
  fi

  MSP_COMMON_ABS="$(cd "$MSP_REPO_ROOT" && cd "$(dirname "$MSP_COMMON_DIR")" && pwd)/$(basename "$MSP_COMMON_DIR")"
  MSP_GIT_ABS="$(cd "$MSP_REPO_ROOT" && cd "$(dirname "$MSP_GIT_DIR")" && pwd)/$(basename "$MSP_GIT_DIR")"

  if [ "$MSP_COMMON_ABS" != "$MSP_GIT_ABS" ]; then
    echo "[MSP][FATAL] This script must be run in the MAIN MSP repo, not in a Git worktree." >&2
    echo "[MSP][FATAL] COMMON_DIR=${MSP_COMMON_ABS}" >&2
    echo "[MSP][FATAL] GIT_DIR=${MSP_GIT_ABS}" >&2
    exit 1
  fi

  return 0
}
