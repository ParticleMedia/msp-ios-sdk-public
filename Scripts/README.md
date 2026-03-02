# Scripts Directory

> **Version**: 2.0 (Post feature/002 Refactoring)
> **Last Updated**: 2026-02-26

Automation scripts for MSP iOS SDK development, testing, and release.

## Directory Structure

```
Scripts/
├── msp-release.sh              # Main release orchestrator (entrypoint)
├── switch-target.sh            # Mode switching (pods-dev/pods-release/spm-release)
├── resume-smart.sh             # Smart resume for interrupted releases
│
├── release/                    # Modular release system
│   ├── cli/                    #   CLI interface layer (dispatch, flags, help)
│   ├── orchestrator/           #   Workflow orchestration (phases)
│   │   └── lib/                #     Notification, summary, verification
│   ├── publish/                #   Publishing layer
│   │   ├── pods/               #     CocoaPods publishing
│   │   │   └── lib/            #       13 modular utilities (GitHub Release, zip, podspec, etc.)
│   │   └── spm/                #     SPM publishing
│   │       └── lib/            #       CDN verification, XCFramework zip
│   ├── preflight/              #   Pre-release checks
│   ├── utils/                  #   Shared utilities (state, git, logger, safety)
│   ├── config/                 #   (deprecated - migrated to Scripts/config/)
│   ├── verify/                 #   Verification dispatcher
│   ├── verify-matrix/          #   Multi-target verification (15 cases)
│   ├── verify_local/           #   Local CocoaPods/SPM verification
│   ├── verify_local_device/    #   Device testing
│   ├── verify_remote/          #   Remote verification with fixtures
│   └── verify_xcframework/     #   XCFramework structure validation
│
├── lib/                        # Shared libraries (33 modules)
│   ├── common.sh               #   Common functions
│   ├── path-helpers.sh         #   Path resolution
│   ├── logging.sh              #   Structured logging with phases
│   ├── config_loader.sh        #   YAML config loading
│   ├── cocoapods.sh            #   CocoaPods operations
│   ├── xcode.sh                #   Xcode command wrappers
│   ├── xcodegen.sh             #   XcodeGen operations
│   ├── validation.sh           #   Validation utilities
│   ├── process_utils.sh        #   Process management
│   ├── lock.sh                 #   Cross-platform locking
│   └── shared/                 #   DRY modules shared across release subsystems
│       ├── xcframework_build.sh
│       ├── xcframework_validate.sh
│       ├── github_release.sh
│       ├── cdn_verify.sh
│       ├── input_validation.sh
│       ├── step_lifecycle.sh
│       └── time_utils.sh
│
├── config/                     # Centralized configuration (SSOT)
│   ├── release.yaml            #   Release profiles & module lists
│   ├── build-config.yaml       #   Build settings
│   ├── cocoapods-config.yaml   #   CocoaPods settings
│   ├── ci-framework-deps.yml   #   CI XCFramework dependencies
│   ├── ci-pod-schemes.yml      #   CI pod schemes
│   ├── notify_mapping.yaml     #   Notification channel mapping
│   ├── slack_mapping.yaml      #   Slack channel mapping
│   ├── email_mapping.yaml      #   Email recipient mapping
│
│
├── ci/                         # CI/CD scripts (GitHub Actions / Jenkins)
│   ├── ci_validate.sh          #   Main CI validation
│   ├── ensure-xcodegen.sh      #   Install/check XcodeGen
│   ├── generate-workspace.sh   #   Generate workspace for CI
│   ├── install-pods.sh         #   CocoaPods install
│   ├── prebuild-pod-deps.sh    #   Prebuild Pod schemes
│   ├── lint-podspecs.sh        #   Lint podspecs
│   ├── validate-shell-syntax.sh #  Bash syntax check
│   ├── validate-workspace-schemes.sh # Verify schemes
│   ├── verify-xcframework.sh   #   Verify single XCFramework
│   ├── verify-xcframework-deps.sh #  Verify stage dependencies
│   ├── fix-artifact-paths.sh   #   Fix artifact paths
│   └── jenkins-slack.sh        #   Jenkins Slack notification
│
├── notify/                     # Notification system (Slack + Email)
│   ├── notify_core.sh          #   Core dispatcher
│   ├── slack.sh                #   Slack integration
│   ├── slack_sender.sh         #   Slack HTTP sender
│   ├── email.sh                #   Email integration
│   ├── email_sender.sh         #   Email HTTP sender
│   └── render.sh               #   Rich message rendering
│
├── plugins/                    # Multi-platform plugin system
│   ├── local.sh                #   Local environment
│   ├── github-actions.sh       #   GitHub Actions
│   └── fastlane.sh             #   Fastlane integration
│
├── tools/                      # Developer & AI agent tools
│   ├── get-test-template.sh    #   Print Quick/Nimble test template
│   ├── validate-script.sh      #   Validate script with shellcheck
│   ├── validate-agent-sync.sh  #   Validate AI agent file sync
│   ├── format-all-swift.sh     #   Batch Swift formatting
│   ├── post-process-protobuf.sh #  Add @_implementationOnly to .pb.swift
│   ├── check-project-diff.sh   #   Check project file differences
│   ├── generate-workspace.sh   #   Generate workspace
│   ├── pre-commit-cleanup.sh   #   Pre-commit cleanup
│   ├── test-cases.py           #   Test case management (validate/list)
│   ├── generate-context-index.py # Generate .context/index.json
│   ├── generate-stub-factory.swift # Generate test stub factories
│   ├── migrate-test-cases.py   #   Migrate test cases to YAML
│   └── update_adapter_sdk_version.py # Update adapter SDK versions
│
├── tests/                      # Test infrastructure
│   ├── run-unit-tests.sh       #   Run Swift unit tests (MSPTests scheme)
│   ├── unit/                   #   Shell script unit tests (37 test files)
│   │   ├── run_all.sh          #     Runner
│   │   ├── helpers.sh          #     Test helpers (test_pass/test_fail)
│   │   ├── mock_loader.sh      #     Mock loader
│   │   └── cases/              #     37 test files covering all modules
│   └── release_state/          #   Release state integration tests (18 cases)
│       ├── run_all.sh          #     Runner
│       ├── helpers.sh          #     Test helpers
│       ├── mock/               #     Mock implementations (curl, gh, git, pod, etc.)
│       └── cases/              #     18 test scenarios
│
├── validation/                 # Cross-cutting validation scripts
│   ├── script-path-lint.sh     #   Script path validation
│   ├── sdk-package-size.sh     #   SDK size analysis
│   ├── source-parity.sh        #   Pods/SPM parity check
│   ├── validate_assets.sh      #   Asset validation
│   └── verify_pods_spm_consistency.sh # Consistency check
│
├── xcframeworks/               # XCFramework build scripts
│   ├── build-all.sh            #   Build all frameworks
│   ├── build-core.sh           #   Build core XCFrameworks
│   ├── build-adapters.sh       #   Build adapter XCFrameworks
│   ├── build-thirdparty.sh     #   Build third-party XCFrameworks
│   ├── builder.sh              #   Builder wrapper
│   ├── build_module.sh         #   Module builder
│   ├── internal/               #   Internal builders (MSPCore, iOSCore, Nova)
│   └── wrappers/               #   Third-party adapter wrapper builders (7)
│
├── testflight/                 # TestFlight deployment
│   ├── deploy.sh               #   Main orchestrator (entrypoint)
│   ├── config.yaml             #   Build number + app config (SSOT)
│   ├── lib/                    #   Modular pipeline stages
│   │   ├── config.sh           #     Config loader + build number management
│   │   ├── validate.sh         #     Pre-flight checks (tools, credentials, workspace)
│   │   ├── archive.sh          #     xcodebuild archive (signed .xcarchive)
│   │   ├── export.sh           #     xcodebuild -exportArchive (IPA)
│   │   └── upload.sh           #     fastlane pilot upload to ASC
│   └── templates/
│       └── ExportOptions.plist #   Export options for App Store distribution
│
├── target-switching/           # Mode switching internals
│   ├── common.sh               #   Shared constants
│   ├── round-trip-test.sh      #   Mode switching validation
│   ├── generate_workspace.sh   #   Workspace generation
│   └── *.sh                    #   Cleanup, validation helpers
│
├── workspace/                  # Workspace management
│   └── update.sh               #   Workspace update script
│
├── context/                    # Context knowledge management
│   ├── add-context.sh          #   Add context entries
│   ├── validate-context.sh     #   Validate context
│   ├── list-context.sh         #   List contexts
│   ├── search-context.sh       #   Search contexts
│   ├── archive-context.sh      #   Archive contexts
│   ├── init-context.sh         #   Initialize context system
│   └── common.sh               #   Common utilities
│
├── spm/                        # SPM management
│   └── sync_thirdparty_pods.sh #   Sync ThirdParty from Pods
├── spm-sync/                   # Pods to SPM sync
│   ├── spm_sync_all.sh         #   Sync all dependencies
│   ├── extract_from_pods.sh    #   Extract frameworks from Pods
│   └── generate_package_swift.sh # Generate Package.swift
│
├── environment/                # Environment setup
│   └── setup-spm.sh            #   SPM environment setup
├── demoapp/                    # Demo app configuration
│   └── configure.sh            #   Configure demo app
├── git/                        # Git utilities
│   └── pre-commit.sh           #   Pre-commit hook
├── git-hooks/                  # Git hooks (legacy, see .husky/)
├── headers/                    # Bridging headers for testing
├── templates/                  # Shared templates
│   └── release-notes-template.md
└── utils/                      # Misc utilities
    └── setup-release-env.sh    #   Release environment setup
```

