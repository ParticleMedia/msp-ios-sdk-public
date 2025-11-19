# MSP iOS SDK

Modular advertising SDK for iOS that ships multiple adapters, shared libraries, and a dual‑integration demo app. The demo application is generated entirely from Xcodegen specs so CocoaPods and Swift Package Manager paths can be validated without hand‑editing Xcode projects.

---

## How to Use the DemoApp

The DemoApp validates both CocoaPods and Swift Package Manager integrations. Choose the target that matches your integration method.

### Quick Start

**1. Clone and setup:**
```bash
git clone <repo-url>
cd msp-ios-sdk
bundle install
brew install xcodegen
```

**2. Choose your target:**

**Option A: Swift Package Manager (SPM)**
```bash
./Scripts/target-switching/switch-target.sh spm
```
This will:
- Clean CocoaPods artifacts
- Generate YAML specs (project.yml, workspace.yml) for SPM mode
- Validate environment
- Open Xcode

**Option B: CocoaPods**
```bash
./Scripts/target-switching/switch-target.sh pods
```
This will:
- Clean SwiftPM artifacts
- Install CocoaPods dependencies
- Generate YAML specs (project.yml, workspace.yml) for Pods mode
- Validate wrappers
- Open Xcode

> **Important:** Target switching **only modifies YAML files** (`project.yml`, `workspace.yml`). Xcode project files (`.pbxproj`, `.xcscheme`) are **never modified** by switching. If you need to regenerate Xcode projects from YAML, run `xcodegen generate` manually.

### Running the DemoApp

Once Xcode opens, select the appropriate scheme:

| Scheme | Target | Purpose |
|--------|--------|---------|
| `MSPDemoApp-SPM` | MSPDemoApp-SPM | Validates all local Swift packages |
| `MSPDemoApp` | MSPDemoApp | Validates adapters linked through CocoaPods |

**Build and run:**
- Press `⌘R` or select **Product → Run** in Xcode
- Or use command line:
  ```bash
  # SPM target
  xcodebuild \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme MSPDemoApp-SPM \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    SKIP_CODE_SIGN=YES \
    build

  # CocoaPods target
  xcodebuild \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme MSPDemoApp \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    SKIP_CODE_SIGN=YES \
    test
  ```

### Requirements

| Tool | Version | Installation |
|------|---------|--------------|
| Xcode | 15.2+ | App Store or developer.apple.com |
| Xcodegen | 2.38.0+ | `brew install xcodegen` |
| Ruby | 3.0+ with Bundler | `bundle install` |
| CocoaPods | 1.14+ | Required for adapter dependencies |

> **Important:** 
> - Never edit `MSPDemoApp.xcodeproj` or `msp-ios-sdk.xcworkspace` manually—they are generated artifacts.
> - Never commit `.pbxproj` or `.xcscheme` files—they are generated from YAML specs.
> - Target switching only modifies YAML files—Xcode projects are not regenerated automatically.
> - To regenerate Xcode projects: run `xcodegen generate` after switching targets.

---

## How to Build & Release the SDK

The SDK supports both CocoaPods and Swift Package Manager distributions. Both must be built and validated before any release.

### Building XCFrameworks

Wrapper XCFrameworks are required for SPM builds. Build them all at once:

```bash
./Scripts/xcframeworks/build-all.sh
```

This script:
- Cleans temporary build directories
- Builds all wrapper xcframeworks (Shimmer, FBAudienceNetwork, IronSource, etc.)
- Verifies all xcframeworks exist and are valid

### Pre-Release Checklist

Before releasing a new version, verify:

1. **Both targets build successfully:**
   ```bash
   # Test SPM target
   ./Scripts/target-switching/switch-target.sh spm
   # Build in Xcode: Product → Build (⌘B)

   # Test CocoaPods target
   ./Scripts/target-switching/switch-target.sh pods
   # Build in Xcode: Product → Build (⌘B)
   ```

2. **Run validation scripts:**
   ```bash
   ./Scripts/validation/script-path-lint.sh
   ./Scripts/xcframeworks/validate-wrappers.sh
   ./Scripts/validation/sdk-package-size.sh
   ```

