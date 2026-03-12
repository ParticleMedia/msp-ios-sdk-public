---
name: scripts-failure-analyst
description: Diagnose CI/CD failures, release script errors, and shell script issues
category: analysis
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Read, Glob, Bash]
applies-to: Scripts/
quick_reference: "When: CI/CD or release script fails. Steps: Check .msp-release-state.json → Parse failure → Propose script-based fix (per Article I.4)."
---

# Scripts Failure Analyst Skill

> **Type**: Analysis Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Root cause analysis for automation script failures

---

## Purpose

Diagnose failures in:
- CI/CD pipelines
- Release automation scripts
- Shell script execution errors
- Build system issues

**Constitutional Compliance**: Enforces **Article I.4** - all fixes must be script-based, no manual workarounds.

---

## Scope

**Does**:
- Analyze release state files (`.msp-release-state.json`)
- Parse CI/CD logs and error messages
- Inspect shell scripts for bugs
- Propose script-based fixes

**Does NOT**:
- Analyze Swift business logic (use `sources-bug-analyst.skill.md`)
- Debug runtime crashes (use `sources-bug-analyst.skill.md`)
- Make architectural decisions (escalate to Claude Code + Opus)

---

## When to Use

- CI/CD job fails
- Release script aborts
- `msp-release.sh` encounters errors
- Shell script exits with non-zero code
- State file corruption suspected

---

## Required Inputs

1. **State File**: `.msp-release-state.json` (if exists)
2. **Logs**: CI output, terminal output, or log files
3. **Script Name**: Which script failed (e.g., `msp-release.sh`)
4. **Context**: What operation was being attempted

---

## Execution Steps

### Step 1: State File Analysis

If `.msp-release-state.json` exists:

```bash
# Read state file
cat .msp-release-state.json | python3 -m json.tool

# Or if jq is available
cat .msp-release-state.json | jq '.'
```

**Extract**:
- `current_tier`: preflight | production
- `current_phase`: Which phase failed
- `completed_steps`: What succeeded before failure
- `failed_step`: Exact step that failed

**Common Issues**:
- Empty state file → First step failed
- Partial state → Mid-process failure, may need cleanup
- Stale state → Previous run didn't clean up

---

### Step 2: Log Analysis

Examine logs for key indicators:

#### Exit Codes
```
Exit code 1: General error
Exit code 127: Command not found
Exit code 130: Script terminated by Ctrl+C
Exit code 137: Killed (OOM or SIGKILL)
```

#### Error Patterns
| Pattern | Likely Cause |
|---------|--------------|
| `permission denied` | File permissions or sudo required |
| `command not found` | Missing dependency or PATH issue |
| `No such file or directory` | Hardcoded path or missing file |
| `connection refused` | Network/API unavailable |
| `authentication failed` | Credentials expired or missing |
| `timeout` | Operation took too long |

---

### Step 3: Script Inspection

Read the failing script:

```bash
# Find the script
ls Scripts/**/*.sh | grep <script-name>

# Read it
cat Scripts/<failing-script>.sh
```

**Check for**:
- ❌ Missing `set -euo pipefail` at top
- ❌ Unhandled error conditions
- ❌ Hardcoded paths (use variables instead)
- ❌ Race conditions in parallel operations
- ❌ Missing retry logic for network operations
- ❌ Inadequate error messages

---

### Step 4: Root Cause Classification

| Category | Examples | Typical Fix |
|----------|----------|-------------|
| **Config** | Missing env vars, wrong paths | Add config validation step |
| **Environment** | Missing tools, permissions | Add dependency checks |
| **Logic** | Script bug, unhandled edge case | Fix script logic |
| **State** | Corrupted state, partial run | Add state validation/cleanup |
| **External** | API failure, network timeout | Add retry logic |

---

### Step 5: Propose Script-Based Fix

Per **Article I.4**, the fix must:
- ✅ Modify the script permanently
- ✅ Handle the failure case automatically
- ✅ Add validation or retry logic
- ❌ NOT require manual intervention

**Good Fix** (Article I.4 compliant):
```diff
# Add retry logic to script
+ retry_count=3
+ for i in $(seq 1 $retry_count); do
+   if curl -f "$URL"; then
+     break
+   fi
+   log_warning "Attempt $i failed, retrying..."
+   sleep 5
+ done
```

