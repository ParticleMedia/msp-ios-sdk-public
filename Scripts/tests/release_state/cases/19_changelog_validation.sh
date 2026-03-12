#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

set -euo pipefail

# Test Case 19: Validate changelog (release.md) parsing in safety check
#
# The safety check uses this sed pattern to extract content under ## Changes:
#   sed -n '/## Changes/,/^##/p' | tail -n +2 | sed '$d' | grep -v '^[[:space:]]*$'
#
# Key constraint: The pattern requires a SECOND ## heading as end marker.
# Without it, sed matches only the '## Changes' line itself (it's both
# start and end of the range), tail -n +2 removes it, and the result is empty.

PASS=0
FAIL=0

assert_changes_detected() {
    local desc="$1"
    local content="$2"
    local tmpfile
    tmpfile=$(mktemp)
    echo "$content" > "$tmpfile"

    local changes_content
    changes_content=$(sed -n '/## Changes/,/^##/p' "$tmpfile" | tail -n +2 | sed '$d' | grep -v '^[[:space:]]*$' | head -1)

    if [[ -n "$changes_content" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (got empty)" >&2
        FAIL=$((FAIL + 1))
    fi
    rm -f "$tmpfile"
}

assert_changes_empty() {
    local desc="$1"
    local content="$2"
    local tmpfile
    tmpfile=$(mktemp)
    echo "$content" > "$tmpfile"

    local changes_content
    changes_content=$(sed -n '/## Changes/,/^##/p' "$tmpfile" | tail -n +2 | sed '$d' | grep -v '^[[:space:]]*$' | head -1 || true)

    if [[ -z "$changes_content" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected empty, got: $changes_content)" >&2
        FAIL=$((FAIL + 1))
    fi
    rm -f "$tmpfile"
}

echo "Test: Changelog (release.md) validation parsing"
echo ""

# --- Cases that SHOULD be detected as having content ---

assert_changes_detected "Two ## headings with content between" \
"# Release 1.0.0

## Changes

- Fixed a bug

## End"

assert_changes_detected "Multiple changes with end marker" \
"# Release 1.0.0

## Changes

- Fixed a bug
- Added a feature

## Notes

Some notes"

assert_changes_detected "Content directly after heading with end marker" \
"## Changes
Content here
## End"

# --- Cases that FAIL (no content detected) ---

assert_changes_empty "Only one ## heading, no end marker" \
"# Release 1.0.0

## Changes

- Fixed a bug"

assert_changes_empty "## Changes with no content and no end marker" \
"# Release 1.0.0

## Changes"

assert_changes_empty "## Changes with only whitespace and no end marker" \
"# Release 1.0.0

## Changes


"

assert_changes_empty "Empty file" ""

assert_changes_empty "No ## Changes heading" \
"# Release 1.0.0

Some content"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All changelog validation tests passed."
