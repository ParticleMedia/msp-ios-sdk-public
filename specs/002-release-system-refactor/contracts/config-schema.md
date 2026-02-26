# Contract: Configuration Schema

**Feature**: Release System Refactor
**Date**: 2026-02-03

## Overview

This document defines the YAML configuration schema for the release system.

## Schema Definition

### Root Structure

```yaml
# Required
schema_version: integer  # Schema version (currently 2)

# Release metadata
version: string          # Semantic version (optional in config, required at runtime)
release_branch: string   # Auto-generated if empty
base_branch: string      # Default: "main"

# Profile system
default_profile: string  # Default profile name
profiles: object         # Profile definitions

# Module configuration
pods: object             # CocoaPods configuration
spm: object              # SPM configuration

# Verification
verify: object           # Verification settings
```

### Profile Schema

```yaml
profiles:
  <profile_name>:
    # NOTE: mode (simple/full) is controlled by --full flag, NOT in profile
    dry_run: boolean       # Preview without publishing

    # Validation settings
    validation:
      preflight: string    # "none" | "basic" | "full"

    # Notification settings
    # NOTE: CI and Local use same settings (no difference)
    notifications:
      slack:
        enabled: boolean
        env: string        # "prod" (same for all)
      email:
        enabled: boolean
        recipients: array  # List of email addresses

    # Logging settings
    # NOTE: Both CI and Local use "pretty" format
    logging:
      level: string        # "debug" | "info" | "warn" | "error"
      format: string       # "pretty"

    # Safety settings
    safety:
      allow_existing_tag: boolean
      allow_existing_release: boolean
      keep_sandbox: boolean
      require_ci: boolean  # If true, production requires CI environment

    # Performance settings
    performance:
      parallel_builds: boolean
      max_workers: integer
      cdn_wait_time: integer  # Seconds
```

**Key Design Decisions**:
- **mode is NOT in profile** - controlled by `--full` flag
- **CI and Local have no difference** - same logging format, same Slack channel
- **require_ci** - when `true`, production profile requires CI environment (TODO: enable when Jenkins ready)

### Pods Configuration Schema

```yaml
pods:
  enabled: boolean

  # Distribution method per module
  distribution:
    binary: array          # XCFramework-based modules
    source: array          # Source-based modules

  # Release order (dependencies first)
  modules: array           # Ordered list of module names

  # Remote verification
  remote_url: string       # Public repo URL
  remote_primary_product: string  # Main pod to test
```

### SPM Configuration Schema

```yaml
spm:
  enabled: boolean

  # Packages to release
  packages: array          # List of package names

  # Remote verification
  remote_url: string       # Public repo URL
  remote_product_name: string  # Main product to test
```

### Verify Configuration Schema

```yaml
verify:
  sandbox_dir: string      # Sandbox directory path
  cleanup_on_success: boolean

  # Verification types
  types:
    local: boolean
    remote_pods: boolean
    remote_spm: boolean
    sample_app: boolean
    device: boolean

  # Strictness
  spm_strict: boolean      # Fail on SPM verification failure

  # Timeouts (seconds)
  timeouts:
    local: integer
    remote_pods: integer
    remote_spm: integer
    sample_app: integer
    device: integer
```

## Value Constraints

### Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]

Valid: 1.0.0, 1.0.0-beta.1, 1.0.0-rc.2+build.123
Invalid: 1.0, v1.0.0, 1.0.0.0
```

### Profile Names

```
Pattern: ^[a-z][a-z0-9-]*$
Valid: local-dev, production, ci-test, quick-test
Invalid: LocalDev, PRODUCTION, 123-test
```

### Module Names

```
Valid: MSPCore, MSPSharedLibraries, MSPGoogleAdapter
Invalid: mspcore, MSP_Core, MSP Core
```

### Log Levels

| Value | Priority | Description |
|-------|----------|-------------|
| debug | 3 | Verbose debugging |
| info | 2 | Normal progress |
| warn | 1 | Non-blocking issues |
| error | 0 | Blocking errors |

## Default Values

```yaml
# Implicit defaults if not specified
schema_version: 2
base_branch: "main"
default_profile: "local-dev"

