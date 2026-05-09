#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/freeze.sh (schema v2)
# ============================================================================
# Static-analysis tests for input validation, pre-flight guards, branch
# operations, state-file commit on freeze branch, RELEASE_DATE handling,
# Slack notice generation, and webhook posting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$HELPERS_DIR/helpers.sh"

PASSED=0
FAILED=0
FREEZE_SCRIPT="$ROOT_DIR/Scripts/freeze.sh"

pass() { echo -e "${_GREEN:-}✓${_NC:-} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${_RED:-}✗${_NC:-} $1"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------

test_freeze_script_is_executable() {
    if [[ -x "$FREEZE_SCRIPT" ]]; then
        pass "freeze.sh is executable"
    else
        fail "freeze.sh should be executable"
    fi
}

test_freeze_script_parses_with_bash() {
    # Smoke test: bash itself must be able to parse the script. shellcheck's
    # parser is more lenient and has missed real bash parse errors before
    # (e.g., apostrophes inside heredoc-in-cmd-substitution).
    if bash -n "$FREEZE_SCRIPT" 2>/dev/null; then
        pass "freeze.sh parses cleanly with bash -n"
    else
        fail "freeze.sh fails bash -n parse check"
    fi
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_freeze_requires_nb_version() {
    if grep -q 'NB_VERSION is required' "$FREEZE_SCRIPT"; then
        pass "freeze: exits with error when NB_VERSION is missing"
    else
        fail "freeze: should exit with error when NB_VERSION is missing"
    fi
}

test_freeze_accepts_release_date_arg() {
    if grep -q 'RELEASE_DATE=\*' "$FREEZE_SCRIPT"; then
        pass "freeze: accepts RELEASE_DATE=YYYY-MM-DD argument"
    else
        fail "freeze: should accept RELEASE_DATE argument"
    fi
}

test_freeze_constructs_branch_name() {
    if grep -q 'freeze/nb-' "$FREEZE_SCRIPT"; then
        pass "freeze: branch name uses freeze/nb-{NB_VERSION} pattern"
    else
        fail "freeze: branch name should follow freeze/nb-{NB_VERSION} pattern"
    fi
}

test_freeze_rejects_invalid_nb_version() {
    # Layer 1: project conventions (slashes, leading dots/dashes).
    if grep -q 'NB_VERSION contains invalid characters' "$FREEZE_SCRIPT" &&
       grep -F -q '[[:space:]/]' "$FREEZE_SCRIPT"; then
        pass "freeze: layer-1 rejects slashes/leading-dot/leading-dash in NB_VERSION"
    else
        fail "freeze: layer-1 should reject project-banned NB_VERSION patterns"
    fi
}

test_freeze_uses_git_check_ref_format() {
    # Layer 2: authoritative git validator catches `:`, `..`, trailing `.`,
    # `@{...}`, control chars that pass layer 1.
    if grep -q 'git check-ref-format --branch' "$FREEZE_SCRIPT" &&
       grep -q 'invalid git branch name' "$FREEZE_SCRIPT"; then
        pass "freeze: layer-2 uses git check-ref-format for authoritative validation"
    else
        fail "freeze: should use git check-ref-format --branch as authoritative NB_VERSION check"
    fi
}

test_freeze_rejects_non_git_dir() {
    if grep -q 'not inside a git repository' "$FREEZE_SCRIPT"; then
        pass "freeze: gives friendly error when run outside a git repo"
    else
        fail "freeze: should give a clear error when invoked outside a git repo"
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks (Article 1.4: no auto-fix)
# ---------------------------------------------------------------------------

test_freeze_checks_clean_working_tree() {
    if grep -q 'git diff --quiet' "$FREEZE_SCRIPT" &&
       grep -q 'git diff --cached --quiet' "$FREEZE_SCRIPT"; then
        pass "freeze: checks both staged and unstaged changes"
    else
        fail "freeze: should check working tree cleanliness (staged + unstaged)"
    fi
}

test_freeze_checks_develop_branch() {
    if grep -q '"develop"' "$FREEZE_SCRIPT" &&
       grep -q 'abbrev-ref HEAD' "$FREEZE_SCRIPT"; then
        pass "freeze: validates current branch is develop"
    else
        fail "freeze: should validate current branch is develop"
    fi
}

test_freeze_strict_develop_sync_check() {
    if grep -q 'git fetch origin develop' "$FREEZE_SCRIPT" &&
       grep -q 'rev-parse develop' "$FREEZE_SCRIPT" &&
       grep -q 'rev-parse origin/develop' "$FREEZE_SCRIPT"; then
        pass "freeze: enforces strict develop == origin/develop sync"
    else
        fail "freeze: should enforce develop == origin/develop sync via rev-parse + fetch"
    fi
}

test_freeze_diagnoses_behind_ahead_diverged() {
    if grep -q 'BEHIND origin/develop' "$FREEZE_SCRIPT" &&
       grep -q 'AHEAD of origin/develop' "$FREEZE_SCRIPT" &&
       grep -q 'DIVERGED' "$FREEZE_SCRIPT"; then
        pass "freeze: gives explicit guidance for behind/ahead/diverged states"
    else
        fail "freeze: should distinguish behind/ahead/diverged with explicit fix instructions"
    fi
}

test_freeze_does_not_auto_pull() {
    # Article 1.4: no auto-fix. Must NOT silently `git pull` when behind.
    if grep -q '^[[:space:]]*git pull origin develop[[:space:]]*$' "$FREEZE_SCRIPT"; then
        fail "freeze: should NOT auto-pull develop (Article 1.4 — pre-flight must fail explicitly)"
    else
        pass "freeze: does not auto-pull develop (Article 1.4 compliant)"
    fi
}

test_freeze_checks_branch_not_exists() {
    if grep -q 'show-ref --verify' "$FREEZE_SCRIPT" &&
       grep -q 'ls-remote' "$FREEZE_SCRIPT"; then
        pass "freeze: checks freeze branch does not already exist (local + remote)"
    else
        fail "freeze: should check freeze branch does not already exist"
    fi
}

# ---------------------------------------------------------------------------
# RELEASE_DATE handling
# ---------------------------------------------------------------------------

test_freeze_defaults_release_date_to_next_tuesday() {
    if grep -q 'next Tuesday' "$FREEZE_SCRIPT" &&
       grep -q 'weekday()' "$FREEZE_SCRIPT"; then
        pass "freeze: defaults RELEASE_DATE to next Tuesday when not provided"
    else
        fail "freeze: should default RELEASE_DATE to next Tuesday"
    fi
}

test_freeze_validates_release_date_format() {
    if grep -q 'YYYY-MM-DD\|%Y-%m-%d' "$FREEZE_SCRIPT" &&
       grep -q 'invalid_format\|invalid format' "$FREEZE_SCRIPT"; then
        pass "freeze: validates RELEASE_DATE is YYYY-MM-DD format"
    else
        fail "freeze: should validate RELEASE_DATE format"
    fi
}

test_freeze_rejects_past_release_date() {
    if grep -q 'past_date\|past date\|in the past' "$FREEZE_SCRIPT"; then
        pass "freeze: rejects RELEASE_DATE in the past"
    else
        fail "freeze: should reject RELEASE_DATE in the past"
    fi
}

# ---------------------------------------------------------------------------
# Branch creation and state file (now committed ON freeze branch, schema v2)
# ---------------------------------------------------------------------------

test_freeze_creates_branch() {
    if grep -q 'git checkout -b' "$FREEZE_SCRIPT"; then
        pass "freeze: creates freeze branch with git checkout -b"
    else
        fail "freeze: should create freeze branch with git checkout -b"
    fi
}

test_freeze_writes_state_v2_schema() {
    if grep -q '"schema_version": 2' "$FREEZE_SCRIPT" &&
       grep -q '"nb_version"' "$FREEZE_SCRIPT" &&
       grep -q '"freeze_branch"' "$FREEZE_SCRIPT" &&
       grep -q '"frozen_at"' "$FREEZE_SCRIPT" &&
       grep -q '"develop_sha_at_freeze"' "$FREEZE_SCRIPT" &&
       grep -q '"planned_release_date"' "$FREEZE_SCRIPT" &&
       grep -q '"status": "active"' "$FREEZE_SCRIPT"; then
        pass "freeze: writes state JSON v2 with all required fields"
    else
        fail "freeze: state JSON should include schema_version=2 and all v2 fields"
    fi
}

test_freeze_commits_state_on_freeze_branch() {
    # State file is gitignored on develop, so commit on freeze branch needs -f
    if grep -q 'git add -f.*STATE_FILENAME\|git add -f.*msp-freeze-state' "$FREEZE_SCRIPT" &&
       grep -q 'git commit -m "chore(freeze):' "$FREEZE_SCRIPT"; then
        pass "freeze: force-adds and commits state file on freeze branch"
    else
        fail "freeze: should force-add and commit .msp-freeze-state.json on freeze branch"
    fi
}

test_freeze_pushes_branch() {
    if grep -q 'git push -u origin' "$FREEZE_SCRIPT"; then
        pass "freeze: pushes branch to remote with -u flag"
    else
        fail "freeze: should push freeze branch to remote with git push -u origin"
    fi
}

test_freeze_returns_to_develop() {
    if grep -q 'git checkout develop' "$FREEZE_SCRIPT"; then
        pass "freeze: switches back to develop after creating freeze branch"
    else
        fail "freeze: should switch back to develop after creating freeze branch"
    fi
}

test_freeze_traps_to_restore_develop_on_abort() {
    # If the script aborts mid-flow (e.g., push fails), the user must not be
    # stranded on the freeze branch.
    if grep -q 'restore_develop_on_abort\|trap.*EXIT\|trap.*ERR' "$FREEZE_SCRIPT"; then
        pass "freeze: traps abort to restore develop"
    else
        fail "freeze: should trap abort and restore develop branch"
    fi
}

# ---------------------------------------------------------------------------
# Slack notice generation + posting
# ---------------------------------------------------------------------------

test_freeze_generates_slack_mrkdwn_notice() {
    if grep -q ':snowflake:' "$FREEZE_SCRIPT" &&
       grep -q '\*MSP iOS SDK — Code Freeze' "$FREEZE_SCRIPT" &&
       grep -q '\*Freeze branch:\*' "$FREEZE_SCRIPT" &&
       grep -q '\*Planned release:\*' "$FREEZE_SCRIPT"; then
        pass "freeze: generates Slack mrkdwn notice with required fields"
    else
        fail "freeze: should generate Slack mrkdwn notice template"
    fi
}

test_freeze_writes_notice_file() {
    if grep -q '\.msp-freeze-notice\.md\|NOTICE_FILENAME' "$FREEZE_SCRIPT"; then
        pass "freeze: writes notice file to .msp-freeze-notice.md (local archive)"
    else
        fail "freeze: should write notice mrkdwn to .msp-freeze-notice.md"
    fi
}

test_freeze_posts_to_slack_webhook_when_configured() {
    # Multiline-friendly: check the building blocks exist anywhere in the script.
    if grep -q 'MSP_FREEZE_SLACK_WEBHOOK_URL' "$FREEZE_SCRIPT" &&
       grep -q 'curl' "$FREEZE_SCRIPT" &&
       grep -q -- '-X POST' "$FREEZE_SCRIPT" &&
       grep -q 'application/json' "$FREEZE_SCRIPT"; then
        pass "freeze: posts to Slack via webhook when MSP_FREEZE_SLACK_WEBHOOK_URL is set"
    else
        fail "freeze: should POST to MSP_FREEZE_SLACK_WEBHOOK_URL when configured"
    fi
}

test_freeze_uses_http_status_for_slack_success_detection() {
    # Reliable detection: separate body from HTTP status code (avoids false
    # negatives from curl stderr noise on the success path).
    if grep -q "%{http_code}" "$FREEZE_SCRIPT"; then
        pass "freeze: uses HTTP status code for Slack success detection"
    else
        fail "freeze: should use curl -w '%{http_code}' for reliable Slack status check"
    fi
}

test_freeze_falls_back_when_webhook_missing() {
    if grep -q 'MSP_FREEZE_SLACK_WEBHOOK_URL not set\|skipped Slack post' "$FREEZE_SCRIPT"; then
        pass "freeze: falls back to local notice file when webhook not configured"
    else
        fail "freeze: should fall back to local notice file when webhook missing"
    fi
}

test_freeze_supports_user_id_mention() {
    if grep -q 'MSP_SLACK_USER_ID' "$FREEZE_SCRIPT" &&
       grep -q '<@' "$FREEZE_SCRIPT"; then
        pass "freeze: uses Slack <@USER_ID> mention when MSP_SLACK_USER_ID is set"
    else
        fail "freeze: should use Slack mention syntax when MSP_SLACK_USER_ID is set"
    fi
}

test_freeze_loads_slack_conf() {
    if grep -q 'Scripts/config/slack.conf\|SLACK_CONF' "$FREEZE_SCRIPT"; then
        pass "freeze: sources Scripts/config/slack.conf for Slack settings"
    else
        fail "freeze: should source Scripts/config/slack.conf"
    fi
}

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------

test_freeze_prints_summary_block() {
    if grep -q 'SDK Code Freeze' "$FREEZE_SCRIPT" &&
       grep -q 'Release branch' "$FREEZE_SCRIPT" &&
       grep -q 'Planned release' "$FREEZE_SCRIPT"; then
        pass "freeze: prints summary block at the end"
    else
        fail "freeze: should print summary block"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running freeze.sh tests..."
echo "============================================"

test_freeze_script_is_executable
test_freeze_script_parses_with_bash
test_freeze_requires_nb_version
test_freeze_accepts_release_date_arg
test_freeze_constructs_branch_name
test_freeze_rejects_invalid_nb_version
test_freeze_uses_git_check_ref_format
test_freeze_rejects_non_git_dir
test_freeze_checks_clean_working_tree
test_freeze_checks_develop_branch
test_freeze_strict_develop_sync_check
test_freeze_diagnoses_behind_ahead_diverged
test_freeze_does_not_auto_pull
test_freeze_checks_branch_not_exists
test_freeze_defaults_release_date_to_next_tuesday
test_freeze_validates_release_date_format
test_freeze_rejects_past_release_date
test_freeze_creates_branch
test_freeze_writes_state_v2_schema
test_freeze_commits_state_on_freeze_branch
test_freeze_pushes_branch
test_freeze_returns_to_develop
test_freeze_traps_to_restore_develop_on_abort
test_freeze_generates_slack_mrkdwn_notice
test_freeze_writes_notice_file
test_freeze_posts_to_slack_webhook_when_configured
test_freeze_uses_http_status_for_slack_success_detection
test_freeze_falls_back_when_webhook_missing
test_freeze_supports_user_id_mention
test_freeze_loads_slack_conf
test_freeze_prints_summary_block

echo "============================================"
echo "Freeze tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
