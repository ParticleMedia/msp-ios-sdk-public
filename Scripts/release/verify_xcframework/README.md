# MSP iOS SDK — XCFramework Deep Verification System

This folder contains the XCFramework deep verification system for MSP SDK releases.

## Goals

The XCFramework verification system validates that:
1. Released XCFrameworks have correct architectures (arm64, arm64-simulator, x86_64).
2. Swift modules are properly structured (.swiftinterface, .swiftmodule, .swiftdoc).
3. Dependencies are correctly linked (no private symbols, no unauthorized frameworks).
4. Info.plist and umbrella headers are valid.
5. Symbol tables are clean (no private/debug symbols leaked).
6. Binary sizes are within acceptable thresholds.

## Architecture

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

## Workflow

1. Create isolated sandbox directory (`/tmp/msp-verify-xcf-*`)
2. Copy XCFrameworks into sandbox
3. Run all validation scans in sequence
4. Collect results per module
5. Report success/failure to release orchestrator

## Validation Checks

### Architecture Check
- Validates arm64, arm64-simulator, x86_64 presence
- Uses `lipo -info` to inspect architectures
- WARN on missing architectures (non-blocking)

### Swift Module Check
- Validates .swiftinterface, .swiftmodule, .swiftdoc existence
- FAIL on missing Swift modules (SPM/Pods cannot work)

### Dependency Check
- Uses `otool -L` to inspect linked libraries
- FAIL on private symbols or unauthorized frameworks
- Validates against whitelist

### Info.plist Check
- Validates Info.plist existence and structure
- Validates umbrella header existence
- FAIL on missing critical files

### Symbol Check
- Uses `nm -gU` and `swift-demangle` to inspect symbols
- FAIL on private/debug/internal symbol leaks

### Size Check
- Generates .size_report.json
- Compares with previous release
- WARN on >30% size increase

## Safety Guarantees

- No file inside the MSP SDK repository is modified.
- All operations occur inside a temporary sandbox.
- Safe to run in CI and local machines.
- All failures are soft-fail (non-blocking).