**Bad Fix** (violates Article I.4):
```
❌ Manual workaround: "Run this curl command manually, then re-run the script"
```

---

## Output Format

```markdown
## Scripts Failure Analysis Report

---
analysis_date: 2026-01-14
script: Scripts/msp-release.sh
phase: Production
exit_code: 1
tier: 2
---

### Failure Summary
- **Script**: `Scripts/msp-release.sh`
- **Phase**: MSPNovaAdapter podspec generation
- **Exit Code**: 1
- **Timestamp**: 2026-01-14 12:03:35

### Root Cause
MSPNovaAdapter-1.0.0-rc.23.zip file missing from GitHub Release. The zip was never uploaded during the build phase, causing SHA256 checksum calculation to timeout after 78 seconds.

### Evidence

**State File** (`.msp-release-state.json`):
```json
{
  "current_phase": "cocoapods",
  "failed_step": "generate_podspec_MSPNovaAdapter"
}
```

**Log Analysis**:
- Line 2317: `INFO: Calculating SHA256 checksum for MSPNovaAdapter-1.0.0-rc.23.zip...`
- Line 2335 (78s later): `ERROR: Failed to generate release podspec for MSPNovaAdapter`
- No file found at `Binary/MSPNovaAdapter-1.0.0-rc.23.zip`

**GitHub Release Check**:
```bash
$ gh release view 1.0.0-rc.23 --json assets
# MSPNovaAdapter zip NOT in asset list
```

### Root Cause Category
**Environment** - Missing artifact (zip file was not created/uploaded)

### Proposed Fix

**Primary Fix**: Ensure zip creation step succeeds before podspec generation

**File**: `Scripts/release/publish/pods/publish.sh`

**Changes**:
1. Add pre-flight check for zip existence:
```diff
+ # Pre-flight: Verify zip exists
+ if [[ ! -f "$zip_path" ]]; then
+   log_error "Zip file not found: $zip_path"
+   log_error "Cannot generate podspec without zip"
+   return 1
+ fi
```

2. Add better error handling in `create_zip_from_xcframework`:
```diff
  create_zip_from_xcframework() {
+   local pod="$1"
+   local version="$2"
+
+   # Verify XCFramework exists first
+   if [[ ! -d "Build/XCFrameworks/${pod}.xcframework" ]]; then
+     log_error "XCFramework not found for $pod"
+     return 1
+   fi
+
    # ... rest of function
  }
```

### Prevention
- Add zip file existence check before podspec generation
- Improve error messages to distinguish between "zip doesn't exist" vs "checksum failed"
- Consider adding resume validation that checks all zips exist

### Verification
```bash
# After fix, verify:
./Scripts/release/publish/pods/publish.sh --dry-run
# Should fail early with clear message if zip missing
```

### Constitutional Compliance
- ✅ **Article I.4**: Script-based fix (no manual workaround)
- ✅ **Scripts/Article VI**: Added error handling and validation
```

---

## Common Failure Scenarios

### Scenario 1: Missing Dependency
**Symptom**: `command not found: jq`
**Fix**: Add dependency check at script start:
```bash
command -v jq >/dev/null || { echo "jq required"; exit 1; }
```

### Scenario 2: Permission Denied
**Symptom**: `permission denied: ./script.sh`
**Fix**: Ensure script has execute permission in repo:
```bash
git ls-files --stage Scripts/script.sh
# Should show 100755, not 100644
```

### Scenario 3: State File Corruption
**Symptom**: `jq: parse error`
**Fix**: Add state file validation:
```bash
if [[ -f .msp-release-state.json ]]; then
  python3 -m json.tool .msp-release-state.json >/dev/null || {
    log_error "Corrupted state file"
    mv .msp-release-state.json .msp-release-state.json.bak
  }
fi
```

---

## Tips for Effective Diagnosis

1. **Start with the Error**: Read the error message carefully
2. **Check State File**: Shows exact failure point
3. **Read Logs Backward**: Start from error, work backward to find trigger
4. **Test Locally**: Reproduce if possible
5. **Add Logging**: If diagnosis unclear, add debug logging to script

---

## Related Skills

- `sources-bug-analyst.skill.md`: For Swift/source code failures
- `constitutional-auditor.skill.md`: To verify fix complies with constitution
