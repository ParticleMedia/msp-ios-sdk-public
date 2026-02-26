#!/usr/bin/env bash
set -euo pipefail

# Script: validate-agent-sync.sh
# Purpose: Validate multi-agent consistency across Claude/Codex/Cursor configs
# Usage: ./Scripts/tools/validate-agent-sync.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PROJECT_ROOT

errors=0

echo "============================================================"
echo "VALIDATE: Multi-Agent Sync Check"
echo "============================================================"

# --- Check 1: Agent entry points under line limits ---
echo ""
echo "1. Checking agent entry point line counts..."

check_line_count() {
    local file="$1"
    local max="$2"
    local label="$3"

    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        echo "   ✗ $label: FILE NOT FOUND ($file)"
        errors=$((errors + 1))
        return
    fi

    local count
    count=$(wc -l < "$PROJECT_ROOT/$file")
    if [[ $count -le $max ]]; then
        echo "   ✓ $label: $count lines (≤ $max)"
    else
        echo "   ✗ $label: $count lines (exceeds $max)"
        errors=$((errors + 1))
    fi
}

check_line_count ".claude/CLAUDE.md" 60 "CLAUDE.md"
check_line_count ".codex/CODEX.md" 60 "CODEX.md"
check_line_count ".cursor/CURSOR.md" 60 "CURSOR.md"
check_line_count "AGENTS.md" 70 "AGENTS.md"
check_line_count "Sources/AGENTS-SOURCES.md" 25 "AGENTS-SOURCES.md"
check_line_count "Scripts/AGENTS-SCRIPTS.md" 25 "AGENTS-SCRIPTS.md"

# --- Check 2: All agents reference .context/index.json ---
echo ""
echo "2. Checking .context/index.json references..."

check_index_ref() {
    local file="$1"
    local label="$2"

    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        echo "   ✗ $label: FILE NOT FOUND"
        errors=$((errors + 1))
        return
    fi

    if grep -q "index.json" "$PROJECT_ROOT/$file"; then
        echo "   ✓ $label references index.json"
    else
        echo "   ✗ $label does NOT reference index.json"
        errors=$((errors + 1))
    fi
}

check_index_ref ".claude/CLAUDE.md" "CLAUDE.md"
check_index_ref ".codex/CODEX.md" "CODEX.md"
check_index_ref ".cursor/CURSOR.md" "CURSOR.md"

# --- Check 3: Playbook IDs in loading guides exist in index.json ---
echo ""
echo "3. Checking playbook ID coverage in index.json..."

INDEX_FILE="$PROJECT_ROOT/.context/index.json"

if [[ ! -f "$INDEX_FILE" ]]; then
    echo "   ✗ .context/index.json not found"
    errors=$((errors + 1))
else
    for guide in "Sources/AGENTS-SOURCES.md" "Scripts/AGENTS-SCRIPTS.md"; do
        guide_path="$PROJECT_ROOT/$guide"
        if [[ ! -f "$guide_path" ]]; then
            continue
        fi

        # Extract playbook IDs (ctx-xxx-nnn pattern)
        ids=$(grep -oE 'ctx-[a-z]+-[0-9]+' "$guide_path" 2>/dev/null || true)
        if [[ -z "$ids" ]]; then
            echo "   ⚠ $guide: no playbook IDs found"
            continue
        fi

        # shellcheck disable=SC2086 -- intentional word-splitting: ids is a space-delimited token list
        for id in $ids; do
            if grep -q "\"$id\"" "$INDEX_FILE"; then
                echo "   ✓ $id (from $guide) found in index.json"
            else
                echo "   ✗ $id (from $guide) NOT found in index.json"
                errors=$((errors + 1))
            fi
        done
    done
fi

# --- Check 4: index.json is valid JSON ---
echo ""
echo "4. Checking index.json validity..."

if [[ -f "$INDEX_FILE" ]]; then
    if python3 -m json.tool "$INDEX_FILE" > /dev/null 2>&1; then
        entry_count=$(python3 -c "import json; d=json.load(open('$INDEX_FILE')); print(d.get('entry_count', 0))")
        echo "   ✓ Valid JSON with $entry_count entries"
    else
        echo "   ✗ Invalid JSON"
        errors=$((errors + 1))
    fi
else
    echo "   ✗ index.json not found"
    errors=$((errors + 1))
fi

# --- Summary ---
echo ""
echo "------------------------------------------------------------"
if [[ $errors -eq 0 ]]; then
    echo "VALIDATE: ✓ ALL CHECKS PASSED"
    exit 0
else
    echo "VALIDATE: ✗ FAILED ($errors error(s))"
    exit 1
fi
