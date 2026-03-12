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

check_line_count ".claude/CLAUDE.md" 70 "CLAUDE.md"
check_line_count ".codex/CODEX.md" 80 "CODEX.md"
check_line_count ".cursor/CURSOR.md" 80 "CURSOR.md"
check_line_count "AGENTS.md" 100 "AGENTS.md"
check_line_count "Sources/AGENTS-SOURCES.md" 25 "AGENTS-SOURCES.md"
check_line_count "Scripts/AGENTS-SCRIPTS.md" 40 "AGENTS-SCRIPTS.md"

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

# --- Check 5: Auto-generated sections are up to date ---
echo ""
echo "5. Checking auto-generated sections (staleness)..."

SYNC_SCRIPT="$PROJECT_ROOT/Scripts/tools/sync-agent-rules.py"
if [[ -f "$SYNC_SCRIPT" ]]; then
    sync_output=$(python3 "$SYNC_SCRIPT" --dry-run 2>&1)
    stale_count=$(echo "$sync_output" | grep -c "WOULD UPDATE" || true)
    if [[ "$stale_count" -eq 0 ]]; then
        echo "   ✓ All generated sections are up to date"
    else
        echo "   ✗ $stale_count file(s) have stale generated sections"
        echo "$sync_output" | grep "WOULD UPDATE" | sed 's/^/     /'
        echo "   → Fix: python3 Scripts/tools/generate-context-index.py && python3 Scripts/tools/sync-agent-rules.py"
        errors=$((errors + 1))
    fi
else
    echo "   ⚠ sync-agent-rules.py not found, skipping"
fi

# --- Check 6: Skills mirror consistency ---
echo ""
echo "6. Checking skills mirror (.agents-shared/skills/ ↔ .claude/skills/)..."

SHARED_SKILLS="$PROJECT_ROOT/.agents-shared/skills"
CLAUDE_SKILLS="$PROJECT_ROOT/.claude/skills"

if [[ -d "$SHARED_SKILLS" ]] && [[ -d "$CLAUDE_SKILLS" ]]; then
    shared_list=$(cd "$SHARED_SKILLS" && ls *.skill.md 2>/dev/null | sort)
    claude_list=$(cd "$CLAUDE_SKILLS" && ls *.skill.md 2>/dev/null | sort)

    if [[ "$shared_list" == "$claude_list" ]]; then
        shared_count=$(echo "$shared_list" | wc -l | tr -d ' ')
        echo "   ✓ Both directories have $shared_count identical skill files"

        # Check content matches
        content_mismatch=0
        for skill in $shared_list; do
            if ! diff -q "$SHARED_SKILLS/$skill" "$CLAUDE_SKILLS/$skill" > /dev/null 2>&1; then
                echo "   ✗ Content mismatch: $skill"
                content_mismatch=$((content_mismatch + 1))
            fi
        done
        if [[ $content_mismatch -gt 0 ]]; then
            echo "   → Fix: Copy the newer version to the other directory"
            errors=$((errors + 1))
        fi
    else
        echo "   ✗ File lists differ:"
        diff <(echo "$shared_list") <(echo "$claude_list") | sed 's/^/     /' || true
        errors=$((errors + 1))
    fi
else
    echo "   ⚠ One or both skills directories missing, skipping"
fi

# --- Check 7: All sync targets have required markers ---
echo ""
echo "7. Checking generated section markers across all agents..."

check_markers() {
    local file="$1"
    local label="$2"
    shift 2
    local markers=("$@")

    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        echo "   ✗ $label: FILE NOT FOUND ($file)"
        errors=$((errors + 1))
        return
    fi

    local all_present=true
    for marker in "${markers[@]}"; do
        if ! grep -q "BEGIN:GENERATED:$marker" "$PROJECT_ROOT/$file"; then
            echo "   ✗ $label: missing <!-- BEGIN:GENERATED:$marker --> marker"
            all_present=false
            errors=$((errors + 1))
        fi
        if ! grep -q "END:GENERATED:$marker" "$PROJECT_ROOT/$file"; then
            echo "   ✗ $label: missing <!-- END:GENERATED:$marker --> marker"
            all_present=false
            errors=$((errors + 1))
        fi
    done

    if [[ "$all_present" == true ]]; then
        echo "   ✓ $label: all ${#markers[@]} marker pair(s) present"
    fi
}

check_markers ".cursor/rules/context-system.mdc" "Cursor context-system" "CONTEXT_INVENTORY"
check_markers ".cursor/rules/skills-sync.mdc" "Cursor skills-sync" "SKILLS_LIST"
check_markers ".codex/instructions.md" "Codex instructions" "CONTEXT_INVENTORY" "SKILLS_LIST"
check_markers ".claude/rules/context-system.md" "Claude context-system" "CONTEXT_INVENTORY"
check_markers ".claude/rules/skills-sync.md" "Claude skills-sync" "SKILLS_LIST"

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
