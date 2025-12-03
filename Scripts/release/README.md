# MSP iOS SDK Release System

This directory contains the complete release orchestration system for the MSP iOS SDK, including verification, notification, and publishing workflows.

## Table of Contents

- [Overview](#overview)
- [Release Orchestrator](#release-orchestrator)
- [Verification Systems](#verification-systems)
  - [Remote Verification](#remote-verification)
  - [Local Verification](#local-verification)
  - [Device Verification](#device-verification)
  - [XCFramework Deep Verification](#xcframework-deep-verification)
  - [Verification Matrix](#verification-matrix)
- [Notification System](#notification-system)
- [State Management](#state-management)
- [Configuration](#configuration)
- [Quick Reference](#quick-reference)

## Overview

The MSP Release System provides a complete multi-layer verification framework that ensures both local and remote environments can successfully resolve, install, and build MSP SDK products across all distribution methods:

- **CocoaPods binary distribution**
- **SwiftPM binaryTarget distribution**
- **Local SPM (path dependency) integration**
- **Full environment matrix testing (15 scenarios)**

All verification systems operate in isolated sandbox directories and never modify the main repository.

## Release Orchestrator

The main release orchestrator (`modular.sh`) coordinates the entire release process:

1. Preflight checks
2. Version management
3. Module publishing (CocoaPods and SPM)
4. Multi-layer verification
5. State persistence
6. Notification dispatch

### Usage

```bash
# Run a full release
./Scripts/msp-release.sh run <version>

# Dry-run mode
./Scripts/msp-release.sh run <version> --dry-run

# Resume from state file
./Scripts/msp-release.sh resume

# Rollback on failure
./Scripts/msp-release.sh rollback
```

See [Scripts/README.md](../README.md) for more details on the main entrypoint.

## Verification Systems

### Remote Verification

**Location:** `Scripts/release/verify_remote/`

The remote verification system validates that released SDK modules can be consumed by fresh external projects.

#### Goals

1. SPM release tags can be consumed by a fresh external project
2. CocoaPods Podspec releases can be consumed by a fresh external project
3. Verification happens inside a sandbox directory (never touching the real repo)
4. No modifications are made to the MSP repository during verification

#### Architecture

```
verify_remote/
  ├── common/        # Shared utilities (sandbox, environment, logs)
  ├── spm/           # Remote SPM consumer validator
  └── cocoapods/     # Remote CocoaPods consumer validator
```

#### Workflow (SPM)

1. Create isolated sandbox directory
2. Copy DemoApp into sandbox
3. Patch Package.swift to point to remote tag
4. Build using SwiftPM
5. Report success/failure to release orchestrator

#### Workflow (CocoaPods)

1. Create isolated sandbox directory
2. Copy DemoApp into sandbox
3. Patch Podfile to use remote source
4. Run `pod install`
5. Build DemoApp
6. Report result

#### Configuration

Environment variables:
- `MSP_REMOTE_VERIFY_ENABLED=1` (default: enabled)
- `MSP_REMOTE_VERIFY_SPM=1` (default: enabled)
- `MSP_REMOTE_VERIFY_PODS=1` (default: enabled)
- `MSP_VERIFY_SPM_URL` - Remote SPM package URL
- `MSP_VERIFY_SPM_VERSION` - Version tag to verify
- `MSP_VERIFY_PODS_URL` - CocoaPods source URL
- `MSP_VERIFY_PODS_VERSION` - Version to verify

#### Safety Guarantees

- No file inside the MSP SDK repository is modified
- All operations occur inside a temporary sandbox
- Safe to run in CI and local machines
- All failures are soft-fail (non-blocking)

---

### Local Verification

**Location:** `Scripts/release/verify_local/`

The local verification system validates that released SDK modules can be consumed by a fresh local project.

#### Goals

1. Released SDK modules can be consumed by a fresh local project
2. DemoApp can build successfully using released CocoaPods or SPM dependencies
3. Verification happens inside a sandbox directory (never touching the real repo)
4. No modifications are made to the MSP repository during verification

#### Architecture

```
verify_local/
  ├── run_local.sh              # Main orchestrator
  ├── prepare_demoapp.sh        # Copy DemoApp to sandbox
  ├── inject_sdk_pods.sh        # Inject CocoaPods dependencies
  ├── inject_sdk_spm.sh         # Inject SPM dependencies
  └── build_demoapp.sh          # Build DemoApp using xcodebuild
```

#### Workflow

1. Create isolated sandbox directory (`/tmp/msp-local-verify-*`)
2. Copy DemoApp into sandbox
3. Inject SDK dependencies (Pods or SPM) based on configuration
4. Build DemoApp using xcodebuild
5. Report success/failure to release orchestrator

#### Configuration

Environment variables:
- `MSP_LOCAL_VERIFY_ENABLED=1` (default: enabled)
- `MSP_LOCAL_USE_PODS=1` (default: enabled)
- `MSP_LOCAL_USE_SPM=1` (default: enabled)

#### Safety Guarantees

- No file inside the MSP SDK repository is modified
- All operations occur inside a temporary sandbox
- Safe to run in CI and local machines
- All failures are soft-fail (non-blocking)

---

### Device Verification

**Location:** `Scripts/release/verify_local_device/`

The device verification system validates that released SDK modules can be used to build device-ready applications.

#### Goals

1. Released SDK modules can be used to build device-ready applications
2. DemoApp can be archived and exported as IPA using released CocoaPods or SPM dependencies
3. Verification happens inside a sandbox directory (never touching the real repo)
4. No modifications are made to the MSP repository during verification

#### Architecture

```
verify_local_device/
  ├── run_device.sh              # Main orchestrator
  ├── prepare_demoapp.sh         # Copy DemoApp to sandbox
  ├── inject_sdk_pods.sh         # Inject CocoaPods dependencies
  ├── inject_sdk_spm.sh          # Inject SPM dependencies
  ├── archive_demoapp.sh         # Archive DemoApp using xcodebuild
  └── export_ipa.sh              # Export IPA from archive
```

#### Workflow

1. Create isolated sandbox directory (`/tmp/msp-local-verify-device-*`)
2. Copy DemoApp into sandbox
3. Inject SDK dependencies (Pods or SPM) based on configuration
4. Archive DemoApp using xcodebuild
5. Export IPA from archive
6. Report success/failure to release orchestrator

#### Configuration

Environment variables:
- `MSP_DEVICE_VERIFY_ENABLED=1` (default: enabled)
- `MSP_DEVICE_VERIFY_PODS=1` (default: enabled)
- `MSP_DEVICE_VERIFY_SPM=1` (default: enabled)

#### Safety Guarantees

- No file inside the MSP SDK repository is modified
- All operations occur inside a temporary sandbox
- Safe to run in CI and local machines
- All failures are soft-fail (non-blocking)

---

### XCFramework Deep Verification

**Location:** `Scripts/release/verify_xcframework/`

The XCFramework verification system validates binary quality and correctness of released XCFrameworks.

#### Goals

1. Released XCFrameworks have correct architectures (arm64, arm64-simulator, x86_64)
2. Swift modules are properly structured (.swiftinterface, .swiftmodule, .swiftdoc)
3. Dependencies are correctly linked (no private symbols, no unauthorized frameworks)
4. Info.plist and umbrella headers are valid
5. Symbol tables are clean (no private/debug symbols leaked)
6. Binary sizes are within acceptable thresholds

#### Architecture

```
verify_xcframework/
  ├── run_xcf.sh              # Main orchestrator
  ├── scan_architectures.sh   # Architecture validation
  ├── scan_swiftmodules.sh    # Swift module validation
  ├── scan_dependencies.sh     # Dependency validation
  ├── scan_plist.sh           # Info.plist and umbrella header validation
  ├── scan_symbols.sh         # Symbol table validation
  └── scan_size.sh            # Binary size validation
```

#### Workflow

1. Create isolated sandbox directory (`/tmp/msp-verify-xcf-*`)
2. Copy XCFrameworks into sandbox
3. Run all validation scans in sequence
4. Collect results per module
5. Report success/failure to release orchestrator

#### Validation Checks

**Architecture Check**
- Validates arm64, arm64-simulator, x86_64 presence
- Uses `lipo -info` to inspect architectures
- WARN on missing architectures (non-blocking)

**Swift Module Check**
- Validates .swiftinterface, .swiftmodule, .swiftdoc existence
- FAIL on missing Swift modules (SPM/Pods cannot work)

**Dependency Check**
- Uses `otool -L` to inspect linked libraries
- FAIL on private symbols or unauthorized frameworks
- Validates against whitelist

**Info.plist Check**
- Validates Info.plist existence and structure
- Validates umbrella header existence
- FAIL on missing critical files

**Symbol Check**
- Uses `nm -gU` and `swift-demangle` to inspect symbols
- FAIL on private/debug/internal symbol leaks

**Size Check**
- Generates .size_report.json
- Compares with previous release
- WARN on >30% size increase

#### Safety Guarantees

- No file inside the MSP SDK repository is modified
- All operations occur inside a temporary sandbox
- Safe to run in CI and local machines
- All failures are soft-fail (non-blocking)

---

### Verification Matrix

**Location:** `Scripts/release/verify-matrix/`

An automated test matrix for validating the MSP iOS SDK release system across multiple configuration combinations.

#### What This Tests

Each test case evaluates:
- `DRY_RUN` mode
- `VERIFY_SPM_STRICT` behavior
- presence/absence of `SPM_REMOTE_URL`
- Pods-only / SPM-only configurations

#### Directory Structure

```
verify-matrix/
├── generate_cases.sh     # auto-generates test cases
├── matrix.sh             # runs all test cases
├── cases/                # generated test-case scripts
└── logs/                 # per-case logs (auto-created)
```

#### Usage

**Generate all cases:**
```bash
./Scripts/release/verify-matrix/generate_cases.sh
```

**Run full matrix:**
```bash
./Scripts/release/verify-matrix/matrix.sh
```

**Output:**
- `logs/*.log` — logs per case
- `summary.json` — machine-readable summary

#### Summary Report Format

Each run produces a machine-readable summary:

```json
{
  "timestamp": "2025-01-03T15:23:11Z",
  "total_cases": 15,
  "passed": 13,
  "failed": 2,
  "cases": {
    "A1": "passed",
    "A2": "failed",
    ...
  }
}
```

#### Adding New Dimensions

Use `generate_cases.sh` as the source of truth. Add your case definitions there.

---

## Notification System

**Location:** `Scripts/notify/`

The notification system provides configurable Slack and Email notifications for release events.

### Features

- **Slack Notifications:** Direct messages and channel broadcasts
- **Email Notifications:** HTML-formatted release summaries
- **Template-Driven:** All messages use YAML templates
- **Block Kit Support:** Rich Slack card UI (optional)
- **Soft-Fail:** Notification failures never block releases

### Configuration

See `Scripts/config/notify_mapping.yaml` and `Scripts/config/email_mapping.yaml` for template configuration.

Environment variables:
- `MSP_SLACK_ALERT_ENV` - "test" or "prod"
- `MSP_SLACK_DM_OVERRIDE` - Test user ID for TEST mode
- `MSP_SLACK_TEST_WEBHOOK` - Test webhook URL
- `SLACK_BOT_TOKEN` - Slack Bot API token
- `MSP_EMAIL_ENDPOINT` - HTTP email service endpoint
- `MSP_SLACK_BLOCK_MODE=1` - Enable Block Kit UI

### Usage

Notifications are automatically triggered by the release orchestrator. No manual invocation needed.

---

## State Management

**Location:** `.msp-release-state.json`

The release system maintains state in a JSON file at the repository root.

### State Schema

```json
{
  "version": "1.9.0",
  "status": "in_progress",
  "modules": {
    "MSPCore": {
      "version": "1.9.0",
      "pods_published": true,
      "spm_published": true
    }
  },
  "verification": {
    "remote": {
      "spm": { "executed": true, "success": true },
      "pods": { "executed": true, "success": true }
    },
    "local": {
      "executed": true,
      "mode": "pods",
      "success": true
    },
    "device": {
      "executed": true,
      "mode": "pods",
      "success": true,
      "archive": "pass",
      "ipa": "pass"
    },
    "xcframework": {
      "executed": true,
      "modules": {
        "MSPCore": { "success": true, "warnings": 0 }
      }
    }
  },
  "notifications": {
    "slack_sent": true,
    "email_sent": true
  }
}
```

### State Operations

- **Resume:** `./Scripts/msp-release.sh resume` - Continue from last saved state
- **Rollback:** `./Scripts/msp-release.sh rollback` - Undo last release attempt
- **Status:** Check `.msp-release-state.json` for current state

---

## Configuration

### Release Configuration

**Location:** `Scripts/release/config/release.yaml`

Main configuration file for release settings, module definitions, and verification parameters.

### Environment Variables

**Verification:**
- `MSP_REMOTE_VERIFY_ENABLED=1`
- `MSP_REMOTE_VERIFY_SPM=1`
- `MSP_REMOTE_VERIFY_PODS=1`
- `MSP_LOCAL_VERIFY_ENABLED=1`
- `MSP_LOCAL_USE_PODS=1`
- `MSP_LOCAL_USE_SPM=1`
- `MSP_DEVICE_VERIFY_ENABLED=1`
- `MSP_DEVICE_VERIFY_PODS=1`
- `MSP_DEVICE_VERIFY_SPM=1`
- `MSP_XCF_VERIFY_ENABLED=1`

**Notifications:**
- `MSP_SLACK_ALERT_ENV` - "test" or "prod"
- `MSP_SLACK_DM_OVERRIDE` - Test user ID
- `MSP_SLACK_TEST_WEBHOOK` - Test webhook URL
- `SLACK_BOT_TOKEN` - Slack Bot API token
- `MSP_EMAIL_ENDPOINT` - HTTP email service endpoint

**Release Control:**
- `DRY_RUN=1` - Simulate without actual publishing
- `MSP_AUTHOR_EMAIL` - Release author email

---

## Quick Reference

### Common Workflows

**Full Release:**
```bash
./Scripts/msp-release.sh run 1.9.0
```

**Dry-Run Release:**
```bash
./Scripts/msp-release.sh run 1.9.0 --dry-run
```

**Resume Failed Release:**
```bash
./Scripts/msp-release.sh resume
```

**Run Verification Only:**
```bash
./Scripts/msp-release.sh verify 1.9.0
```

**Run Verification Matrix:**
```bash
./Scripts/msp-release.sh verify-matrix
```

### Recommended Workflow

**During Development / Refactoring:**
```bash
./Scripts/msp-release.sh verify-matrix
```
- Ensures all environments behave consistently
- Useful after major changes to release/publish scripts

**Before Official Release:**
```bash
./Scripts/msp-release.sh verify <version>
```

**CI Integration (Optional):**
Add a small subset of matrix cases:
- E1 — baseline default
- B2 — strict + valid SPM URL
- E2 — pods-only
- E3 — spm-only

---

## Notes

- The verification system never touches the main repository — all tests run in isolated temp directories
- Pods verification is hard-fail (always blocks release)
- SPM remote verification is configurable via strict mode
- Local SPM validation is always blocking
- All verification failures are soft-fail (non-blocking) unless explicitly configured otherwise

---

## Related Documentation

- [Scripts/README.md](../README.md) - Main scripts overview and entrypoints
- [Scripts/target-switching/README.md](../target-switching/README.md) - Target switching and mode management

