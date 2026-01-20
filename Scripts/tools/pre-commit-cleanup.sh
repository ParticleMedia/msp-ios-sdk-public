#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# Pre-Commit Cleanup Script
# Removes report files and temporary artifacts before committing
# Reports are visible in working directory but never committed

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

echo "🧹 Pre-commit cleanup: Removing report files..."

# Remove report files from staging
git reset -- '*_Migration_Summary.md' 2>/dev/null || true
git reset -- '*_Project_Fix_Summary.md' 2>/dev/null || true
git reset -- '*_Validation_Checklist.md' 2>/dev/null || true
git reset -- '*_Migration_Report.md' 2>/dev/null || true
git reset -- '*_Fix_Report.md' 2>/dev/null || true
git reset -- '*.log' 2>/dev/null || true
git reset -- '*.tmp' 2>/dev/null || true

# Remove report directories from staging
git reset -- 'BuildReports/' 2>/dev/null || true
git reset -- 'MigrationReports/' 2>/dev/null || true
git reset -- 'Tmp/' 2>/dev/null || true

# Clean all generated validation & migration reports from MigrationReports/
if [ -d "MigrationReports" ]; then
    echo "[pre-commit] Cleaning MigrationReports..."
    
    # Remove all files except .gitkeep
    find MigrationReports -type f ! -name ".gitkeep" -delete 2>/dev/null || true
    
    # Remove empty directories
    find MigrationReports -type d -empty -delete 2>/dev/null || true
    
    # Ensure MigrationReports/ directory exists with .gitkeep
    if [ ! -d "MigrationReports" ]; then
        mkdir -p MigrationReports
    fi
    if [ ! -f "MigrationReports/.gitkeep" ]; then
        touch MigrationReports/.gitkeep
    fi
    
    echo "[pre-commit] ✅ MigrationReports/ cleaned (preserved .gitkeep)"
fi

echo "✅ Report files removed from staging area"
echo "✅ MigrationReports/ cleaned (files removed, directory preserved)"
echo "ℹ️  Report files are visible in working directory but will not be committed"
