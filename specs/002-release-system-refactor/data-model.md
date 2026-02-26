# Data Model: Release System

**Feature**: Release System Refactor
**Date**: 2026-02-03

## Overview

This document defines the data models for the refactored release system, including configuration schemas, state management, and interface contracts.

## Configuration Schema

### Consolidated release.yaml

The refactored system uses a single configuration file at `Scripts/config/release.yaml`.

```yaml
# ============================================================================
# MSP iOS SDK - Release Configuration (Consolidated)
# ============================================================================
# Version: 2.0
#
# This file combines profile-based configuration with module definitions.
# It is the Single Source of Truth (SSOT) for release configuration.
#
# Usage:
#   ./Scripts/msp-release.sh run 1.0.0
#   ./Scripts/msp-release.sh run --full 1.0.0
#   ./Scripts/msp-release.sh run --profile=production 1.0.0
# ============================================================================

# Schema version for migration support
schema_version: 2

# ============================================================================
# RELEASE METADATA
# ============================================================================

# Release version (set via CLI or here for CI)
version: ""

# Branch configuration
release_branch: ""          # Auto-generated as "release/{version}" if empty
base_branch: "main"

# ============================================================================
# PROFILE SYSTEM
# ============================================================================

# Default profile when no --profile specified
default_profile: local-dev

# Profile definitions
# NOTE: mode (simple/full) is controlled by --full flag, NOT by profile
# NOTE: CI and Local have NO difference - same logging format, same Slack channel
profiles:
  # ---------------------------------------------------------------------------
  # local-dev: Local development and testing (DEFAULT)
  # ---------------------------------------------------------------------------
  local-dev:
    dry_run: true             # Preview without publishing

    validation:
      preflight: basic        # basic or full

    notifications:
      slack:
        enabled: true
        env: prod             # Same as production
      email:
        enabled: false

    logging:
      level: info             # debug, info, warn, error
      format: pretty          # pretty (same for CI and local)

    safety:
      allow_existing_tag: true
      allow_existing_release: true
      keep_sandbox: true

    performance:
      parallel_builds: true
      max_workers: 4
      cdn_wait_time: 10

  # ---------------------------------------------------------------------------
  # quick-test: Minimal validation for quick testing
  # ---------------------------------------------------------------------------
  quick-test:
    dry_run: true

    validation:
      preflight: none         # Skip all validation

    notifications:
      slack:
        enabled: false
      email:
        enabled: false

    logging:
      level: warn
      format: pretty

    safety:
      allow_existing_tag: true
      allow_existing_release: true
      keep_sandbox: true

    performance:
      parallel_builds: true
      max_workers: 8
      cdn_wait_time: 5

  # ---------------------------------------------------------------------------
  # production: Real publishing (used by both CI and Local)
  # ---------------------------------------------------------------------------
  production:
    dry_run: false            # Real publishing

    validation:
      preflight: full

    notifications:
      slack:
        enabled: true
        env: prod
      email:
        enabled: true
        recipients:
          - msp-team@newsbreak.com

    logging:
      level: info
      format: pretty          # Same as local (not JSON)

    safety:
      allow_existing_tag: false
      allow_existing_release: false
      keep_sandbox: false
      require_ci: false       # TODO: Set to true when Jenkins ready

    performance:
      parallel_builds: true
      max_workers: 6
      cdn_wait_time: 120

# ============================================================================
# MODULE CONFIGURATION
# ============================================================================

# CocoaPods modules (in dependency order)
# NOTE: ALL modules use binary distribution (HTTP zip + vendored_frameworks)
pods:
  enabled: true

  # Release order (dependencies first)
  # Total: 11 modules, all binary distribution
  modules:
    # Core modules (foundation first)
    - MSPiOSCore
    - MSPSharedLibraries
    # Common modules
    - MSPGoogleAdsTypes
    # Adapters
    - MSPPrebidAdapter
    - MSPGoogleAdapter
    - MSPFacebookAdapter
    - MSPNovaAdapter
    - MSPAmazonAdapter
    - MSPMolocoAdapter
    - MSPLiftoffAdapter
    # MSPCore depends on MSPPrebidAdapter, so comes last
    - MSPCore

  # Remote verification
  remote_url: "https://github.com/ParticleMedia/msp-ios-sdk-public"
  remote_primary_product: "MSPCore"

# SPM packages
# NOTE: SPM packages should match CocoaPods modules (all binary)
# TODO: Confirm actual SPM package list during implementation
spm:
  enabled: true

  packages:
    # Should match pods modules (all binaryTarget)
    - MSPiOSCore
    - MSPSharedLibraries
    - MSPGoogleAdsTypes
    - MSPPrebidAdapter
    - MSPGoogleAdapter
    - MSPFacebookAdapter
    - MSPNovaAdapter
    - MSPAmazonAdapter
    - MSPMolocoAdapter
    - MSPLiftoffAdapter
    - MSPCore

  # Remote verification
  remote_url: "https://github.com/ParticleMedia/msp-ios-sdk-public"
  remote_product_name: "MSPAds"

# ============================================================================
# VERIFICATION CONFIGURATION
# ============================================================================

verify:
  # Sandbox directory for isolated verification
  sandbox_dir: "/tmp/msp-verify-sandbox"
  cleanup_on_success: true

  # Verification types (enabled in full mode)
  types:
    local: true               # Local simulator build
    remote_pods: true         # CocoaPods trunk verification
    remote_spm: true          # SPM package resolution
    sample_app: true          # Demo app build
    device: false             # Physical device test (optional)

  # Strictness
  spm_strict: true            # Fail on SPM verification failure

  # Timeouts (seconds)
  timeouts:
    local: 300
    remote_pods: 600
    remote_spm: 300
    sample_app: 600
    device: 900

# ============================================================================
# ENVIRONMENT VARIABLE MAPPING (for backward compatibility)
# ============================================================================
#
# These environment variables can override config values:
#
# | Environment Variable      | Config Path                     |
# |---------------------------|--------------------------------|
# | MSP_RELEASE_MODE          | profiles.{profile}.mode        |
# | DRY_RUN                   | profiles.{profile}.dry_run     |
# | MSP_LOG_LEVEL             | profiles.{profile}.logging.level |
# | MSP_ALLOW_EXISTING_TAG    | profiles.{profile}.safety.allow_existing_tag |
# | MSP_PARALLEL_BUILDS       | profiles.{profile}.performance.parallel_builds |
# | MSP_CDN_WAIT_TIME         | profiles.{profile}.performance.cdn_wait_time |
# | MSP_SANDBOX_DIR           | verify.sandbox_dir             |
# ============================================================================
```

