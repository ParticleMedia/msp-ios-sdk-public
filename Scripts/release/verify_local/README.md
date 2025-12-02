# MSP iOS SDK — Local Release Verification System

This folder contains the local verification system for MSP SDK releases.

## Goals

The local verification system validates that:
1. Released SDK modules can be consumed by a fresh local project.
2. DemoApp can build successfully using released CocoaPods or SPM dependencies.
3. Verification happens inside a sandbox directory (never touching the real repo).
4. No modifications are made to the MSP repository during verification.

## Architecture

```
verify_local/
  ├── run_local.sh              # Main orchestrator
  ├── prepare_demoapp.sh        # Copy DemoApp to sandbox
  ├── inject_sdk_pods.sh        # Inject CocoaPods dependencies
  ├── inject_sdk_spm.sh         # Inject SPM dependencies
  └── build_demoapp.sh          # Build DemoApp using xcodebuild
```

## Workflow

1. Create isolated sandbox directory (`/tmp/msp-local-verify-*`)
2. Copy DemoApp into sandbox
3. Inject SDK dependencies (Pods or SPM) based on configuration
4. Build DemoApp using xcodebuild
5. Report success/failure to release orchestrator

## Configuration

Environment variables:
- `MSP_LOCAL_VERIFY_ENABLED=1` (default: enabled)
- `MSP_LOCAL_USE_PODS=1` (default: enabled)
- `MSP_LOCAL_USE_SPM=1` (default: enabled)

## Safety Guarantees

- No file inside the MSP SDK repository is modified.
- All operations occur inside a temporary sandbox.
- Safe to run in CI and local machines.
- All failures are soft-fail (non-blocking).

