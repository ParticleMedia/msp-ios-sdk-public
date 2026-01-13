---
name: scripts-failure-analyst
description: A skill for diagnosing CI/CD failures, release script errors, and shell script issues. Analyzes state files and logs to find root causes in automation systems.
allowed-tools: Read, Glob, Bash
applies-to: Scripts/
---
# Scripts Failure Analyst Skill

## Purpose
Diagnose failures in CI/CD pipelines, release scripts, and shell automation. This skill enforces **Article I.4** of the Constitution: fixes must be script-based, not manual workarounds.

## Scope
- **Does**: Analyze release state files, CI logs, shell script failures
- **Does NOT**: Analyze Swift business logic or runtime crashes (use `sources-bug-analyst` for that)

## Inputs Required
1. `.msp-release-state.json` file (if available)
2. CI/CD log output or terminal errors
3. The failing script name or CI job

## Execution Steps

### Step 1: State File Analysis
If `.msp-release-state.json` exists:
```bash
cat .msp-release-state.json | jq '.'
```
Identify:
- Current release phase (`preflight`, `production`)
- Last successful step
- Exact failure point
- Partial state requiring cleanup

### Step 2: Log Analysis
Examine logs for:
- Exit codes (non-zero indicates failure)
- Error messages from shell commands
- Missing dependencies or permissions
- Environment variable issues
- Network/API failures

### Step 3: Script Inspection
Read the failing script under `Scripts/`:
```bash
cat Scripts/<failing-script>.sh
```
Look for:
- Missing `set -euo pipefail`
- Unhandled error conditions
- Hardcoded paths that may not exist
- Race conditions in parallel operations

### Step 4: Root Cause Classification
| Category | Examples |
|----------|----------|
| **Config** | Missing env vars, wrong paths |
| **Environment** | Missing tools, permissions |
| **Logic** | Script bug, unhandled edge case |
| **State** | Corrupted state file, partial run |
| **External** | API failure, network timeout |

### Step 5: Script-Based Fix
Per **Article I.4**, propose a fix that:
- Modifies the script permanently
- Handles the failure case automatically
- Does NOT require manual intervention

## Output Format
```
## Scripts Failure Analysis Report

### Failure Summary
- **Script**: `Scripts/msp-release.sh`
- **Phase**: Preflight
- **Exit Code**: 1

### Root Cause
[Explanation of why the script failed]

### Evidence
- State file shows: `current_step: "pod_publish"`
- Log shows: `error: authentication failed`
- Script line 234: Missing retry logic for API calls

### Proposed Fix
**File**: `Scripts/msp-release.sh`

```diff
- curl -X POST "$API_URL"
+ for i in {1..3}; do
+   curl -X POST "$API_URL" && break
+   sleep 5
+ done
```

### Prevention
This fix adds retry logic to handle transient API failures.
```

## Constitutional Compliance
- **Article I.4**: No manual workarounds
- **Scripts/constitution.md**: POSIX compliance, `set -euo pipefail`
