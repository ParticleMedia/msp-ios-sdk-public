# MSP iOS SDK — Remote Release Verification System

This folder contains the consumer-side verification system for MSP SDK releases.

## Goals

The remote verification system validates that:

1. SPM release tags can be consumed by a fresh external project.

2. CocoaPods Podspec releases can be consumed by a fresh external project.

3. Verification happens inside a sandbox directory (never touching the real repo).

4. No modifications are made to the MSP repository during verification.

## Architecture

verify_remote/
  ├── common/        # Shared utilities (sandbox, environment, logs)
  ├── spm/           # Remote SPM consumer validator
  └── cocoapods/     # Remote CocoaPods consumer validator

## Workflow (SPM)

1. Create isolated sandbox directory

2. Copy DemoApp into sandbox

3. Patch Package.swift to point to remote tag

4. Build using SwiftPM

5. Report success/failure to release orchestrator

## Workflow (CocoaPods)

1. Create isolated sandbox directory

2. Copy DemoApp into sandbox

3. Patch Podfile to use remote source

4. Run `pod install`

5. Build DemoApp

6. Report result

## Safety Guarantees

- No file inside the MSP SDK repository is modified.

- All operations occur inside a temporary sandbox.

- Safe to run in CI and local machines.