3. **Regenerate Xcode projects (if needed):**
   ```bash
   xcodegen generate
   bundle exec pod install  # Only needed for CocoaPods target
   ```

### Releasing via Jenkins

**CocoaPods Release:**
1. Open Jenkins pipeline: `Jenkinsfile.cocoapods`
2. Provide:
   - `VERSION` – semantic version (e.g., `1.2.3`)
   - `PODS_SPECS_REPO` – SSH URL for private spec repo (defaults to `git@github.com:ParticleMedia/private-specs.git`)
3. Pipeline automatically:
   - Lints all podspecs (warnings fail the build)
   - Builds all frameworks
   - Pushes to CocoaPods repo
   - Creates git tags

**SPM Release:**
1. Open Jenkins pipeline: `Jenkinsfile.spm`
2. Provide `VERSION` (optional, only if tagging)
3. Pipeline automatically:
   - Validates Swift Package Manager distribution
   - Builds MSPDemoApp-SPM scheme
   - Creates git tags (if version provided)

### Releasing via GitHub Actions

The `.github/workflows/release.yml` workflow handles:
- Building production frameworks
- Validating CocoaPods specs
- Creating GitHub releases
- Publishing to CocoaPods (optional)

Trigger via GitHub Actions UI with:
- `pod_name`: Adapter name to release
- `version`: Semantic version
- `skip_cocoapods`: Set to `true` to skip CocoaPods publish

### Version Bump Workflow

1. Update version in:
   - All `*.podspec` files
   - All `Package.swift` files
   - `CHANGELOG.md` (if applicable)

2. Commit changes:
   ```bash
   git add -A
   git commit -m "chore: bump version to X.Y.Z"
   ```

3. Create release branch (optional):
   ```bash
   git checkout -b release/X.Y.Z
   ```

4. Run pre-release checklist (above)

5. Push and trigger Jenkins/GitHub Actions

---

## Target Switching Framework

The repository includes a Target Switching Framework that safely switches between CocoaPods and Swift Package Manager environments. **Switching only modifies YAML spec files**—Xcode project files are never touched, ensuring zero-diff switching.

### How It Works

Target switching:
1. **Only modifies YAML files** (`project.yml`, `workspace.yml`)
2. **Never modifies Xcode files** (`.pbxproj`, `.xcscheme`, workspace contents)
3. **Is fully deterministic**—round-trip switching produces identical YAML files
4. **Does not run xcodegen**—you must run `xcodegen generate` manually if needed

### Quick Commands

**Switch to SPM:**
```bash
./Scripts/target-switching/switch-target.sh spm
# Then optionally: xcodegen generate
```

**Switch to CocoaPods:**
```bash
./Scripts/target-switching/switch-target.sh pods
# Then optionally: xcodegen generate
```

**Validate environment:**
```bash
./Scripts/target-switching/switch-target-validator.sh
```

### Zero-Diff Guarantee

After switching targets, `git diff` will show:
- ✅ Changes in `project.yml` and `workspace.yml` (expected)
- ❌ **NO changes** in `.pbxproj`, `.xcscheme`, or workspace files

Round-trip switching (spm → pods → spm) produces **identical YAML files**—fully deterministic.

### When to Switch

- When testing both package managers
- When updating wrappers or Pods
- When preparing a release
- When debugging environment-specific issues

### Best Practices

- Always use `switch-target.sh` to change environments
- Commit or stash changes before switching
- Run `xcodegen generate` after switching if you need fresh Xcode projects
- Validate after switching: `./Scripts/target-switching/switch-target-validator.sh`
- Never commit generated xcframeworks or Xcode project files
- Use CI to verify both environments build

---

## Troubleshooting

### Build Errors

**"binary target could not be mapped" errors:**
```bash
# Check for tracked xcframeworks (should output nothing)
git ls-files | grep xcframework

# Rebuild xcframeworks
./Scripts/target-switching/build-xcframeworks.sh
```

**Build errors after switching targets:**
```bash
# Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Regenerate Xcode projects from YAML
xcodegen generate

# If still failing, clean and re-switch
./Scripts/target-switching/cleanup_spm.sh --force
./Scripts/target-switching/cleanup_pods.sh
./Scripts/target-switching/switch-target.sh [spm|pods]
xcodegen generate
```