## State Schema

### Release State File (.msp-release-state.json)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "MSP Release State",
  "description": "State tracking for release operations",
  "type": "object",
  "required": ["schema_version", "run_id", "version"],
  "properties": {
    "schema_version": {
      "type": "integer",
      "description": "State schema version for migration",
      "const": 2
    },
    "run_id": {
      "type": "string",
      "description": "Unique identifier for this release run",
      "pattern": "^[a-f0-9-]{36}$"
    },
    "mode": {
      "type": "string",
      "enum": ["run", "resume"],
      "description": "Operation mode"
    },
    "release_mode": {
      "type": "string",
      "enum": ["simple", "full"],
      "description": "Release mode (simple skips verification)"
    },
    "version": {
      "type": "string",
      "description": "Release version",
      "pattern": "^\\d+\\.\\d+\\.\\d+(-[a-zA-Z0-9.]+)?$"
    },
    "profile": {
      "type": "string",
      "description": "Configuration profile used"
    },
    "base_branch": {
      "type": "string",
      "description": "Source branch for release"
    },
    "release_branch": {
      "type": "string",
      "description": "Release branch name"
    },
    "dry_run": {
      "type": "boolean",
      "description": "Whether this is a dry run"
    },
    "phases": {
      "type": "object",
      "description": "Phase-level status tracking",
      "properties": {
        "preflight": { "$ref": "#/definitions/phase" },
        "branch": { "$ref": "#/definitions/phase" },
        "publish_pods": { "$ref": "#/definitions/phase" },
        "publish_spm": { "$ref": "#/definitions/phase" },
        "github_release": { "$ref": "#/definitions/phase" },
        "verify": { "$ref": "#/definitions/phase" },
        "notify": { "$ref": "#/definitions/phase" }
      }
    },
    "git": {
      "type": "object",
      "properties": {
        "tag_created": { "type": "boolean" },
        "tag_name": { "type": "string" },
        "tag_sha": { "type": "string" },
        "release_branch_created": { "type": "boolean" },
        "release_branch_pushed": { "type": "boolean" },
        "github_release_id": { "type": "string" },
        "github_release_created": { "type": "boolean" }
      }
    },
    "timestamps": {
      "type": "object",
      "properties": {
        "started_at": { "type": "string", "format": "date-time" },
        "updated_at": { "type": "string", "format": "date-time" },
        "completed_at": { "type": ["string", "null"], "format": "date-time" }
      }
    },
    "last_error": {
      "type": "object",
      "properties": {
        "phase": { "type": ["string", "null"] },
        "step": { "type": ["string", "null"] },
        "message": { "type": ["string", "null"] },
        "exit_code": { "type": ["integer", "null"] },
        "occurred_at": { "type": ["string", "null"], "format": "date-time" }
      }
    },
    "metrics": {
      "type": "object",
      "description": "Performance metrics",
      "properties": {
        "total_duration_seconds": { "type": "number" },
        "phase_durations": {
          "type": "object",
          "additionalProperties": { "type": "number" }
        },
        "pods_published": { "type": "integer" },
        "spm_published": { "type": "boolean" },
        "verification_results": {
          "type": "object",
          "additionalProperties": { "type": "boolean" }
        }
      }
    }
  },
  "definitions": {
    "phase": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "enum": ["pending", "in_progress", "success", "failed", "skipped"]
        },
        "started_at": { "type": "string", "format": "date-time" },
        "completed_at": { "type": ["string", "null"], "format": "date-time" },
        "steps": {
          "type": "object",
          "additionalProperties": { "$ref": "#/definitions/step" }
        }
      }
    },
    "step": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "enum": ["pending", "in_progress", "success", "failed", "skipped"]
        },
        "attempt": { "type": "integer", "minimum": 1 },
        "started_at": { "type": "string", "format": "date-time" },
        "completed_at": { "type": ["string", "null"], "format": "date-time" },
        "error": { "type": ["string", "null"] },
        "output": { "type": ["string", "null"] }
      }
    }
  }
}
```

### Example State File

```json
{
  "schema_version": 2,
  "run_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "mode": "run",
  "release_mode": "full",
  "version": "1.0.0",
  "profile": "production",
  "base_branch": "main",
  "release_branch": "release/1.0.0",
  "dry_run": false,

  "phases": {
    "preflight": {
      "status": "success",
      "started_at": "2026-02-03T10:00:00Z",
      "completed_at": "2026-02-03T10:02:00Z",
      "steps": {
        "static": { "status": "success", "attempt": 1 },
        "build": { "status": "success", "attempt": 1 }
      }
    },
    "branch": {
      "status": "success",
      "started_at": "2026-02-03T10:02:00Z",
      "completed_at": "2026-02-03T10:02:30Z",
      "steps": {
        "create": { "status": "success" },
        "push": { "status": "success" }
      }
    },
    "publish_pods": {
      "status": "in_progress",
      "started_at": "2026-02-03T10:02:30Z",
      "completed_at": null,
      "steps": {
        "MSPSharedLibraries": { "status": "success", "attempt": 1 },
        "MSPOMSDK": { "status": "success", "attempt": 1 },
        "MSPCore": { "status": "failed", "attempt": 2, "error": "trunk push timeout" },
        "MSPiOSCore": { "status": "pending" }
      }
    },
    "publish_spm": {
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
    }
  },

  "git": {
    "tag_created": true,
    "tag_name": "v1.0.0",
    "tag_sha": "abc123def456",
    "release_branch_created": true,
    "release_branch_pushed": true,
    "github_release_id": null,
    "github_release_created": false
  },

  "timestamps": {
    "started_at": "2026-02-03T10:00:00Z",
    "updated_at": "2026-02-03T10:15:30Z",
    "completed_at": null
  },

  "last_error": {
    "phase": "publish_pods",
    "step": "MSPCore",
    "message": "pod trunk push failed after 2 attempts",
    "exit_code": 1,
    "occurred_at": "2026-02-03T10:15:30Z"
  },

  "metrics": {
    "total_duration_seconds": 930,
    "phase_durations": {
      "preflight": 120,
      "branch": 30,
      "publish_pods": 780
    },
    "pods_published": 2,
    "spm_published": false
  }
}
```

## Log Entry Schema

### Structured Log Format

```json
{
  "timestamp": "2026-02-03T10:15:30.123Z",
  "level": "INFO",
  "phase": {
    "number": 2,
    "total": 4,
    "name": "publish_pods"
  },
  "step": {
    "number": 3,
    "total": 16,
    "name": "MSPCore"
  },
  "message": "Publishing MSPCore to CocoaPods trunk",
  "context": {
    "version": "1.0.0",
    "attempt": 1,
    "dry_run": false
  }
}
```

### Pretty Format Output

```
[Phase 2/4] [Step 03/16] [INFO] Publishing MSPCore to CocoaPods trunk
```

### Log Levels

| Level | Code | Description | When to Use |
|-------|------|-------------|-------------|
| ERROR | 0 | Blocking errors | Release cannot continue |
| WARN | 1 | Non-blocking issues | CDN timeouts, retries |
| INFO | 2 | Normal progress | Standard operations |
| DEBUG | 3 | Detailed info | Verbose mode only |

## Commit Message Schema

### Format

```
release(<scope>): <module>@<version>

