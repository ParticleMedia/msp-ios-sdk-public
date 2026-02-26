# Quickstart Guide: Release System v2

**Feature**: Release System Refactor
**Date**: 2026-02-03

## Overview

This guide covers the new release system with Simple/Full modes, unified configuration, and improved verification.

## Installation

No installation required. The release system is part of the MSP iOS SDK repository.

## Basic Usage

### Simple Release (Default)

The simplest way to release is the simple mode, which skips post-release verification:

```bash
# Release version 1.0.0 in simple mode
./Scripts/msp-release.sh run 1.0.0
```

This will:
1. Run basic preflight checks
2. Create release branch
3. Build XCFrameworks
4. Publish to CocoaPods
5. Publish to SPM
6. Create GitHub Release
7. Send Slack notification

**Time**: ~30 minutes (30% faster than full mode)

### Full Release with Verification

For production releases, use full mode to run complete verification:

```bash
# Release with all verification
./Scripts/msp-release.sh run --full 1.0.0

# Or use production profile (same effect)
./Scripts/msp-release.sh run --profile=production 1.0.0
```

This adds:
- Complete preflight checks
- Local sandbox verification
- Remote CocoaPods verification
- Remote SPM verification
- Sample app build test
- Optional device testing

**Time**: ~45-60 minutes

## Release Modes

### Mode Comparison

| Feature | Simple Mode | Full Mode |
|---------|-------------|-----------|
| Basic preflight | Yes | Yes |
| Full preflight | No | Yes |
| XCFramework build | Yes | Yes |
| CocoaPods publish | Yes | Yes |
| SPM publish | Yes | Yes |
| Local verification | No | Yes (sandbox) |
| Remote verification | No | Yes |
| Device testing | No | Optional |

### When to Use Each Mode

- **Simple Mode**: Daily development, quick iterations, hotfixes
- **Full Mode**: Major releases, version bumps, production deployments

## CLI Reference

### Commands

```bash
# Full release (pods + SPM)
./Scripts/msp-release.sh run [--full] <VERSION>

# CocoaPods only
./Scripts/msp-release.sh pods <VERSION>

# SPM only
./Scripts/msp-release.sh spm <VERSION>

# Resume failed release
./Scripts/msp-release.sh resume [--full]

# Run verification only
./Scripts/msp-release.sh verify <VERSION>

# Show effective configuration
./Scripts/msp-release.sh env

# Show help
./Scripts/msp-release.sh help
```

### Common Options

```bash
--full              # Enable full mode (all verification)
--profile=NAME      # Use named profile (local-dev, production, ci-test)
--config=FILE       # Load custom config file
--dry-run           # Show what would happen without executing
--verbose           # Enable verbose output
--skip-pods         # Skip CocoaPods release
--skip-spm          # Skip SPM release
--version=VER       # Specify version (alternative to positional)
--release-notes=MSG # Specify release notes for GitHub
```

## Configuration

### View Current Configuration

```bash
# Show all effective settings
./Scripts/msp-release.sh env

# Output:
# MSP Release Configuration
# =========================
# Profile: local-dev
# Mode: simple
# Dry Run: true
# ...
```

### Configuration File

Edit `Scripts/config/release.yaml` to customize defaults:

```yaml
# Default profile
default_profile: local-dev

# Profile definitions
profiles:
  local-dev:
    mode: simple
    dry_run: true
    validation:
      preflight: basic
      post_release: false
    # ...

  production:
    mode: full
    dry_run: false
    validation:
      preflight: full
      post_release: true
    # ...
```

### Environment Variables

Override any config value with environment variables:

```bash
# Override log level
MSP_LOG_LEVEL=debug ./Scripts/msp-release.sh run 1.0.0

# Override CDN wait time
MSP_CDN_WAIT_TIME=300 ./Scripts/msp-release.sh run --full 1.0.0

# Force dry run
DRY_RUN=true ./Scripts/msp-release.sh run --profile=production 1.0.0
```

## Resume Mode

### Resume After Failure

If a release fails, resume from where it stopped:

```bash
# Resume in simple mode (default)
./Scripts/msp-release.sh resume

# Resume with full verification
./Scripts/msp-release.sh resume --full
```

Resume will:
1. Read state from `.msp-release-state.json`
2. Skip completed steps
3. Retry failed step
4. Continue with remaining steps

### View Release State

```bash
# Check current state
cat .msp-release-state.json | jq '.phases'

# See last error
cat .msp-release-state.json | jq '.last_error'
```

## Profiles

### Available Profiles

| Profile | Dry Run | Preflight | Use Case |
|---------|---------|-----------|----------|
| local-dev | true | basic | Local testing (default) |
| quick-test | true | none | Quick iteration |
| production | false | full | Real releases (CI or Local) |

**Note**:
- **mode (simple/full) is controlled by `--full` flag**, not by profile
- **CI and Local have no difference** - same logging format, same Slack channel
- When Jenkins is ready, `production` profile will require CI environment

### Using Profiles

```bash
# Use production profile (real release)
./Scripts/msp-release.sh run --profile=production 1.0.0

# Combine profile with --full for verification
./Scripts/msp-release.sh run --profile=production --full 1.0.0

# Local dev with full verification (dry run + verification)
./Scripts/msp-release.sh run --full 1.0.0
```