## Release System Architecture

### Entrypoints

| Script | Purpose |
|--------|---------|
| `msp-release.sh` | Main release orchestrator with subcommands |
| `switch-target.sh` | Switch between development modes |
| `testflight/deploy.sh` | TestFlight deployment (archive → export → upload) |

### Subcommands

```bash
./Scripts/msp-release.sh <subcommand> [options]
```

| Subcommand | Description |
|------------|-------------|
| `run <version>` | Execute full release |
| `resume [version]` | Resume interrupted release from state file |
| `create-github-releases <version>` | Create/verify GitHub Releases for all binary pods |
| `fix-public-tag <version>` | Push tag to public remote |
| `verify <version>` | Run verification suite |
| `verify-matrix` | Run multi-target verification |
| `rollback [--force]` | Rollback failed release |
| `preflight` | Run pre-release checks only |
| `pods <version>` | CocoaPods-only release |
| `spm <version>` | SPM-only release |
| `config` | Show effective configuration |
| `env [--show]` | Show environment variables |

### Common Options

| Option | Description |
|--------|-------------|
| `--profile=<name>` | Select release profile (`production`, `local-dev`, `quick-test`) |
| `--full` | Force full mode (auto for production) |
| `--only-pods` | Run CocoaPods release only |
| `--only-spm` | Run SPM release only |