### Xcode Cache Issues

**Duplicate GUID errors:**
```bash
./Scripts/cleanup-swiftpm-caches.sh
```

**Stale workspace or project:**
```bash
# Regenerate from YAML specs
xcodegen generate

# For CocoaPods target, also run:
bundle exec pod install
```

### SPM/Pods Conflicts

**Mixed environment detected:**
```bash
# Validate environment
./Scripts/target-switching/switch-target-validator.sh

# If validation fails, clean everything and re-switch
./Scripts/target-switching/cleanup_spm.sh --force
./Scripts/target-switching/cleanup_pods.sh
./Scripts/target-switching/switch-target.sh [spm|pods]
xcodegen generate  # Regenerate Xcode projects if needed
```

**Package resolution errors:**
```bash
# For SPM
swift package reset
swift package resolve

# For CocoaPods
bundle exec pod deintegrate
bundle exec pod install
```

---

## Repository Scripts

| Script | Purpose |
|-------|---------|
| `Scripts/target-switching/switch-target.sh` | Switch between CocoaPods and SPM environments |
| `Scripts/workspace/update.sh` | Regenerate project/workspace specs and SwiftPM metadata |
| `Scripts/xcframeworks/build-all.sh` | Build all wrapper xcframeworks |
| `Scripts/xcframeworks/validate-wrappers.sh` | Validate all wrapper packages |
| `Scripts/validation/script-path-lint.sh` | Validate script paths and ROOT_DIR usage |
| `Scripts/validation/sdk-package-size.sh` | Check SDK package size against baseline |
| `Scripts/cleanup-swiftpm-caches.sh` | Clean SwiftPM caches and DerivedData |

For detailed script documentation, see `Scripts/README.md`.

---

## Appendix

### Workspace Generation

The workspace is generated from YAML specs using Xcodegen. Target switching automatically updates YAML files, but you must manually regenerate Xcode projects:

```bash
# After switching targets, regenerate Xcode projects:
xcodegen generate

# For CocoaPods target, also run:
bundle exec pod install
```

**YAML Generation:**
- `project.yml` and `workspace.yml` are auto-generated by `switch-target.sh`
- YAML files are deterministic—round-trip switching produces identical files
- YAML files are the **single source of truth** for project configuration

**Xcode Project Generation:**
- Xcode projects (`.xcodeproj`) are generated from YAML using `xcodegen generate`
- Xcode projects are **never modified** by target switching
- Xcode projects should **never be committed** to git

### CI/CD Integration

**GitHub Actions:**
- `.github/workflows/demoapp-dual.yml` – Builds both targets on every PR
- `.github/workflows/release.yml` – Handles releases and publishing

**Jenkins Pipelines:**
- `Jenkinsfile.cocoapods` – CocoaPods release pipeline
- `Jenkinsfile.spm` – SPM validation and release pipeline
- `Jenkinsfile.demoapp` – Demo app build and artifact export

All pipelines use the same script workflow as local development to avoid drift.

### Package Validation

Validate individual Swift packages:

```bash
for pkg in MSPCore MSPSharedLibraries MSPOMSDK PrebidAdapter NovaAdapter NovaCore MSPGoogleAdapter MSPFacebookAdapter MSPiOSCore; do
  (cd "$pkg" && swift build --configuration release)
done
```

### Additional Documentation

- `Docs/DemoAppIntegration.md` – Dual-target integration details and troubleshooting
- `fastlane/README.md` – Fastlane lanes for CI/release automation
- `Scripts/README.md` – Detailed script documentation

### Contribution Checklist

1. Switch to your target: `./Scripts/target-switching/switch-target.sh [spm|pods]`
2. Regenerate Xcode projects: `xcodegen generate`
3. For CocoaPods target: `bundle exec pod install`
4. Build/test both demo app schemes (`MSPDemoApp` and `MSPDemoApp-SPM`)
5. Commit only source/spec files—**never commit** `.pbxproj`, `.xcscheme`, or generated workspace files
6. Verify zero-diff switching: run round-trip test and confirm only YAML files change
7. Submit pull requests with build logs for both schemes
