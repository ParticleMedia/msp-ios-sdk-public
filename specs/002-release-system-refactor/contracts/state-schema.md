# Contract: State Schema

**Feature**: Release System Refactor
**Date**: 2026-02-03

## Overview

This document defines the JSON state file schema for tracking release progress.

## File Location

```
.msp-release-state.json
```

Located at the repository root. This file:
- Is created on release start
- Updated throughout the release
- Used for resume functionality
- Should be in `.gitignore`

## Schema Definition

### Root Object

```json
{
  "schema_version": 2,
  "run_id": "uuid",
  "mode": "run|resume",
  "release_mode": "simple|full",
  "version": "1.0.0",
  "profile": "production",
  "base_branch": "main",
  "release_branch": "release/1.0.0",
  "dry_run": false,
  "phases": {},
  "git": {},
  "timestamps": {},
  "last_error": {},
  "metrics": {}
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | integer | Yes | Schema version (2) |
| `run_id` | string | Yes | UUID for this run |
| `mode` | string | Yes | "run" or "resume" |
| `release_mode` | string | Yes | "simple" or "full" |
| `version` | string | Yes | Release version |
| `profile` | string | Yes | Profile used |
| `base_branch` | string | Yes | Source branch |
| `release_branch` | string | Yes | Target branch |
| `dry_run` | boolean | Yes | Dry run mode |
| `phases` | object | Yes | Phase tracking |
| `git` | object | Yes | Git state |
| `timestamps` | object | Yes | Timing info |
| `last_error` | object | No | Last error info |
| `metrics` | object | No | Performance data |

### Phases Object

```json
{
  "phases": {
    "preflight": {
      "status": "success",
      "started_at": "ISO8601",
      "completed_at": "ISO8601",
      "steps": {
        "static": { "status": "success", "attempt": 1 },
        "build": { "status": "success", "attempt": 1 }
      }
    },
    "branch": {
      "status": "success",
      "steps": {
        "create": { "status": "success" },
        "push": { "status": "success" }
      }
    },
    "publish_pods": {
      "status": "in_progress",
      "steps": {
        "MSPSharedLibraries": { "status": "success" },
        "MSPCore": { "status": "failed", "error": "..." }
      }
    },
    "publish_spm": {
      "status": "pending",
      "steps": {}
    },
    "github_release": {
      "status": "pending",
      "steps": {}
    },
    "verify": {
      "status": "pending",
      "steps": {
        "local": { "status": "pending" },
        "remote_pods": { "status": "pending" },
        "remote_spm": { "status": "pending" }
      }
    },
    "notify": {
      "status": "pending",
      "steps": {}
    }
  }
}
```

### Phase Status Values

| Status | Description | Can Resume From |
|--------|-------------|-----------------|
| `pending` | Not started | Yes |
| `in_progress` | Currently running | Yes (retry current step) |
| `success` | Completed successfully | Skip |
| `failed` | Failed with error | Yes (retry) |
| `skipped` | Intentionally skipped | Skip |

### Step Object

```json
{
  "status": "success|failed|pending|skipped|in_progress",
  "attempt": 1,
  "started_at": "2026-02-03T10:00:00Z",
  "completed_at": "2026-02-03T10:01:30Z",
  "error": null,
  "output": null
}
```

### Git Object

```json
{
  "git": {
    "tag_created": true,
    "tag_name": "v1.0.0",
    "tag_sha": "abc123def456789",
    "release_branch_created": true,
    "release_branch_pushed": true,
    "github_release_id": "123456789",
    "github_release_created": true,
    "github_release_url": "https://github.com/.../releases/tag/v1.0.0"
  }
}
```

### Timestamps Object

```json
{
  "timestamps": {
    "started_at": "2026-02-03T10:00:00Z",
    "updated_at": "2026-02-03T10:15:30Z",
    "completed_at": null
  }
}
```

### Last Error Object

```json
{
  "last_error": {
    "phase": "publish_pods",
    "step": "MSPCore",
    "message": "pod trunk push failed: timeout after 300s",
    "exit_code": 1,
    "occurred_at": "2026-02-03T10:15:30Z",
    "stack_trace": null,
    "recoverable": true
  }
}
```

### Metrics Object

```json
{
  "metrics": {
    "total_duration_seconds": 930,
    "phase_durations": {
      "preflight": 120,
      "branch": 30,
      "publish_pods": 780
    },
    "pods_published": 5,
    "pods_failed": 1,
    "spm_published": false,
    "verification_results": {
      "local": true,
      "remote_pods": true,
      "remote_spm": false
    },
    "retry_count": 2
  }
}
```

## State Transitions

### Phase Lifecycle

```
pending → in_progress → success
                     → failed
                     → skipped (if conditions not met)
