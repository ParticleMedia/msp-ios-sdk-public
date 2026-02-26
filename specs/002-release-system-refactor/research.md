# Research: Release System Architecture Analysis

**Feature**: Release System Refactor
**Date**: 2026-02-03
**Status**: Complete

## Executive Summary

The MSP iOS SDK release system is a sophisticated, multi-layer automation framework with 2,100+ line CLI managing 11 subcommands, 12 specialized utilities, and a 4-tier verification system. Key issues identified include monolithic entry point, inconsistent logging, broken verification, and excessive environment variables.

## Current Architecture

### Directory Structure Overview

```
Scripts/
├── msp-release.sh                      # Main entry point (2,100+ lines)
├── config/
│   └── release.yaml                    # Profile-based configuration
├── lib/                                # 26 shared library files
│   ├── release-common.sh               # Core utilities (600 lines)
│   ├── colors.sh                       # Terminal colors
│   ├── ui.sh                           # Output formatting
│   ├── logging.sh                      # Logging functions (460 lines)
│   ├── cocoapods.sh                    # CocoaPods utilities (1,030 lines)
│   ├── config_loader.sh                # Profile loading (400 lines)
│   └── validation.sh                   # Input validation (560 lines)
└── release/
    ├── config/release.yaml.template    # Config template (300 lines)
    ├── utils/                          # 12 utility files
    │   ├── config.sh                   # Config management (477 lines)
    │   ├── state.sh                    # State machine (611 lines)
    │   ├── notify.sh                   # Notifications (789 lines)
    │   ├── podspec.sh                  # Podspec tools (728 lines)
    │   └── logger.sh                   # Structured logging (459 lines)
    ├── orchestrator/modular.sh         # Release orchestrator
    ├── preflight/preflight.sh          # Pre-release validation
    ├── publish/
    │   ├── pods/publish.sh             # CocoaPods publisher (5,700+ lines)
    │   └── spm/publish.sh              # SPM publisher
    └── verify/                         # Verification system (broken)
        ├── verify.sh
        ├── verify_local/
        ├── verify_local_device/
        └── verify_remote/
```

### CLI Commands (11 total)

| Command | Purpose | Status |
|---------|---------|--------|
| help | Show CLI help | Working |
| version | Show version info | Working |
| config | Print effective configuration | Working |
| preflight | Validate environment | Working |
| run | Execute full release | Working |
| pods | CocoaPods release only | Working |
| spm | SPM release only | Working |
| verify | Post-release verification | Broken |
| verify-matrix | Full verification matrix | Broken |
| rollback | Rollback failed release | Working |
| resume | Resume failed release | Working |

### Release Pipeline (4 Phases)

```
Phase 1: Preflight
├── Static checks (git, version, branch)
└── Build checks (XCFramework, round-trip test)

Phase 2: Branch Management
├── Create release branch
└── Push to remote

Phase 3: Publishing
├── CocoaPods (series, dependency order)
│   ├── Generate podspecs
│   └── Publish each pod
└── SPM (series)
    ├── Generate Package.swift
    └── Tag and push

Phase 4: Post-Release
├── Create GitHub Release
├── Upload assets
├── Verification (broken)
└── Notifications
```

## Configuration System Analysis

### Two Configuration Files

1. **Scripts/config/release.yaml** - Profile-based configuration
   - Defines profiles: local-dev, ci-test, production, quick-test
   - Maps 30+ environment variables to config keys
   - 200+ lines

2. **Scripts/release/config/release.yaml.template** - Module configuration
   - Defines pod and SPM module lists with order
   - Defines dependencies and release order
   - 300 lines

### Environment Variable Mapping (Documented)

| Old Variable | New Config Key |
|--------------|----------------|
| DRY_RUN | dry_run |
| MSP_PODS_ENABLED | validation.pods |
| MSP_SPM_ENABLED | validation.spm |
| MSP_LOG_LEVEL | logging.level |
| MSP_ALLOW_EXISTING_TAG | safety.allow_existing_tag |
| MSP_PARALLEL_BUILDS | performance.parallel_builds |
| MSP_CDN_WAIT_TIME | performance.cdn_wait_time |

### Profile System

```yaml
profiles:
  local-dev:
    dry_run: true
    validation:
      pods: true
      spm: false
      remote: false
    notifications:
      slack: {enabled: true, env: test}

  production:
    dry_run: false
    validation:
      pods: true
      spm: true
      remote: true
    notifications:
      slack: {enabled: true, env: prod}
```

## Test Infrastructure Analysis

### Existing Framework

Location: `Scripts/tests/release_state/`

**Components**:
- `run_all.sh` - Test runner with sandbox isolation
- `helpers.sh` - Assertion utilities
- `mock/` - Mock external tools (curl, gh, git, pod, swift, xcodebuild)
- `cases/` - 12 existing test cases

**Assertion Functions Available**:
- `assert_equals(expected, actual, message)`
- `assert_file_exists(path, message)`
- `assert_contains(haystack, needle, message)`
- `assert_state_step_status(repo_root, step, expected)`
- `mock_log_contains(pattern, message)`

**Test Case Coverage**:
1. State creation on run
2. Resume skips successful steps
3. Resume retries failed steps
4. State reset between versions
5. Rollback plan generation
6. Rollback force execution
7. Partial rollback failure handling
8-12. Slack notification scenarios

### Test Execution Model

```bash
# Each test runs in isolated sandbox
tmpdir=$(mktemp -d)
cd "$tmpdir"

# Copy Scripts/ to sandbox
cp -R "${repo_root}/Scripts"/* "$tmpdir/Scripts/"

# Set up mock PATH
export PATH="${mock_dir}:${PATH}"

# Source and run test case
source "${case_script}"
```