### Release Flow (Modular Architecture)

```
msp-release.sh (entrypoint)
    │
    ├── cli/dispatch.sh (command routing)
    │   └── parse subcommand and flags
    │
    ├── orchestrator/modular.sh (workflow coordination)
    │   │
    │   ├── Preflight checks
    │   │   └── preflight/preflight.sh
    │   │
    │   ├── Build XCFrameworks
    │   │   └── xcframeworks/build-*.sh
    │   │
    │   ├── Tag & Push
    │   │   ├── utils/git.sh (create tag)
    │   │   ├── Push to origin
    │   │   └── Push to public
    │   │
    │   ├── GitHub Release
    │   │   ├── publish/pods/lib/github_release_ext.sh
    │   │   │   ├── Create release (per pod)
    │   │   │   ├── Upload XCFramework ZIPs
    │   │   │   └── Update state (github_release_created=true)
    │   │   │
    │   │   └── publish/pods/lib/github_release_verify.sh
    │   │       └── Unified verification (all binary pods)
    │   │
    │   ├── CocoaPods Publishing
    │   │   └── publish/pods/publish.sh
    │   │       ├── Generate podspecs (with per-pod resource_bundles)
    │   │       ├── Push to Trunk (dependency order)
    │   │       └── Per-pod state tracking
    │   │
    │   └── Verification
    │       └── verify/verify.sh
    │
    └── State Management
        └── utils/state.sh (.msp-release-state.json)
            ├── Per-pod trunk_verified tracking
            ├── Per-pod github_release_created tracking (v3)
            └── Resume support
```

See [Scripts/release/README.md](release/README.md) for detailed architecture documentation.

### Release Artifacts (Canonical Paths)

All build outputs are consolidated under:

```
Build/ReleaseArtifacts/
├── XCFrameworks/   # Built XCFrameworks (core/adapters/third-party)
├── Archives/       # Xcode archives
├── Binary/         # Release staging (Binary/ inside pod zip)
└── Zips/           # Release zip outputs
```

### Pod-Specific Release Handling

MSPCore has special handling in the release pipeline:
- **generate_podspec.sh**: Generates `resource_bundles` (not just `vendored_frameworks`) so `Config.plist` is accessible via `MSPCoreResources.bundle`
- **zip_management.sh**: Includes `Resources/Config.plist` alongside `MSPCore.xcframework` in the release zip
- This ensures `getMSPVersion()` works in both dev mode (via `resource_bundles` in podspec) and release mode (via `Config.plist` bundled in zip)

## Test Infrastructure

### Shell Script Unit Tests