[optional body]

[optional footer]
```

### Scopes

| Scope | Description |
|-------|-------------|
| pods | CocoaPods release commit |
| spm | SPM release commit |
| tag | Git tag creation |
| config | Configuration changes |
| verify | Verification-related changes |

### Examples

```
release(pods): MSPCore@1.0.0

release(pods): MSPGoogleAdapter@1.0.0 MSPFacebookAdapter@1.0.0

release(spm): Package.swift@1.0.0

release(tag): v1.0.0

Refs: #123
```

## Notification Payload Schema

### Slack Message (Block Kit)

```json
{
  "channel": "#msp-release",
  "text": "MSP iOS SDK v1.0.0 released successfully",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "MSP iOS SDK Release v1.0.0"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Status:*\n:white_check_mark: Success"
        },
        {
          "type": "mrkdwn",
          "text": "*Mode:*\nFull"
        },
        {
          "type": "mrkdwn",
          "text": "*Pods Published:*\n16"
        },
        {
          "type": "mrkdwn",
          "text": "*Duration:*\n45m 30s"
        }
      ]
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Verification Results:*\n- Local: :white_check_mark:\n- Remote Pods: :white_check_mark:\n- Remote SPM: :white_check_mark:"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": { "type": "plain_text", "text": "View Release" },
          "url": "https://github.com/ParticleMedia/msp-ios-sdk/releases/tag/v1.0.0"
        }
      ]
    }
  ]
}
```

## Data Migration

### State Schema v1 to v2

```bash
migrate_state_v1_to_v2() {
    local state_file="$1"

    # Read old state
    local old_state=$(cat "$state_file")

    # Transform to new structure
    jq '{
      schema_version: 2,
      run_id: .run_id,
      mode: .mode,
      release_mode: (if .mode == "run" then "simple" else "simple" end),
      version: .version,
      profile: "local-dev",
      base_branch: .base_branch,
      release_branch: .release_branch,
      dry_run: .dry_run,
      phases: {
        preflight: {
          status: (if .steps.preflight_static.status == "success" then "success" else "pending" end),
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
        }
      },
      git: .git,
      timestamps: .timestamps,
      last_error: .last_error
    }' <<< "$old_state" > "$state_file"
}
```
