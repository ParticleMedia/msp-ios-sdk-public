# MSP iOS SDK

Modular advertising SDK for iOS that ships multiple adapters, shared libraries, and a dual‑integration demo app. The demo application is generated entirely from Xcodegen specs so CocoaPods and Swift Package Manager paths can be validated without hand‑editing Xcode projects.

## Requirements

| Tool | Version | Notes |
| ---- | ------- | ----- |
| Xcode | 15.2+ | Install from App Store or developer.apple.com |
| Xcodegen | 2.38.0+ | `brew install xcodegen` |
| Ruby | 3.0+ with Bundler | run `bundle install` |
| CocoaPods | 1.14+ | required for adapter dependencies |

## Initial Setup

```bash
git clone <repo-url>
cd msp-ios-sdk
bundle install
brew install xcodegen          # or brew upgrade xcodegen
```

## Workspace Generation Workflow

1. **Regenerate specs / workspace**
   ```bash
   ./Scripts/update-workspace.sh
   ```
   - Scans every `Package.swift`.
   - Rewrites `MSPDemoApp/project.yml`, `workspace.yml`, and `msp-ios-sdk.xcworkspace/xcshareddata/swiftpm/local-packages.json`.
   - Runs `xcodegen generate` when available.
2. **Install Pods (outside the sandbox)**
   ```bash
   bundle exec pod install
   ```
   Run on your Mac or on GitHub Actions runners; the Codex sandbox cannot write to CocoaPods caches.
3. **Open the workspace**
   ```bash
   xed msp-ios-sdk.xcworkspace
   ```

> Never edit `MSPDemoApp.xcodeproj` or `msp-ios-sdk.xcworkspace` manually—they are generated artifacts.

## Demo App Schemes

| Scheme | Target | Dependency Stack | Purpose |
| ------ | ------ | ---------------- | ------- |
| `MSPDemoApp` | MSPDemoApp | CocoaPods | Validates adapters linked through Pods. |
| `MSPDemoApp-SPM` | MSPDemoApp-SPM | Swift Package Manager | Validates all local Swift packages. |

Select the scheme that matches the integration you need to validate.

## Build & Test Commands

```bash
# Pods scheme: build + unit/UI tests
xcodebuild \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  SKIP_CODE_SIGN=YES \
  test

# SwiftPM scheme: build only
xcodebuild \
  -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp-SPM \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  SKIP_CODE_SIGN=YES \
  build

# Package validation loop
for pkg in MSPCore MSPSharedLibraries MSPOMSDK PrebidAdapter NovaAdapter NovaCore MSPGoogleAdapter MSPFacebookAdapter MSPiOSCore; do
  (cd "$pkg" && swift build --configuration release)
done
```

## Jenkins Pipelines Overview

Three declarative Jenkins pipelines live at the repo root:

| Jenkinsfile | Purpose |
| ----------- | ------- |
| `Jenkinsfile.cocoapods` | Publishes all CocoaPods (lint → build → repo push → tagging). |
| `Jenkinsfile.spm` | Builds/validates the Swift Package Manager distribution and tags releases. |
| `Jenkinsfile.demoapp` | Builds both demo app schemes, exports unsigned IPAs, and prepares for a future Firebase upload. |

Each pipeline assumes Slack notifications are configured via `Scripts/config/slack.conf` and that Jenkins has access to macOS builders with Xcode 15.4+.

### How to Publish via Jenkins (CocoaPods)

1. Open Jenkins and create a new pipeline pointing to `Jenkinsfile.cocoapods`.
2. Provide:
   - `VERSION` – semantic version used for git tags.
   - `PODS_SPECS_REPO` – SSH URL for the private spec repo (defaults to `git@github.com:ParticleMedia/private-specs.git`).
3. Pipeline stages:
   - Checkout → `bundle install`
   - `./Scripts/update-workspace.sh`
   - `bundle exec pod install`
   - Strict `pod lib lint` over every adapter (warnings fail the build)
   - `./Scripts/build.sh --skip-code-sign`
   - `pod repo push` + git tagging (only if `VERSION` is provided)
4. Slack feedback is delivered on success/failure.

### How to Publish via Jenkins (SPM)

1. Configure a Jenkins pipeline that references `Jenkinsfile.spm`.
2. Supply `VERSION` only when you intend to push release tags.
3. Pipeline stages:
   - Checkout + `bundle install`
   - `./Scripts/update-workspace.sh`
   - `swift package resolve` / `swift build --configuration release`
   - `swift package describe` (graph validation)
   - `xcodebuild ... -scheme MSPDemoApp-SPM`
   - Optional git tagging/push
4. Slack notifications mirror CocoaPods pipeline behavior.

### DemoApp CI Build (Future: Firebase Upload)

`Jenkinsfile.demoapp` builds both demo schemes and exports unsigned IPAs into `artifacts/`. A TODO block marks where Firebase upload logic will be added once credentials are finalized. Artifacts are automatically archived with the Jenkins build for manual distribution/testing.

### Local vs Automated CI

- **Local development**: run `./Scripts/update-workspace.sh`, `bundle exec pod install`, and the build/test commands above.
- **GitHub Actions**: `.github/workflows/demoapp-dual.yml` reproduces the full dual-target build for every PR.
- **Jenkins**: use the new Jenkinsfiles for publishing or demo app artifact creation. All of them rely on the same script workflow used locally to avoid drift.

## Repository Scripts

| Script | Description |
| ------ | ----------- |
| `Scripts/update-workspace.sh` | Generates project/workspace specs, SwiftPM metadata, and (optionally) runs Xcodegen + `pod install`. |
| `Scripts/build.sh`, `buildDemoApp.sh`, etc. | Adapter build/test helpers (see `Scripts/README.md`). |

## Additional Documentation

- `Docs/DemoAppIntegration.md` – Dual-target integration, troubleshooting, validation commands.
- `fastlane/README.md` – Fastlane lanes used by CI/release automation.

## Contribution Checklist

1. Run `./Scripts/update-workspace.sh`.
2. Run `bundle exec pod install` on a macOS host.
3. Build/test both demo app schemes.
4. Commit only source/spec files—generated `.xcodeproj`/`.xcworkspace` files are ignored.
5. Submit pull requests with logs for both schemes.
