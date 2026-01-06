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

### Phase B: Simplified Architecture

**Key Changes**:
- ✅ Removed dual-tier system (preflight/release)
- ✅ Unified `DRY_RUN` control (true/false)
- ✅ Profile-based configuration
- ✅ Automatic release branch creation

**Migration**:
- Old: `MSP_RELEASE_TIER=release` → New: `DRY_RUN=false`
- Old: `MSP_RELEASE_TIER=preflight` → New: `DRY_RUN=true`

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

## 11. MSP Release Config Variable Naming Convention

All configuration keys follow the strict naming convention:

### 1. SCOPE (pods, spm)

Indicates which subsystem owns the variable.

Examples:
- `pods.remote_url`
- `pods.remote_primary_product`
- `spm.remote_url`
- `spm.remote_product_name`

### 2. PURPOSE (remote_url, primary_product, product_name)

Describes exactly what the variable is used for.

### 3. Exported Shell Variables (UPPER_SNAKE_CASE)

All parsed config values are exported using uppercase snake case:

| YAML Key                      | Shell Variable               |
|------------------------------|-------------------------------|
| pods.remote_url              | PODS_REMOTE_URL               |
| pods.remote_primary_product  | PODS_REMOTE_PRIMARY_PRODUCT   |
| spm.remote_url               | SPM_REMOTE_URL                |
| spm.remote_product_name      | SPM_REMOTE_PRODUCT_NAME       |

### 4. No ambiguity

- Podspec → "product" refers to CocoaPods frameworks
- SPM → "product" refers to SPM product names
- All variables always reference a *single importable module name*

### 5. Safe defaults

Defaults ensure verification always works even with minimal config:

- PODS_REMOTE_PRIMARY_PRODUCT = MSPCore
- SPM_REMOTE_PRODUCT_NAME = MSPAds

---

## 12. Verification Matrix

The verification matrix system provides automated testing of the MSP release verification system across multiple scenarios.

### Purpose

The verification matrix tests various combinations of:
- `DRY_RUN` mode (enabled/disabled)
- `VERIFY_SPM_STRICT` behavior (strict/soft mode)
- `SPM_REMOTE_URL` presence (set/unset/invalid)
- Pods-only and SPM-only configurations

### How to Run

Run the full verification matrix:

```bash
./Scripts/msp-release.sh verify-matrix
```

Or run the matrix script directly:

```bash
./Scripts/release/verify-matrix/matrix.sh
```

### Output Structure

Results are stored under `verification_matrix/run-<timestamp>/`:

```
verification_matrix/
└── run-20251128_160000/
    ├── case-A1/
    │   └── output.log
    ├── case-B2/
    │   └── output.log
    └── summary.json
```

The `summary.json` file contains machine-readable results:

```json
{
  "timestamp": "2025-11-28T16:00:00Z",
  "cases": {
    "A1": { "status": "success", "exit_code": 0 },
    "B2": { "status": "failed", "exit_code": 1 }
  }
}
```

### Strict vs Non-Strict Behavior

- **Strict mode (default)**: SPM remote verification failures block the release
- **Non-strict mode**: SPM remote verification failures are logged as warnings but do not block the release

Configure via `release.yaml`:

```yaml
verify:
  spm_strict: true   # or false for non-strict
```

### Overriding Test Parameters

You can override environment variables for specific test scenarios:

```bash
DRY_RUN=1 VERIFY_SPM_STRICT=false SPM_REMOTE_URL="https://example.com" \
  ./Scripts/msp-release.sh verify-matrix
```

### CI Usage Examples

```bash
# Run matrix in CI
./Scripts/msp-release.sh verify-matrix

# Check exit code
if [[ $? -ne 0 ]]; then
  echo "Verification matrix failed"
  exit 1
fi
```

### Generating Test Cases

To regenerate all test case scripts:

```bash
./Scripts/release/verify-matrix/generate_cases.sh
```

This will create 15 test cases covering all combinations of DRY_RUN, VERIFY_SPM_STRICT, and SPM_REMOTE_URL settings.

---

## Release & Deployment

### Configuration System

MSP iOS SDK release system uses **profile-based configuration** for simplified environment management.

#### Quick Start

```bash
# Local development (dry-run, minimal validation)
./Scripts/msp-release.sh --profile=local-dev run 0.4.0-rc.1

# Production release (publish enabled, full validation)
./Scripts/msp-release.sh --profile=production run 0.4.0-rc.1

# CI testing (dry-run, full validation, JSON logs)
./Scripts/msp-release.sh --profile=ci-test run 0.4.0-rc.1
```