## Logging System Analysis

### Current Issues

1. **Multiple Systems**
   - `lib/logging.sh` - General logging
   - `release/utils/logger.sh` - Structured release logging
   - Ad-hoc `echo` statements throughout

2. **Inconsistent Formatting**
   - Some use `[Phase X]`, others use `Phase X:`
   - Step numbers not always padded
   - No standard for context inclusion

3. **Wrong Log Levels**
   - Pod availability timeout logged as ERROR
   - Should be WARN (CDN delay is expected)

### Current Log Output Examples

```
# Inconsistent formats found:
[Phase 1] Running preflight...
Phase 2/4: Publishing pods
[Step 3] MSPCore
[ERROR] Pod availability check timed out  # Should be WARN
```

### Proposed Unified Format

```
[Phase X/Y] [Step NN/MM] [LEVEL] Message
[Phase 1/4] [Step 01/05] [INFO] Running static preflight checks
[Phase 2/4] [Step 03/12] [WARN] Pod availability timeout (CDN delay)
```

## State Management Analysis

### Current State Schema

```json
{
  "schema_version": 1,
  "run_id": "uuid",
  "mode": "run",
  "version": "1.0.0",
  "steps": {
    "run": {"status": "success", "attempt": 1},
    "preflight_static": {"status": "success"},
    "pod_MSPCore": {"status": "failed", "error": "..."}
  },
  "git": {
    "tag_created": true,
    "tag_name": "v1.0.0"
  }
}
```

### State Tracking Functions (17 total)

- `msp_state_init` - Initialize state file
- `msp_state_set_step_status` - Update step status
- `msp_state_get_step_status` - Query step status
- `msp_state_should_skip_step` - Check if step already complete
- `msp_state_record_error` - Record error information
- `msp_state_get_last_error` - Retrieve last error

## Verification System Analysis

### Current State: Non-Functional

The verification system exists but cannot run successfully. Issues:

1. **Local Verification**
   - Runs in main repo directory
   - Modifies working state
   - No sandbox isolation

2. **Remote Verification**
   - CocoaPods check fails with spec repo issues
   - SPM check has Package.swift parsing errors
   - No retry logic for CDN delays

3. **Device Testing**
   - Requires manual iPhone connection
   - No simulator fallback
   - Archive/export flow incomplete

### Verification Types Needed

| Type | Current Status | Required Changes |
|------|----------------|------------------|
| Local | Partially works | Add sandbox isolation |
| Remote CocoaPods | Fails | Rewrite with proper spec repo handling |
| Remote SPM | Fails | Fix Package.swift generation |
| Sample App | Not tested | Create automated build flow |
| Device | Manual only | Add optional flag, simulator support |

## CocoaPods Publishing Analysis

### Pod Update Frequency Issue

Found redundant `update_specs_repo` calls in `publish/pods/publish.sh`:
- Line 5127: Before availability check
- Line 5408: After waiting for availability
- Line 5681: Before next pod publish

### Current TTL Mechanism

```bash
# In lib/cocoapods.sh
update_specs_repo() {
    local cache_file=".msp-specs-repo-last-update"
    local ttl_seconds=300  # 5 minutes

    if [[ -f "$cache_file" ]]; then
        local last_update=$(cat "$cache_file")
        local now=$(date +%s)
        if (( now - last_update < ttl_seconds )); then
            return 0  # Skip update
        fi
    fi

    pod repo update
    date +%s > "$cache_file"
}
```

### Optimization Opportunities

1. **Centralize update**: Single update at phase start
2. **Share availability state**: Track confirmed-available pods
3. **Remove redundant checks**: Don't re-check already-confirmed pods
4. **Parallel publishing**: Where dependencies allow

## Concurrency Analysis

### macOS flock Issue

```bash
# Current code
if command -v flock &>/dev/null; then
    flock -n "$lock_file" || return 1
else
    # Skip locking on macOS
    return 0
fi
```

### Platform-Agnostic Solution

```bash
# Proposed approach using mkdir (atomic on all platforms)
acquire_lock() {
    local lock_dir="$1"
    local max_attempts=30

    for ((i=0; i<max_attempts; i++)); do
        if mkdir "$lock_dir" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done
    return 1
}

release_lock() {
    local lock_dir="$1"
    rmdir "$lock_dir" 2>/dev/null
}
```

## Slack Notification Analysis

### Current Issues

1. **Silent failures**: Curl errors not captured
2. **Wrong payload format**: Block Kit JSON sometimes malformed
3. **No retry**: Single attempt only
4. **DM failures**: User ID lookup fails

### Test Cases Covering Slack

- `08_slack_notification_success.sh`
- `09_slack_test_mode_dm_override_required.sh`
- `10_slack_test_mode_webhook_required.sh`
- `11_slack_soft_failure.sh`
- `12_slack_prod_mode_uses_yaml.sh`

## Recommendations Summary

### High Priority

1. **Unify configuration**: Merge two YAML files into single source
2. **Rewrite verification**: Implement sandbox-based verification system
3. **Fix logging**: Single unified logging module with proper levels
4. **Add simple/full modes**: Implement release mode switching

### Medium Priority

1. **Extend test coverage**: Add unit tests for core functions
2. **Optimize pod updates**: Reduce redundant spec repo updates
3. **Fix concurrency**: Platform-agnostic locking mechanism
4. **Fix Slack**: Proper error handling and retry

### Low Priority

1. **Clean legacy code**: Remove unused functions and comments
2. **Reduce env vars**: Document and consolidate to 15 essential
3. **Update documentation**: README and inline comments
4. **Performance benchmarking**: Measure simple vs full mode times
