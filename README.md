# MSP iOS SDK

[![CocoaPods](https://img.shields.io/cocoapods/v/MSPCore.svg)](https://cocoapods.org/pods/MSPCore)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)

Internal SDK repository containing MSPDemoApp, all core modules, adapters, and the Pods ↔ SPM toolchain.

---

## 1. SDK Developer Workflow (Start Here)

### 1.1 Prerequisites

```bash
brew install xcodegen cocoapods
```

### 1.2 Fresh Clone & Setup (CocoaPods Mode)

For a fresh clone, just run these commands:

```bash
git clone <repo-url>
cd msp-ios-sdk
pod install
open msp-ios-sdk.xcworkspace
```

Then select scheme **MSPDemoApp** → Run.

**That's it!** No additional scripts needed for initial setup.

> **Note:** This uses `pods-dev` mode (all modules as source code), which is the default for SDK development.

### 1.3 Build from Command Line (CocoaPods Mode)

```bash
xcodebuild \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

> Note: Change `iPhone 16` to any simulator available on your machine.

---

## 2. When Do You Need `switch-target.sh`?

The `switch-target.sh` script is **ONLY needed when switching between modes**, not for initial setup.

### Three-Mode Architecture

| Mode | Core Modules | Adapters | Use Case |
|------|--------------|----------|----------|
| **pods-dev** | SOURCE | SOURCE | Daily development (default) |
| **pods-release** | BINARY | SOURCE | Pre-release validation |
| **spm-release** | BINARY | SOURCE | SPM distribution testing |

> **Important:** Adapters are **SOURCE-ONLY** in all modes. No adapter XCFrameworks are ever required.

**Third-party SDKs in each mode:**
- **pods-dev / pods-release**: Third-party SDKs (Google, Facebook, InMobi, etc.) come from their official CocoaPods. CocoaPods handles embedding frameworks like DTBiOSSDK.framework automatically.
- **spm-release**: Third-party XCFrameworks are synced to `ThirdParty/` via `spm_sync_all.sh`.

**Workspace symlink:** All modes create a symlink at the project root:
```
msp-ios-sdk.xcworkspace → .generated/msp-ios-sdk.xcworkspace
```
This is handled automatically by `switch-target.sh` — always use `open msp-ios-sdk.xcworkspace`.

| Scenario | What to run |
|----------|-------------|
| Fresh clone (first time) | `pod install` → open workspace |
| Already in Pods mode, want to stay | Nothing needed |
| Switch to development mode | `./Scripts/switch-target.sh pods-dev` |
| Switch to release validation | `./Scripts/switch-target.sh pods-release` |
| Switch to SPM mode | `./Scripts/switch-target.sh spm-release` |

### 2.1 Switch to SPM Mode

```bash
./Scripts/switch-target.sh spm-release
```

This will:
- Clean `Pods/` directory
- Generate `Package.swift` from template
- Auto-sync XCFrameworks if missing
- Generate SPM project via XcodeGen
- Open `Examples/MSPDemoApp/MSPDemoApp.xcodeproj`

After Xcode opens, select scheme **MSPDemoApp-SPM** → Run.

### 2.2 Switch Back to CocoaPods Mode (from SPM)

```bash
./Scripts/switch-target.sh pods-dev
```

This will:
- Clean SPM artifacts (using `cleanup_spm.sh`)
- Run `pod install`
- Generate project files from templates via XcodeGen
- Open `msp-ios-sdk.xcworkspace`

### 2.3 Summary Table

| Mode | Workspace/Project | Scheme |
|------|-------------------|--------|
| **pods-dev** | `msp-ios-sdk.xcworkspace` | `MSPDemoApp` |
| **pods-release** | `msp-ios-sdk.xcworkspace` | `MSPDemoApp` |
| **spm-release** | `Examples/MSPDemoApp/MSPDemoApp.xcodeproj` | `MSPDemoApp-SPM` |

### 2.4 Template System

All generated files are created from templates (tracked in git):

| Template | Generated File | When |
|----------|----------------|------|
| `workspace.yml.template` | `workspace.yml` | All modes |
| `project.yml.template` | `project.yml` | All modes |
| `Package.swift.template` | `Package.swift` | spm-release only |
| `Info.plist.template` | `Info.plist` | All modes |

Generated files are ignored by git. After switching modes, `git status` should show no tracked file changes.

---

## 3. Round-Trip Testing

Test that all three modes work correctly:

```bash
./Scripts/target-switching/round-trip-test.sh
```

**Test cycle:** `pods-dev` → `pods-release` → `spm-release` → `pods-dev`

### Prerequisites

Before running the full round-trip test, you need the 5 core XCFrameworks:

```bash
./Scripts/xcframeworks/build-core.sh
```

This builds: MSPCore, MSPiOSCore, MSPSharedLibraries, MSPOMSDK, NovaCore

### What each mode validates

| Mode | Validation |
|------|------------|
| **pods-dev** | `pod install` + **DemoApp builds successfully** |
| **pods-release** | 5 core XCFrameworks exist (no DemoApp build) |
| **spm-release** | Package.swift syntax + 5 core XCFrameworks exist |

The round-trip test also validates:
- Generated files (workspace.yml, project.yml, Package.swift) exist
- Git status is clean after full cycle (no tracked file changes)

**Stress test (multiple cycles):**

```bash
./Scripts/target-switching/round-trip-test.sh --loops=3
```

**Skip builds (validation only):**

```bash
./Scripts/target-switching/round-trip-test.sh --skip-build
```

---

## 4. Upgrading Third-Party SDKs

> **Podfile is the only source of truth** for all third-party SDK versions.

### Step-by-Step Process

**1. Update version in Podfile:**

```ruby
pod 'Google-Mobile-Ads-SDK', '~> 12.0'
```

**2. Run these 3 commands:**

```bash
pod install                                     # Update Pods
./Scripts/spm-sync/spm_sync_all.sh              # Extract XCFrameworks to ThirdParty/
./Scripts/target-switching/round-trip-test.sh  # Validate all modes work
```

### Rules

| ✅ Do | ❌ Don't |
|-------|----------|
| Update versions in `Podfile` | Manually edit `ThirdParty/` contents |
| Run `spm_sync_all.sh` after changes | Edit third-party versions in `Package.swift` |

### XCFramework Build Rules

Only **5 core XCFrameworks** are required (built via `build-core.sh`):
- MSPCore
- MSPiOSCore
- MSPSharedLibraries
- MSPOMSDK
- NovaCore

**Adapter XCFrameworks are NOT required** — adapters are always source-only.

### Special Cases

- **PrebidMobile**: Uses canonical XCFramework at `ThirdParty/PrebidMobile/` (no extraction)
- **GoogleMobileAds**: Uses official SPM package (skip extraction)

---

## 5. Troubleshooting

### Pods build fails

```bash
pod install
rm -rf ~/Library/Developer/Xcode/DerivedData/*
open msp-ios-sdk.xcworkspace
```

### SPM: "binary target does not contain a binary artifact"

```bash
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/switch-target.sh spm-release
```

### SPM: "no such module XXX"

```bash
./Scripts/target-switching/cleanup_spm.sh --force
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/switch-target.sh spm-release
```

### Nuclear Option (Full Reset)

```bash
# 1. Clean everything
rm -rf Pods/ .swiftpm .build ~/Library/Developer/Xcode/DerivedData/*

# 2. Reinstall
pod install
./Scripts/spm-sync/spm_sync_all.sh

# 3. Switch to desired mode
./Scripts/switch-target.sh pods-dev   # or: pods-release, spm-release
```

### Full CI Validation

```bash
./Scripts/ci/ci_validate.sh
```

---

## 6. Repository Layout

```
msp-ios-sdk/
├── Sources/
│   ├── Core/                 # Core modules (5)
│   ├── Adapters/             # Ad network adapters (10) — always source
│   └── Common/               # Shared modules
│
├── Build/XCFrameworks/       # Built core XCFrameworks
├── Binary/                   # Release-ready XCFrameworks
├── ThirdParty/               # Third-party XCFrameworks (from Pods)
│
├── Scripts/
│   ├── spm-sync/             # Pods → SPM sync
│   ├── target-switching/     # Mode switching (3 modes)
│   ├── xcframeworks/         # XCFramework builders
│   └── ci/                   # CI scripts
│
├── Examples/MSPDemoApp/      # Demo app
├── *.podspec                 # CocoaPods specs (dual-mode)
├── *.template                # Project templates (tracked)
├── msp-ios-sdk.xcworkspace   # CocoaPods workspace (generated)
├── Package.swift             # SPM manifest (generated from template)
└── Podfile                   # CocoaPods (source of truth)
```

### Key Scripts

| Script | Purpose |
|--------|---------|
| `switch-target.sh` | Switch between pods-dev, pods-release, spm-release |
| `generate_project_templates.sh` | Generate project.yml from templates |
| `spm_sync_all.sh` | Sync Pods → ThirdParty XCFrameworks |
| `build-core.sh` | Build 5 core XCFrameworks |
| `build-adapters.sh` | Build adapter XCFrameworks (optional, non-blocking) |
| `validate_xcframeworks.sh` | Validate 5 core XCFrameworks exist |
| `round-trip-test.sh` | Test 3-mode switching cycle |
| `cleanup_spm.sh` | Clean SwiftPM artifacts |

---

## 7. Architecture

```
Podfile  (source of truth)
    │
    ▼ pod install
Pods/                  → ThirdParty/*.xcframework
    │                              │
    └──► spm_sync_all.sh ──────────┘
                              │
                              ▼
                        Package.swift.template
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼
        pods-dev         pods-release      spm-release
     (all source)     (core binary)     (core binary)
                      (adapter source)  (adapter source)

Required Core XCFrameworks (5):
  MSPCore, MSPiOSCore, MSPSharedLibraries, MSPOMSDK, NovaCore

Adapters: Always SOURCE (no XCFrameworks required)
```

### Release Workflow (Summary)

```
preflight → build-core → pods-release → spm-release → publish
```

For detailed release steps, see internal release documentation.

---

## 8. Internal Documentation

| Document | Description |
|----------|-------------|
| [DEPENDENCY_MIGRATION_GUIDE_ZH.md](Docs/DEPENDENCY_MIGRATION_GUIDE_ZH.md) | Chinese technical reference |

---

## 9. External App Integration

### CocoaPods

```ruby
pod 'MSPCore'
pod 'MSPGoogleAdapter'
pod 'MSPFacebookAdapter'
```

### SPM

```
https://github.com/ParticleMedia/msp-ios-sdk-public.git
```

---

## 10. Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 15.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| CocoaPods | 1.14.0+ |
| XcodeGen | Latest |

---

## 11. Contact

**Email:** pengyu.gou@newsbreak.com  
**GitHub Issues:** [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