#### Available Profiles

| Profile | Purpose | DRY_RUN | Validation | Use Case |
|---------|---------|---------|------------|----------|
| **local-dev** | Local development | ✅ true | Minimal | Quick testing, development |
| **ci-test** | CI/CD testing | ✅ true | Full | Automated CI pipelines |
| **production** | Production release | ❌ false | Full | Actual CocoaPods releases |
| **quick-test** | Quick validation | ✅ true | None | Fast sanity checks |

#### Configuration File

Configuration is stored in `Scripts/config/release.yaml`. See the file for detailed settings and comments.

#### Environment Variable Overrides

All profile settings can be overridden using environment variables:

```bash
# Override specific settings
DRY_RUN=false ./Scripts/msp-release.sh --profile=local-dev run 0.4.0-rc.1
MSP_LOG_LEVEL=debug ./Scripts/msp-release.sh --profile=production run 0.4.0-rc.1

# Override multiple settings
DRY_RUN=false MSP_LOG_LEVEL=debug MSP_MAX_WORKERS=8 \
  ./Scripts/msp-release.sh --profile=local-dev run 0.4.0-rc.1
```

#### Configuration Priority

Settings are applied in the following order (highest to lowest):

1. **CLI flags**: `--skip-pods`, `--dry-run`, etc.
2. **Environment variables**: `DRY_RUN=false`, `MSP_LOG_LEVEL=debug`
3. **Profile settings**: `--profile=production`
4. **Config file**: `Scripts/config/release.yaml`
5. **Built-in defaults**: Hardcoded fallbacks

#### Backward Compatibility

Old environment variable approach still works:

```bash
# Option 1: Profile-based (recommended)
./Scripts/msp-release.sh --profile=production run 0.4.0-rc.1

# Option 2: Environment variables
DRY_RUN=false MSP_ALLOW_TRUNK_PUSH=1 ./Scripts/msp-release.sh run 0.4.0-rc.1
```

#### Configuration Variables

The system uses 15 core configuration variables organized by category:

**Core**:
- `DRY_RUN`: Skip publish steps (CocoaPods push, Git push)
- `MODE`: Release mode (cli, ci)
- `LOG_LEVEL`: Logging level (debug, info, warn, error)

**Validation**:
- `MSP_VALIDATION_PODS`: Validate podspecs
- `MSP_VALIDATION_SPM`: Validate SPM packages
- `MSP_VALIDATION_XCFRAMEWORK`: Validate XCFrameworks
- `MSP_VALIDATION_LOCAL`: Local build validation
- `MSP_VALIDATION_REMOTE`: Remote validation
- `MSP_VALIDATION_DEVICE`: Device testing

**Notifications**:
- `MSP_SLACK_ENABLED`: Enable Slack notifications
- `MSP_SLACK_ENV`: Slack environment (test, prod)
- `MSP_EMAIL_ENABLED`: Enable email notifications

**Safety**:
- `MSP_ALLOW_EXISTING_TAG`: Allow reusing existing Git tags
- `MSP_ALLOW_EXISTING_RELEASE`: Allow reusing existing GitHub Releases
- `MSP_KEEP_SANDBOX`: Keep worktree sandbox after completion
- `MSP_REQUIRE_CONFIRMATION`: Require manual confirmation prompts

**Performance**:
- `MSP_PARALLEL_BUILDS`: Build XCFrameworks in parallel
- `MSP_MAX_WORKERS`: Max parallel workers
- `MSP_CDN_WAIT_TIME`: Seconds to wait for CDN propagation

#### Examples

**Local Development**:
```bash
# Quick test with minimal validation
./Scripts/msp-release.sh --profile=local-dev run 0.4.0-test

# Debug mode
MSP_LOG_LEVEL=debug ./Scripts/msp-release.sh --profile=local-dev run 0.4.0-test

# Force real publish from local
DRY_RUN=false ./Scripts/msp-release.sh --profile=local-dev run 0.4.0-test
```

**Production Release**:
```bash
# Standard production release
./Scripts/msp-release.sh --profile=production run 0.4.0-rc.1

# Production release with debug logging
MSP_LOG_LEVEL=debug ./Scripts/msp-release.sh --profile=production run 0.4.0-rc.1

# View configuration before releasing
./Scripts/msp-release.sh --profile=production --verbose config
```

