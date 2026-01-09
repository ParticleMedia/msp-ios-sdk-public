# MSP iOS SDK

MSP (Mobile SDK Platform) iOS SDK provides a unified advertising mediation framework for iOS applications. It integrates multiple ad networks through a modular adapter architecture with support for CocoaPods and Swift Package Manager distribution.

## Quick Start

### Local Development (pods-dev)

```bash
# Switch to development mode
./Scripts/switch-target.sh pods-dev

# Open workspace
open msp-ios-sdk.xcworkspace
```

### Release Commands

```bash
# Production release
./Scripts/msp-release.sh --profile=production run 1.0.0

# Resume interrupted release
./Scripts/msp-release.sh resume

# Fix public tag (after GitHub Push Protection skip)
./Scripts/msp-release.sh fix-public-tag 1.0.0
```

## Development Modes

| Mode | Command | Use Case |
|------|---------|----------|
| `pods-dev` | `./Scripts/switch-target.sh pods-dev` | Daily development with source files |
| `pods-release` | `./Scripts/switch-target.sh pods-release` | Pre-release validation with XCFrameworks |
| `spm-release` | `./Scripts/switch-target.sh spm-release` | SPM distribution testing |

## Repository Layout

```
msp-ios-sdk/
├── Sources/
│   ├── Core/           # Core modules (MSPCore, MSPiOSCore, NovaCore, etc.)
│   └── Adapters/       # Ad network adapters
├── ThirdParty/         # Pre-built third-party XCFrameworks
├── Binary/             # Built XCFrameworks for release
├── Examples/           # MSPDemoApp
├── Scripts/            # Automation scripts
│   ├── msp-release.sh  # Main release entrypoint
│   └── switch-target.sh # Mode switching
├── Podfile             # CocoaPods dependencies (source of truth)
├── Package.swift.template # SPM package template
└── *.podspec           # Pod specifications
```

## Release Profiles

| Profile | DRY_RUN | Purpose |
|---------|---------|---------|
| `production` | false | Full production release |
| `local-dev` | true | Local testing (no publishing) |
| `ci-test` | true | CI/CD validation |
| `quick-test` | true | Minimal validation |

## Documentation

- [Docs/INDEX.md](Docs/INDEX.md) - Documentation navigation
- [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) - System architecture
- [Docs/RELEASE.md](Docs/RELEASE.md) - Release semantics
- [Docs/TARGET_SWITCHING.md](Docs/TARGET_SWITCHING.md) - Mode switching details
- [Docs/THIRD_PARTY_UPGRADES.md](Docs/THIRD_PARTY_UPGRADES.md) - Dependency management
- [Docs/TROUBLESHOOTING.md](Docs/TROUBLESHOOTING.md) - Common issues
- [Scripts/README.md](Scripts/README.md) - Scripts reference

## Requirements

- Xcode 15.0+
- iOS 15.0+
- CocoaPods 1.14+
- XcodeGen (`brew install xcodegen`)