37 unit test files in `Scripts/tests/unit/cases/`:

```bash
# Run all unit tests
./Scripts/tests/unit/run_all.sh

# Run specific test
bash Scripts/tests/unit/cases/zip_management_test.sh
```

Coverage includes: config loading, logging, state management, pod publishing, GitHub release, version management, zip management, podspec generation, input validation, CDN verification, checksum, time utils, and more.

### Release State Integration Tests

18 integration test scenarios in `Scripts/tests/release_state/cases/`:

```bash
./Scripts/tests/release_state/run_all.sh
```

Tests cover: state creation, resume logic, rollback, Slack notifications, mode switching, pods-only/spm-only releases.

### Swift Unit Tests

```bash
# Run Swift unit tests (Quick/Nimble)
./Scripts/tests/run-unit-tests.sh
```

Default scheme: `MSPTests`

## Configuration System

### Profile System

Profiles configure release behavior via `Scripts/config/release.yaml`:

| Profile | DRY_RUN | Mode | Description |
|---------|---------|------|-------------|
| `production` | false | full (auto) | Full release with verification |
| `local-dev` | true | simple | Local testing, no publishing |
| `quick-test` | true | simple | Quick validation only |

```bash
./Scripts/msp-release.sh run --profile=local-dev 1.0.0
./Scripts/msp-release.sh env --show  # inspect effective config
```

### Environment Variable Overrides

| Variable | Config Path | Notes |
|----------|-------------|-------|
| `DRY_RUN` | `profiles.{profile}.dry_run` | Boolean |
| `MSP_LOG_LEVEL` | `profiles.{profile}.logging.level` | debug/info/warn/error |
| `MSP_ALLOW_EXISTING_TAG` | `profiles.{profile}.safety.allow_existing_tag` | Boolean |
| `MSP_PARALLEL_BUILDS` | `profiles.{profile}.performance.parallel_builds` | Boolean |
| `MSP_CDN_WAIT_TIME` | `profiles.{profile}.performance.cdn_wait_time` | Seconds |

## State Management

Release state is persisted to `.msp-release-state.json` (Schema v3):

- Step completion tracking
- Per-pod publishing progress (status, trunk_verified, github_release_created)
- Resume support with intelligent retry

### DRY_RUN Behavior

When `DRY_RUN=true`:
- Git operations execute but don't push
- CocoaPods Trunk push is skipped
- GitHub Release creation is skipped
- All validation still runs

## Notification System

Multi-channel notification framework in `Scripts/notify/`:

| Channel | File | Features |
|---------|------|----------|
| Slack | `slack.sh` + `slack_sender.sh` | Block Kit, DM override, test mode |
| Email | `email.sh` + `email_sender.sh` | HTML templates |

Configuration via `Scripts/config/notify_mapping.yaml` and profile-based settings.

## TestFlight Deployment

Automated TestFlight deployment pipeline for MSPDemoApp in `Scripts/testflight/`.

### Usage

```bash
# Dry run — archive + export only (no ASC credentials needed)
./Scripts/testflight/deploy.sh --dry-run

# Full deploy — archive + export + upload to App Store Connect
./Scripts/testflight/deploy.sh

# Override build number
./Scripts/testflight/deploy.sh --build-number 42
```

### Pipeline Stages

```
deploy.sh (entrypoint)
    │
    ├── validate.sh     — Pre-flight checks (tools, credentials, workspace)
    ├── config.sh       — Load config.yaml, compute next build number
    ├── version.sh      — Read SDK version from SSOT (sdk_version.conf)
    ├── archive.sh      — xcodebuild archive (signed .xcarchive)
    ├── export.sh       — xcodebuild -exportArchive (IPA)
    ├── upload.sh       — fastlane pilot upload to App Store Connect
    └── config.sh       — Commit build number bump to config.yaml
```

### Configuration

`Scripts/testflight/config.yaml` is the SSOT for build number and app settings:

| Field | Description |
|-------|-------------|
| `build_number` | Auto-incremented after each successful upload |
| `app.scheme` | Xcode scheme (`MSPDemoApp`) |
| `app.workspace` | Workspace path |
| `app.bundle_id` | App bundle identifier |
| `signing.team_id` | Apple Developer Team ID |

### Version Injection

| Build Setting | Source | Description |
|---------------|--------|-------------|
| `MARKETING_VERSION` | `Scripts/config/sdk_version.conf` (SSOT) | App version (e.g., `3.1.7`) |
| `CURRENT_PROJECT_VERSION` | `Scripts/testflight/config.yaml` | Build number (e.g., `2`) |

