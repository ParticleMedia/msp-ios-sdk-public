#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/unfreeze.sh (schema v2)
# ============================================================================
# Static-analysis tests for input validation, cherry-pick detection,
# branch retention (default), DELETE_BRANCH support, KEEP_BRANCH backwards
# compat, and state-file status update on retain path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$HELPERS_DIR/helpers.sh"

PASSED=0
FAILED=0
UNFREEZE_SCRIPT="$ROOT_DIR/Scripts/unfreeze.sh"

pass() { echo -e "${_GREEN:-}✓${_NC:-} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${_RED:-}✗${_NC:-} $1"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------

test_unfreeze_script_is_executable() {
    if [[ -x "$UNFREEZE_SCRIPT" ]]; then
        pass "unfreeze.sh is executable"
    else
        fail "unfreeze.sh should be executable"
    fi
}

test_unfreeze_script_parses_with_bash() {
    # Smoke test (see freeze_test.sh for rationale).
    if bash -n "$UNFREEZE_SCRIPT" 2>/dev/null; then
        pass "unfreeze.sh parses cleanly with bash -n"
    else
        fail "unfreeze.sh fails bash -n parse check"
    fi
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_unfreeze_requires_nb_version() {
    if grep -q 'NB_VERSION is required' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: exits with error when NB_VERSION is missing"
    else
        fail "unfreeze: should exit with error when NB_VERSION is missing"
    fi
}

test_unfreeze_constructs_branch_name() {
    if grep -q 'freeze/nb-' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: branch name uses freeze/nb-{NB_VERSION} pattern"
    else
        fail "unfreeze: branch name should follow freeze/nb-{NB_VERSION} pattern"
    fi
}

test_unfreeze_rejects_invalid_nb_version() {
    if grep -q 'NB_VERSION contains invalid characters' "$UNFREEZE_SCRIPT" &&
       grep -q 'git check-ref-format --branch' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: validates NB_VERSION with two-layer (project + git ref) check"
    else
        fail "unfreeze: should validate NB_VERSION (project regex + git check-ref-format)"
    fi
}

test_unfreeze_handles_corrupted_state_json() {
    # Defensive: malformed JSON on freeze branch must produce friendly error,
    # not a raw Python traceback, and must NOT leave user stranded on freeze branch.
    if grep -q 'is not valid JSON' "$UNFREEZE_SCRIPT" &&
       grep -q 'json.JSONDecodeError' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: handles corrupted state JSON with friendly error"
    else
        fail "unfreeze: should catch JSON parse errors and produce friendly message"
    fi
}

test_unfreeze_traps_to_restore_develop() {
    if grep -q 'restore_develop_on_abort\|trap.*EXIT' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: traps abort to restore develop"
    else
        fail "unfreeze: should trap abort to restore develop branch"
    fi
}

test_unfreeze_rejects_non_git_dir() {
    if grep -q 'not inside a git repository' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: gives friendly error when run outside a git repo"
    else
        fail "unfreeze: should give a clear error when invoked outside a git repo"
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

test_unfreeze_checks_clean_working_tree() {
    if grep -q 'git diff --quiet' "$UNFREEZE_SCRIPT" &&
       grep -q 'git diff --cached --quiet' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: checks both staged and unstaged changes"
    else
        fail "unfreeze: should check working tree cleanliness"
    fi
}

test_unfreeze_requires_on_develop() {
    # Symmetric with freeze: must start on develop. Otherwise DELETE_BRANCH=1
    # path can fail if user is on the freeze branch being deleted.
    if grep -q "'develop'" "$UNFREEZE_SCRIPT" &&
       grep -q 'abbrev-ref HEAD' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: validates current branch is develop"
    else
        fail "unfreeze: should validate current branch is develop in pre-flight"
    fi
}

test_unfreeze_verifies_remote_branch_exists() {
    if grep -q 'ls-remote --exit-code origin' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: verifies freeze branch exists on remote before proceeding"
    else
        fail "unfreeze: should verify freeze branch exists on remote"
    fi
}

test_unfreeze_fetches_before_cherry_check() {
    if grep -q 'git fetch origin' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: fetches from remote before cherry-pick check"
    else
        fail "unfreeze: should git fetch origin before running git cherry"
    fi
}

# ---------------------------------------------------------------------------
# Cherry-pick detection
# ---------------------------------------------------------------------------

test_unfreeze_uses_git_cherry() {
    # Accept either bash form (`git cherry origin/develop ...`) or Python
    # subprocess form (`["git", "cherry", "origin/develop", ...]`).
    if grep -qE '"git", "cherry", "origin/develop"|git cherry origin/develop' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: uses git cherry to detect un-cherry-picked commits"
    else
        fail "unfreeze: should use git cherry origin/develop origin/freeze-branch"
    fi
}

test_unfreeze_aborts_on_missing_cherry_picks() {
    if grep -q 'Cherry-pick these commits' "$UNFREEZE_SCRIPT" &&
       grep -q 'die ' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: aborts with guidance when cherry-picks are missing"
    else
        fail "unfreeze: should abort and list missing commits"
    fi
}

test_unfreeze_excludes_metadata_only_commits_from_cherry_check() {
    # The freeze-state and freeze-notice files live ONLY on the freeze branch
    # by design. Cherry-pick check must skip commits whose only changed files
    # are these metadata files; otherwise every clean unfreeze aborts (Blocker).
    if grep -q 'metadata_files' "$UNFREEZE_SCRIPT" &&
       grep -q '\.msp-freeze-state\.json' "$UNFREEZE_SCRIPT" &&
       grep -q '\.msp-freeze-notice\.md' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: cherry-pick check excludes metadata-only commits"
    else
        fail "unfreeze: cherry-pick check must skip metadata-only freeze commits"
    fi
}

test_unfreeze_recovery_uses_pr_not_direct_push() {
    # develop is branch-protected; cherry-pick recovery must NOT instruct
    # users to git push origin develop directly.
    if grep -q 'gh pr create' "$UNFREEZE_SCRIPT" &&
       ! grep -qE '^\s*git push\s+origin\s+develop\s*$' "$UNFREEZE_SCRIPT" &&
       ! grep -qE 'git push origin develop[[:space:]]*\\n' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: cherry-pick recovery uses PR flow (no direct push to develop)"
    else
        fail "unfreeze: recovery instructions must use PR flow, not direct push to develop"
    fi
}

# ---------------------------------------------------------------------------
# Branch retention vs deletion (new convention: default = retain)
# ---------------------------------------------------------------------------

test_unfreeze_supports_delete_branch_param() {
    if grep -q 'DELETE_BRANCH=1' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: supports DELETE_BRANCH=1 to explicitly delete the branch"
    else
        fail "unfreeze: should support DELETE_BRANCH=1 parameter"
    fi
}

test_unfreeze_default_retains_branch() {
    # Default DELETE_BRANCH=0 must mean "retain branch"; deletion path is gated by DELETE_BRANCH==1.
    if grep -q 'DELETE_BRANCH=0' "$UNFREEZE_SCRIPT" &&
       grep -q 'Retaining.*for future' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: default behavior retains the freeze branch"
    else
        fail "unfreeze: default should retain the freeze branch"
    fi
}

test_unfreeze_keep_branch_backwards_compat() {
    if grep -q 'KEEP_BRANCH=0' "$UNFREEZE_SCRIPT" &&
       grep -q 'KEEP_BRANCH=1' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: keeps backwards compat with KEEP_BRANCH=0/1"
    else
        fail "unfreeze: should accept legacy KEEP_BRANCH=0/1 args"
    fi
}

test_unfreeze_deletes_remote_when_requested() {
    if grep -q 'git push origin --delete' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: deletes remote freeze branch when DELETE_BRANCH=1"
    else
        fail "unfreeze: should delete remote freeze branch via git push origin --delete"
    fi
}

test_unfreeze_deletes_local_when_requested() {
    if grep -q 'git branch -D' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: deletes local freeze branch when DELETE_BRANCH=1"
    else
        fail "unfreeze: should delete local freeze branch when DELETE_BRANCH=1"
    fi
}

# ---------------------------------------------------------------------------
# State update on retain path (status → closed)
# ---------------------------------------------------------------------------

test_unfreeze_updates_state_status_to_closed() {
    if grep -q '"closed"' "$UNFREEZE_SCRIPT" &&
       grep -q 'closed_at' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: updates state.status to 'closed' with closed_at timestamp"
    else
        fail "unfreeze: should update state.status to 'closed' on retain path"
    fi
}

test_unfreeze_close_is_idempotent() {
    # Re-running unfreeze on an already-closed cycle must NOT re-stamp
    # closed_at and must NOT create a second close commit. The Python block
    # has to gate the write on the existing status.
    if grep -q 'write_needed' "$UNFREEZE_SCRIPT" &&
       grep -q 'state.get("status") != "closed"' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: close path is idempotent (no re-stamp on already-closed state)"
    else
        fail "unfreeze: close should be idempotent — guard write on status != closed"
    fi
}

test_unfreeze_commits_state_update_to_freeze_branch() {
    if grep -q 'git commit -m "chore(freeze): close' "$UNFREEZE_SCRIPT" &&
       grep -q 'git push origin' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: commits closed-state update and pushes to freeze branch"
    else
        fail "unfreeze: should commit + push state.status=closed update"
    fi
}

test_unfreeze_handles_missing_legacy_state_file() {
    if grep -q 'legacy freeze\|legacy local state' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: tolerates legacy freeze branches without state file"
    else
        fail "unfreeze: should tolerate legacy freeze branches with no state JSON"
    fi
}

test_unfreeze_recovers_from_failed_push() {
    # Idempotency: if a previous unfreeze committed status=closed locally
    # but the push failed, re-running must push (not blindly --ff-only pull).
    if grep -q 'previous failed push\|local_sha != "$remote_sha"\|recovering from previous' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: recovers from previous failed push (local-ahead branch)"
    else
        fail "unfreeze: should detect local-ahead branch and push instead of --ff-only pull"
    fi
}

test_unfreeze_local_ahead_push_gated_on_metadata_only() {
    # Recovery push must verify that all local-ahead commits are freeze
    # metadata only — otherwise un-pushed bugfix commits would silently
    # bypass the cherry-pick check.
    if grep -q 'NON_META_AHEAD' "$UNFREEZE_SCRIPT" &&
       grep -q 'bypass the cherry-pick check' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: local-ahead recovery push is gated on metadata-only"
    else
        fail "unfreeze: must abort if local-ahead commits include non-metadata changes"
    fi
}

# ---------------------------------------------------------------------------
# Cleanup of stale local state file (legacy v1)
# ---------------------------------------------------------------------------

test_unfreeze_cleans_legacy_local_state_file() {
    if grep -q 'rm.*STATE_FILENAME\|rm.*msp-freeze-state' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: removes any legacy local .msp-freeze-state.json from develop"
    else
        fail "unfreeze: should clean up legacy local state file"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running unfreeze.sh tests..."
echo "============================================"

test_unfreeze_script_is_executable
test_unfreeze_script_parses_with_bash
test_unfreeze_requires_nb_version
test_unfreeze_constructs_branch_name
test_unfreeze_rejects_invalid_nb_version
test_unfreeze_handles_corrupted_state_json
test_unfreeze_traps_to_restore_develop
test_unfreeze_rejects_non_git_dir
test_unfreeze_checks_clean_working_tree
test_unfreeze_requires_on_develop
test_unfreeze_verifies_remote_branch_exists
test_unfreeze_fetches_before_cherry_check
test_unfreeze_uses_git_cherry
test_unfreeze_aborts_on_missing_cherry_picks
test_unfreeze_excludes_metadata_only_commits_from_cherry_check
test_unfreeze_recovery_uses_pr_not_direct_push
test_unfreeze_supports_delete_branch_param
test_unfreeze_default_retains_branch
test_unfreeze_keep_branch_backwards_compat
test_unfreeze_deletes_remote_when_requested
test_unfreeze_deletes_local_when_requested
test_unfreeze_updates_state_status_to_closed
test_unfreeze_close_is_idempotent
test_unfreeze_commits_state_update_to_freeze_branch
test_unfreeze_handles_missing_legacy_state_file
test_unfreeze_recovers_from_failed_push
test_unfreeze_local_ahead_push_gated_on_metadata_only
test_unfreeze_cleans_legacy_local_state_file

echo "============================================"
echo "Unfreeze tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
