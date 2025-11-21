#!/bin/bash
# Pre-Commit Cleanup Script
# Removes report files and temporary artifacts before committing

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

echo "✅ Report files removed from staging area"
echo "ℹ️  Report files are still in working directory but will not be committed"