### Environment Variables (Upload Only)

Required for full deploy (not needed for `--dry-run`):

| Variable | Description |
|----------|-------------|
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_KEY_PATH` | Path to AuthKey `.p8` file |

**Setup (recommended):** Copy the `.env` template and fill in your credentials:

```bash
cp Scripts/testflight/.env.example Scripts/testflight/.env
# Edit Scripts/testflight/.env with your ASC credentials
```

The `.env` file is gitignored and loaded automatically by `deploy.sh`. Existing environment variables take precedence over `.env` values. Alternatively, `direnv` users can uncomment the ASC section in `.envrc.example`.

Without ASC credentials, `--dry-run` uses local Keychain for code signing.

## Shared Tools (AI Agents)

The `tools/` directory contains scripts shared across all AI agents (Claude, Cursor, Copilot, Codex).

| Tool | Description |
|------|-------------|
| `get-test-template.sh` | Print Quick/Nimble unit test template |
| `validate-script.sh` | Validate shell script with shellcheck |
| `validate-agent-sync.sh` | Validate AI agent file sync (.claude/ vs .agents-shared/) |
| `format-all-swift.sh` | Batch format all Swift files |
| `post-process-protobuf.sh` | Add `@_implementationOnly` to protoc-generated .pb.swift |
| `check-project-diff.sh` | Check project file differences |
| `generate-workspace.sh` | Generate workspace |
| `pre-commit-cleanup.sh` | Pre-commit cleanup |
| `test-cases.py` | Test case management (validate YAML, list cases) |
| `generate-context-index.py` | Generate `.context/index.json` from entries |
| `generate-stub-factory.swift` | Generate test stub factories |
| `migrate-test-cases.py` | Migrate test cases to YAML format |
| `update_adapter_sdk_version.py` | Update adapter SDK versions |

### Adding New Tools

1. Create script in `Scripts/tools/`
2. Add `set -euo pipefail` at the top
3. Make executable: `chmod +x Scripts/tools/<name>.sh`
4. Document in this file and `AGENTS.md`

## Validation Scripts

Cross-cutting validation in `Scripts/validation/`:

| Script | Purpose |
|--------|---------|
| `script-path-lint.sh` | Validate script paths conform to conventions |
| `sdk-package-size.sh` | Analyze SDK binary size |
| `source-parity.sh` | Check Pods/SPM source parity |
| `validate_assets.sh` | Validate asset integrity |
| `verify_pods_spm_consistency.sh` | Verify Pods/SPM consistency |

## Context Management

Knowledge base management scripts in `Scripts/context/`:

```bash
# Add a new context entry
./Scripts/context/add-context.sh

# Validate all context entries
./Scripts/context/validate-context.sh

# List context entries
./Scripts/context/list-context.sh

# Search context
./Scripts/context/search-context.sh <keyword>
```

## Advanced Commands

### Verify Matrix

Run verification across multiple configurations (15 test cases):

```bash
./Scripts/msp-release.sh verify-matrix
```

### Round-Trip Test

Validate mode switching consistency:

```bash
./Scripts/target-switching/round-trip-test.sh
./Scripts/target-switching/round-trip-test.sh --loops=3
./Scripts/target-switching/round-trip-test.sh --skip-build
```

### Build XCFrameworks

```bash
./Scripts/xcframeworks/build-all.sh      # Build everything
./Scripts/xcframeworks/build-core.sh     # Build core modules
./Scripts/xcframeworks/build-adapters.sh # Build adapters
./Scripts/xcframeworks/build-thirdparty.sh # Build third-party
```

### SPM Sync

```bash
./Scripts/spm-sync/spm_sync_all.sh        # Sync all from Pods to SPM
./Scripts/spm/sync_thirdparty_pods.sh     # Sync ThirdParty XCFrameworks
```

## Script Dependencies

Required tools:
- `xcodegen` - Xcode project generation
- `cocoapods` - Pod management
- `gh` - GitHub CLI (for releases)
- `jq` - JSON processing
- `shellcheck` - Shell script validation
- `yq` - YAML processing (for config)
- `python3` - For test-cases.py, context index generation

## TODO

- Re-enable post-release verification once SPM local build issues are resolved. Note: `--profile=production` automatically activates full mode (includes verification). Other profiles default to simple mode (skips Phase 4 verification).
- Re-enable CI-only restriction for production releases when CI pipeline is ready (`Scripts/release/utils/safety.sh`).
- **[CI Integration]** When Jenkins CI pipeline is ready, set `safety.require_ci: true` in `Scripts/config/release.yaml` production profile.
