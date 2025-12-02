# MSP iOS SDK — Device Verification System

This folder contains the device verification system for MSP SDK releases.

## Goals

The device verification system validates that:
1. Released SDK modules can be used to build device-ready applications.
2. DemoApp can be archived and exported as IPA using released CocoaPods or SPM dependencies.
3. Verification happens inside a sandbox directory (never touching the real repo).
4. No modifications are made to the MSP repository during verification.

## Architecture

```
verify_local_device/
  ├── run_device.sh              # Main orchestrator
  ├── prepare_demoapp.sh         # Copy DemoApp to sandbox
  ├── inject_sdk_pods.sh         # Inject CocoaPods dependencies
  ├── inject_sdk_spm.sh          # Inject SPM dependencies
  ├── archive_demoapp.sh         # Archive DemoApp using xcodebuild
  └── export_ipa.sh              # Export IPA from archive
```

## Workflow

1. Create isolated sandbox directory (`/tmp/msp-local-verify-device-*`)
2. Copy DemoApp into sandbox
3. Inject SDK dependencies (Pods or SPM) based on configuration
4. Archive DemoApp using xcodebuild
5. Export IPA from archive
6. Report success/failure to release orchestrator

## Configuration

Environment variables:
- `MSP_DEVICE_VERIFY_ENABLED=1` (default: enabled)
- `MSP_DEVICE_VERIFY_PODS=1` (default: enabled)
- `MSP_DEVICE_VERIFY_SPM=1` (default: enabled)

## Safety Guarantees

- No file inside the MSP SDK repository is modified.
- All operations occur inside a temporary sandbox.
- Safe to run in CI and local machines.
- All failures are soft-fail (non-blocking).