#### Troubleshooting

**Q: How do I see what configuration is being used?**
```bash
./Scripts/msp-release.sh --profile=production --verbose version
```

**Q: Why is my environment variable not taking effect?**
Check the priority order. CLI flags and existing environment variables may override your setting.

**Q: Can I create custom profiles?**
Yes, edit `Scripts/config/release.yaml` and add a new profile section following the existing format.

**Q: Where can I find the full configuration?**
See `Scripts/config/release.yaml` for all available settings and profiles.

#### Migration from Old System

See [docs/MIGRATION.md](docs/MIGRATION.md) for detailed migration guide from environment variables to profiles.

For complete configuration documentation, see [docs/CONFIGURATION_GUIDE.md](docs/CONFIGURATION_GUIDE.md).

---

### Quick Start (Legacy)

**Local Release** (3 variables needed):
```bash
# Setup environment
source Scripts/utils/setup-release-env.sh local

# Run release
./Scripts/msp-release.sh run 0.3.0-rc.6
```

**Using direnv** (auto-load):
```bash
cp .envrc.example .envrc
direnv allow
./Scripts/msp-release.sh run 0.3.0-rc.6
```

### Environment Variables (Legacy)

### 🚀 推荐方式: 使用 direnv 自动加载（最优）

**一次配置，永久生效！**

direnv 可以在你 cd 进入目录时自动加载 `.envrc` 文件中的环境变量，完全消除手动 export 的需求。

#### 快速开始

1. **安装 direnv**:
   ```bash
   # macOS
   brew install direnv

   # Linux
   sudo apt-get install direnv
   ```

2. **配置 Shell Hook** (添加到 `~/.bashrc` 或 `~/.zshrc`):
   ```bash
   eval "$(direnv hook bash)"  # for bash
   eval "$(direnv hook zsh)"   # for zsh
   ```

3. **启用 .envrc**:
   ```bash
   cd msp-ios-sdk
   direnv allow
   ```

4. **完成！** 现在每次 cd 进入目录，环境变量自动加载：
   ```bash
   cd msp-ios-sdk
   # ✅ 环境变量自动加载！

   ./Scripts/msp-release.sh resume
   # 不需要任何 export！
   ```

详细配置说明请查看 [DIRENV_SETUP.md](DIRENV_SETUP.md)

---

### 传统方式: 手动设置环境变量

如果你不想使用 direnv，也可以手动设置环境变量：

Only **2 variables** required for production release:
- `DRY_RUN=false` - Enable production mode
- `MSP_ALLOW_TRUNK_PUSH=1` - Allow CocoaPods push

**Profile-based setup** (recommended):
```bash
./Scripts/msp-release.sh --profile=production run <version>
```

**Configuration Profiles**:
- `local` - Local release (default)
- `ci` - CI/CD release
- `rerelease` - Republish existing version
- `test` - Test mode (no actual push)

Use the setup script:
```bash
source Scripts/utils/setup-release-env.sh <profile>
```

### Slack Notifications

**Option 1: Local config file** (recommended for development):
```bash
cp Scripts/config/slack.conf.example Scripts/config/slack.conf
# Edit slack.conf and fill in your credentials
```

**Option 2: Environment variables** (recommended for CI):
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export MSP_SLACK_ALERT_ENV="test"  # or "prod"
```

### Release Commands

```bash
# Basic release
./Scripts/msp-release.sh run <version>

# Fix public remote tag (if GitHub Push Protection blocks)
./Scripts/msp-release.sh fix-public-tag <version>

# Dry run (test without publishing)
DRY_RUN=true ./Scripts/msp-release.sh run <version>
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Release tier cannot be executed locally" | Set `MSP_ALLOW_LOCAL_RELEASE=1` |
| "trunk push disabled" | Set `MSP_ALLOW_TRUNK_PUSH=1` |
| "Tag already exists" | Use `rerelease` profile or set `MSP_ALLOW_EXISTING_TAG=1` |
| Tag SHA mismatch | Run `./Scripts/msp-release.sh fix-public-tag <version>` |
| GitHub Push Protection blocks push | Visit URL in error, allow secret, then run fix-public-tag |

**For detailed documentation**, see [Scripts/README.md](Scripts/README.md).

---

## 13. Contact

**Email:** pengyu.gou@newsbreak.com  
**GitHub Issues:** [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public/issues)