profiles:
  <any>:
    mode: "simple"
    dry_run: false
    validation:
      preflight: "basic"
      post_release: false
    notifications:
      slack:
        enabled: true
        env: "test"
      email:
        enabled: false
    logging:
      level: "info"
      format: "pretty"
    safety:
      allow_existing_tag: false
      allow_existing_release: false
      keep_sandbox: false
      require_confirmation: false
    performance:
      parallel_builds: true
      max_workers: 4
      cdn_wait_time: 60

verify:
  sandbox_dir: "/tmp/msp-verify-sandbox"
  cleanup_on_success: true
  types:
    local: true
    remote_pods: true
    remote_spm: true
    sample_app: true
    device: false
  spm_strict: true
  timeouts:
    local: 300
    remote_pods: 600
    remote_spm: 300
    sample_app: 600
    device: 900
```

## Environment Variable Override

Environment variables can override any config value:

| Environment Variable | Config Path |
|---------------------|-------------|
| `MSP_RELEASE_MODE` | `profiles.{profile}.mode` |
| `DRY_RUN` | `profiles.{profile}.dry_run` |
| `MSP_LOG_LEVEL` | `profiles.{profile}.logging.level` |
| `MSP_ALLOW_EXISTING_TAG` | `profiles.{profile}.safety.allow_existing_tag` |
| `MSP_ALLOW_EXISTING_RELEASE` | `profiles.{profile}.safety.allow_existing_release` |
| `MSP_PARALLEL_BUILDS` | `profiles.{profile}.performance.parallel_builds` |
| `MSP_MAX_WORKERS` | `profiles.{profile}.performance.max_workers` |
| `MSP_CDN_WAIT_TIME` | `profiles.{profile}.performance.cdn_wait_time` |
| `MSP_SANDBOX_DIR` | `verify.sandbox_dir` |
| `MSP_SLACK_ENV` | `profiles.{profile}.notifications.slack.env` |

## Override Priority

1. CLI flags (highest)
2. Environment variables
3. Config file values
4. Built-in defaults (lowest)

## Validation Rules

### Required Fields

- When running release: `version` must be specified (CLI or config)
- `pods.modules` must not be empty if `pods.enabled: true`
- `spm.packages` must not be empty if `spm.enabled: true`

### Cross-Field Validation

- If `mode: full`, then `validation.post_release` should be `true`
- If `dry_run: true`, then `safety.allow_existing_*` can be `true`
- `max_workers` should be between 1 and 16

### Module Order Validation

```yaml
# Dependencies must come before dependents
pods:
  modules:
    - MSPSharedLibraries  # No dependencies
    - MSPCore             # Depends on MSPSharedLibraries
    - MSPiOSCore          # Depends on MSPCore
    - MSPGoogleAdapter    # Depends on MSPCore, MSPiOSCore
```

## Example Configuration

### Minimal Configuration

```yaml
schema_version: 2
version: "1.0.0"
default_profile: local-dev
```

### Complete Configuration

See `Scripts/config/release.yaml` for full example with all options.

## Migration from v1

### Breaking Changes

- `options` section removed (use profiles)
- `notifications.slack_channel` moved to `notifications.slack.env`
- `verify.spm_strict` default changed from `false` to `true`

### Backward Compatibility

Old environment variables are still supported but deprecated:

| Old Variable | New Config Path |
|--------------|-----------------|
| `MSP_RELEASE_TIER` | Use `profiles.{profile}.dry_run` |
| `MSP_ALLOW_LOCAL_RELEASE` | Use `profiles.{profile}.dry_run` |
| `MSP_ALLOW_TRUNK_PUSH` | Use `profiles.{profile}.dry_run` |
| `MSP_SKIP_LOCAL_VALIDATION` | Use `profiles.{profile}.validation.local` (inverted) |
| `MSP_SKIP_REMOTE_VALIDATION` | Use `profiles.{profile}.validation.remote` (inverted) |
