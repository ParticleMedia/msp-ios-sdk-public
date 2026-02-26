# Contract: CLI Interface

**Feature**: Release System Refactor
**Date**: 2026-02-03

## Overview

This document defines the CLI interface contract for the MSP release system.

## Command Structure

```
msp-release.sh <command> [options] [VERSION]
```

## Commands

### run

Execute a full release (CocoaPods + SPM).

```bash
./Scripts/msp-release.sh run [--full] [--profile=NAME] <VERSION>
```

**Arguments**:
- `VERSION` (required): Semantic version (e.g., `1.0.0`, `1.0.0-beta.1`)

**Options**:
- `--full`: Enable full mode with all verification
- `--profile=NAME`: Use named profile
- `--skip-pods`: Skip CocoaPods release
- `--skip-spm`: Skip SPM release
- `--dry-run`: Preview without executing
- `--verbose`: Enable debug logging

**Exit Codes**:
- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: Preflight failure
- `4`: Publish failure
- `5`: Verification failure

### pods

Execute CocoaPods release only.

```bash
./Scripts/msp-release.sh pods [--full] <VERSION>
```

### spm

Execute SPM release only.

```bash
./Scripts/msp-release.sh spm [--full] <VERSION>
```

### resume

Resume a failed release from last checkpoint.

```bash
./Scripts/msp-release.sh resume [--full]
```

**Behavior**:
- Reads state from `.msp-release-state.json`
- Skips completed steps
- Retries failed step
- `--full` adds verification after completion

### verify

Run verification only (for already-published versions).

```bash
./Scripts/msp-release.sh verify <VERSION>
```

**Verification Types**:
- Local sandbox build
- Remote CocoaPods availability
- Remote SPM resolution
- Sample app build
- Device testing (optional)

### env

Display effective configuration.

```bash
./Scripts/msp-release.sh env [--json]
```

**Output**: Human-readable or JSON format configuration dump.

### preflight

Run preflight checks without releasing.

```bash
./Scripts/msp-release.sh preflight <VERSION>
```

### rollback

Rollback a failed or unwanted release.

```bash
./Scripts/msp-release.sh rollback [--force]
```

**Behavior**:
- Without `--force`: Shows rollback plan
- With `--force`: Executes rollback (delete tags, branches)
- **Note**: Cannot unpublish from CocoaPods trunk

### help

Display help information.

```bash
./Scripts/msp-release.sh help [command]
```

### version

Display release system version.

```bash
./Scripts/msp-release.sh version
```

## Global Options

These options can be used with any command:

| Option | Description | Default |
|--------|-------------|---------|
| `--full` | Enable full mode | false |
| `--profile=NAME` | Use named profile | local-dev |
| `--config=FILE` | Load custom config | release.yaml |
| `--dry-run` | Preview mode | false |
| `--verbose, -V` | Debug output | false |
| `--no-ansi` | Disable colors | false |
| `--version=VER` | Alternative version spec | - |
| `--release-notes=MSG` | GitHub release notes | - |

## Option Parsing Rules

1. **Position**: Options can appear before or after command
2. **Format**: Both `--option=value` and `--option value` supported
3. **Boolean**: `--flag` enables, no `--no-flag` prefix
4. **Priority**: CLI > Environment > Config > Defaults

## Version Format

Versions must follow semantic versioning:

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

**Examples**:
- `1.0.0` - Release version
- `1.0.0-beta.1` - Beta version
- `1.0.0-rc.2` - Release candidate
- `0.0.3` - Development version

## Environment Variables

| Variable | Maps To | Description |
|----------|---------|-------------|
| `MSP_RELEASE_MODE` | `--full` | Set to "full" for full mode |
| `DRY_RUN` | `--dry-run` | Set to "true" for preview |
| `MSP_LOG_LEVEL` | `--verbose` | debug, info, warn, error |
| `MSP_PROFILE` | `--profile` | Profile name |
| `RELEASE_VERSION` | `VERSION` | Version number |

## Output Contract

### Standard Output

Normal operation output to stdout:

```
[Phase 1/4] [Step 01/05] [INFO] Starting preflight checks
[Phase 1/4] [Step 02/05] [INFO] Checking git status
...
```

### Error Output

Errors to stderr:

```
[Phase 2/4] [Step 03/16] [ERROR] pod trunk push failed: MSPCore
```

### Exit Behavior

- Success: Clean exit with code 0
- Failure: Log error, update state, exit with appropriate code
- Interrupt (Ctrl+C): Save state, clean exit

## Examples

### Basic Release

```bash
# Simple release
./Scripts/msp-release.sh run 1.0.0

# Full release
./Scripts/msp-release.sh run --full 1.0.0
```

### With Options

```bash
# Production profile
./Scripts/msp-release.sh run --profile=production 1.0.0

# Dry run with verbose
./Scripts/msp-release.sh run --dry-run --verbose 1.0.0

# Skip SPM
./Scripts/msp-release.sh run --skip-spm 1.0.0
```

### Resume Scenarios

```bash
# Resume simple
./Scripts/msp-release.sh resume

# Resume with verification
./Scripts/msp-release.sh resume --full
```

### Verification

```bash
# Verify published version
./Scripts/msp-release.sh verify 1.0.0

# Check config
./Scripts/msp-release.sh env
```