```

### Step Lifecycle

```
(not exist) → pending → in_progress → success
                                    → failed (can retry)
                                    → skipped
```

### Resume Logic

```
1. Load state file
2. For each phase:
   - If status == "success": skip
   - If status == "failed": retry from this phase
   - If status == "in_progress": retry current step
   - If status == "pending": execute
3. For each step within resumed phase:
   - If status == "success": skip
   - If status == "failed": retry
   - Otherwise: execute
```

## State File Operations

### Create State

Called at release start:

```bash
msp_state_init() {
    local version="$1"
    local mode="$2"  # simple or full

    cat > .msp-release-state.json <<EOF
{
  "schema_version": 2,
  "run_id": "$(uuidgen)",
  "mode": "run",
  "release_mode": "$mode",
  "version": "$version",
  ...
}
EOF
}
```

### Update Phase Status

```bash
msp_state_set_phase_status() {
    local phase="$1"
    local status="$2"

    jq ".phases.$phase.status = \"$status\"" \
       .msp-release-state.json > .tmp && mv .tmp .msp-release-state.json
}
```

### Update Step Status

```bash
msp_state_set_step_status() {
    local phase="$1"
    local step="$2"
    local status="$3"

    jq ".phases.$phase.steps.$step.status = \"$status\"" \
       .msp-release-state.json > .tmp && mv .tmp .msp-release-state.json
}
```

### Check If Should Skip

```bash
msp_state_should_skip_step() {
    local phase="$1"
    local step="$2"

    local status
    status=$(jq -r ".phases.$phase.steps.$step.status // \"pending\"" \
             .msp-release-state.json)

    [[ "$status" == "success" || "$status" == "skipped" ]]
}
```

### Record Error

```bash
msp_state_record_error() {
    local phase="$1"
    local step="$2"
    local message="$3"
    local exit_code="$4"

    jq ".last_error = {
      \"phase\": \"$phase\",
      \"step\": \"$step\",
      \"message\": \"$message\",
      \"exit_code\": $exit_code,
      \"occurred_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" .msp-release-state.json > .tmp && mv .tmp .msp-release-state.json
}
```

## Schema Migration

### v1 to v2 Migration

```bash
migrate_state_v1_to_v2() {
    local state_file=".msp-release-state.json"

    # Check current version
    local version
    version=$(jq -r '.schema_version // 1' "$state_file")

    if [[ "$version" == "1" ]]; then
        # Migrate steps to phases structure
        jq '{
          schema_version: 2,
          run_id: .run_id,
          mode: .mode,
          release_mode: "simple",
          version: .version,
          profile: "local-dev",
          base_branch: .base_branch,
          release_branch: .release_branch,
          dry_run: .dry_run,
          phases: {
            preflight: {
              status: (.steps.preflight_static.status // "pending"),
              steps: {
                static: .steps.preflight_static,
                build: .steps.preflight_build
              }
            },
            publish_pods: {
              status: "pending",
              steps: (
                .steps | to_entries |
                map(select(.key | startswith("pod_"))) |
                map({(.key | sub("pod_"; "")): .value}) |
                add // {}
              )
            },
            publish_spm: { status: "pending", steps: {} },
            verify: { status: "pending", steps: {} }
          },
          git: .git,
          timestamps: .timestamps,
          last_error: .last_error
        }' "$state_file" > "${state_file}.new"

        mv "${state_file}.new" "$state_file"
    fi
}
```

## Best Practices

### State File Hygiene

1. **Never manually edit** the state file
2. **Back up before resume** if debugging
3. **Delete to reset** if state is corrupted
4. **Keep in .gitignore** to avoid accidental commits

### Error Recovery

1. Check `last_error` for failure details
2. Fix underlying issue
3. Run `resume` to continue
4. State automatically updates on success

### Debugging

```bash
# View current state summary
jq '{
  version: .version,
  mode: .release_mode,
  phases: (.phases | to_entries | map({(.key): .value.status}) | add),
  last_error: .last_error.message
}' .msp-release-state.json

# View failed steps
jq '.phases | to_entries | map(
  {phase: .key, failed: (.value.steps | to_entries | map(select(.value.status == "failed")))}
) | map(select(.failed | length > 0))' .msp-release-state.json
```