## Verification

### Local Verification (Sandbox)

Local verification runs in an isolated sandbox to avoid affecting the main repo:

```bash
# Sandbox location
/tmp/msp-verify-sandbox/

# Contents after verification
/tmp/msp-verify-sandbox/
├── pods-test/          # CocoaPods test project
├── spm-test/           # SPM test project
└── sample-app/         # Sample app build
```

### Remote Verification

Remote verification tests the published packages:

1. **CocoaPods**: Creates fresh project, runs `pod install` with new version
2. **SPM**: Creates Package.swift, resolves dependencies
3. **Sample App**: Builds DemoApp with new SDK

### Run Verification Only

```bash
# Run verification for an already-published version
./Scripts/msp-release.sh verify 1.0.0
```

## Logging

### Log Format

```
[Phase X/Y] [Step NN/MM] [LEVEL] Message
```

### Log Levels

| Level | When Shown | Description |
|-------|------------|-------------|
| ERROR | Always | Blocking errors |
| WARN | Always | Non-blocking issues (e.g., CDN delay) |
| INFO | Default | Normal progress |
| DEBUG | --verbose | Detailed debugging |

### Examples

```
[Phase 1/4] [Step 01/05] [INFO] Running static preflight checks
[Phase 2/4] [Step 03/16] [WARN] Pod availability timeout (retrying...)
[Phase 2/4] [Step 03/16] [ERROR] pod trunk push failed: MSPCore
```

### Verbose Mode

```bash
# Enable debug logging
./Scripts/msp-release.sh run --verbose 1.0.0
```

## Commit Messages

The system uses per-pod commits with standardized messages:

```
release(pods): MSPCore@1.0.0
release(pods): MSPGoogleAdapter@1.0.0
release(spm): Package.swift@1.0.0
release(tag): v1.0.0
```

## Common Workflows

### Standard Development Release

```bash
# 1. Ensure clean state
git status  # Should be clean

# 2. Run simple release
./Scripts/msp-release.sh run 1.0.0-dev.1

# 3. Check result
cat .msp-release-state.json | jq '.phases'
```

### Production Release

```bash
# 1. Verify environment
./Scripts/msp-release.sh preflight 1.0.0

# 2. Run full release
./Scripts/msp-release.sh run --full 1.0.0

# 3. Monitor progress
tail -f release.log  # If logging to file

# 4. Verify success
./Scripts/msp-release.sh verify 1.0.0
```

### Handle Failed Release

```bash
# 1. Check what failed
cat .msp-release-state.json | jq '.last_error'

# 2. Fix the issue (e.g., network, credentials)

# 3. Resume
./Scripts/msp-release.sh resume

# 4. If still failing, check verbose output
./Scripts/msp-release.sh resume --verbose
```

### Rollback (If Needed)

```bash
# View rollback plan
./Scripts/msp-release.sh rollback

# Execute rollback
./Scripts/msp-release.sh rollback --force
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Pod already published" | Version exists on trunk | Bump version or use `--allow-existing-tag` |
| "Preflight failed" | Missing dependencies | Run `pod install`, check Xcode |
| "CDN timeout" | CocoaPods CDN delay | Wait and retry, or increase `cdn_wait_time` |
| "Slack notification failed" | Webhook issue | Check webhook URL, non-blocking |

### Debug Mode

```bash
# Full debug output
MSP_LOG_LEVEL=debug ./Scripts/msp-release.sh run --verbose 1.0.0

# Dry run to see what would happen
./Scripts/msp-release.sh run --dry-run 1.0.0
```

### Reset State

```bash
# Remove state file to start fresh
rm .msp-release-state.json

# Or run new version (state resets automatically)
./Scripts/msp-release.sh run 1.0.1
```

## Integration with CI

### GitHub Actions

```yaml
- name: Release SDK
  run: ./Scripts/msp-release.sh run --profile=ci-test ${{ github.event.inputs.version }}
  env:
    COCOAPODS_TRUNK_TOKEN: ${{ secrets.COCOAPODS_TRUNK_TOKEN }}
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Environment Variables for CI

```bash
# Required
COCOAPODS_TRUNK_TOKEN     # CocoaPods trunk authentication
GITHUB_TOKEN              # GitHub API access

# Optional
SLACK_WEBHOOK_URL         # For notifications
MSP_LOG_LEVEL             # Logging verbosity
```

## Migration from Old System

### Key Differences

| Old System | New System |
|------------|------------|
| No release modes | Simple/Full modes |
| Verification always runs | Verification optional |
| 30+ env vars | 15 essential configs |
| Flat logging | Phase/Step hierarchy |
| Single config file | Profile-based config |

### Backward Compatibility

Old environment variables still work but are deprecated:

```bash
# Old way (deprecated)
MSP_SKIP_LOCAL_VALIDATION=1 ./Scripts/msp-release.sh run 1.0.0

# New way (recommended)
./Scripts/msp-release.sh run 1.0.0  # Simple mode skips by default
```

## Further Resources

- [Specification](./spec.md) - Full requirements
- [Data Model](./data-model.md) - Schema definitions
- [Research](./research.md) - Architecture analysis
- [README](../../README.md) - Project overview
