# MSP iOS SDK — Release System Analysis & Refactoring Proposal

> **Date**: November 27, 2025  
> **Audience**: Engineers refactoring the release system  
> **Status**: Analysis Complete — Ready for Implementation Planning

---

## 1. Scripts Inventory

### Directory Tree

```text
Scripts/
├── build/
│   ├── demo-app.sh              # Build DemoApp
│   ├── test.sh                  # Run tests
│   └── unified.sh               # Unified build entrypoint
├── ci/
│   ├── ci_validate.sh           # ⭐ CI validation pipeline (Pods + SPM)
│   ├── jenkins-slack.sh         # Jenkins Slack integration
│   ├── test-release-notes.sh    # Release notes testing
│   └── test-slack.sh            # Slack notification testing
├── config/
│   ├── build.conf               # Build configuration
│   ├── environments.conf        # Environment settings
│   ├── frameworks.conf          # Framework definitions
│   ├── slack.conf               # Slack credentials (gitignored)
│   └── slack.conf.example       # Slack config template
├── lib/                         # ⭐ Shared libraries
│   ├── asset_sync.sh            # Asset synchronization
│   ├── asset_validation.sh      # Asset validation
│   ├── ci.sh                    # CI helpers
│   ├── cocoapods.sh             # ⭐ CocoaPods operations
│   ├── colors.sh                # Terminal colors
│   ├── common.sh                # ⭐ Core utilities
│   ├── demo_app_builder.sh      # DemoApp build logic
│   ├── framework_config.sh      # Framework configuration
│   ├── logging.sh               # Logging utilities
│   ├── paths.sh                 # Path constants
│   ├── release-common.sh        # ⭐ Release utilities + Slack + Notifications
│   ├── ui.sh                    # UI/formatting utilities
│   ├── validation-helpers.sh    # Validation helpers
│   ├── validation.sh            # Validation logic
│   ├── wrapper-config.sh        # Wrapper configuration
│   ├── xcframework_builder.sh   # XCFramework building
│   └── xcode.sh                 # Xcode utilities
├── release/                     # ⭐ Release entrypoints
│   ├── cocoapods.sh             # CocoaPods release pipeline
│   ├── create-branch.sh         # Release branch creation
│   ├── modular.sh               # ⭐ Main orchestrator
│   └── spm.sh                   # SPM release pipeline
├── spm-sync/                    # ⭐ Pods → XCFramework → SPM sync
│   ├── extract_from_pods.sh     # Extract XCFrameworks from Pods
│   ├── generate_package_swift.sh # Generate Package.swift
│   └── spm_sync_all.sh          # ⭐ Orchestrate sync pipeline
├── target-switching/            # ⭐ Pods ↔ SPM mode switching
│   ├── build-xcframeworks.sh    # Build XCFrameworks
│   ├── cleanup_pods.sh          # Clean Pods environment
│   ├── cleanup_spm.sh           # Clean SPM environment
│   ├── common.sh                # Switching utilities
│   ├── generate_workspace.sh    # Generate workspace/project YAML
│   ├── round-trip-test.sh       # ⭐ Round-trip build validation
│   ├── switch-target-validator.sh # Validate switching
│   ├── switch-target.sh         # ⭐ Main switching script
│   ├── validate_environment.sh  # Environment validation
│   └── validate_xcframeworks.sh # XCFramework validation
├── templates/
│   └── release-notes-template.md # Release notes template
├── xcframeworks/                # XCFramework building
│   ├── build_module.sh
│   ├── build-adapters.sh
│   ├── build-all.sh
│   ├── build-core.sh
│   ├── builder.sh
│   ├── fix_modulemap.sh
│   ├── generate-wrappers.sh
│   ├── validate_xcframework.sh
│   ├── validate-wrappers.sh
│   ├── internal/
│   │   ├── build-ioscore.sh
│   │   ├── build-mspcore.sh
│   │   └── build-nova.sh
│   └── wrappers/
│       ├── build-fbaudiencenetwork.sh
│       ├── build-inmobi.sh
│       └── ... (other wrapper builders)
└── validation/
    ├── script-path-lint.sh
    ├── sdk-package-size.sh
    └── source-parity.sh
```

### Script Classification

| Category | Scripts | Purpose |
|----------|---------|---------|
| **Release Orchestration** | `release/modular.sh` | Main release entrypoint |
| **Release Pipelines** | `release/cocoapods.sh`, `release/spm.sh` | Platform-specific release |
| **Release Utilities** | `release/create-branch.sh` | Git branch management |
| **CI/Validation** | `ci/ci_validate.sh`, `target-switching/round-trip-test.sh` | Build validation |
| **Target Switching** | `target-switching/switch-target.sh` | Pods ↔ SPM mode |
| **Dependency Sync** | `spm-sync/spm_sync_all.sh` | Pods → XCFramework → SPM |
| **Shared Libraries** | `lib/*.sh` | Reusable utilities |
| **Build Infrastructure** | `xcframeworks/*.sh`, `build/*.sh` | Framework building |

### Entrypoints vs Internal Helpers

**Primary Entrypoints (called by humans/CI):**
- `Scripts/release/modular.sh` — Full release orchestration
- `Scripts/ci/ci_validate.sh` — CI validation pipeline
- `Scripts/target-switching/switch-target.sh` — Mode switching
- `Scripts/spm-sync/spm_sync_all.sh` — Dependency synchronization
- `Scripts/target-switching/round-trip-test.sh` — Build validation

**Internal Helpers (called by entrypoints):**
- `Scripts/release/cocoapods.sh` — Called by `modular.sh`
- `Scripts/release/spm.sh` — Called by `modular.sh`
- `Scripts/release/create-branch.sh` — Called by `modular.sh`
- `Scripts/lib/*.sh` — Sourced by all scripts

---

## 2. Responsibilities & Coupling

### `release/modular.sh` — Main Orchestrator

**Responsibilities:**
- Parse CLI arguments (`--dry-run`, `--skip-cocoapods`, `--skip-spm`, etc.)
- Create release branch via `create-branch.sh`
- Invoke CocoaPods release via `release-cocoapods-modular.sh` (note: file is `cocoapods.sh`)
- Invoke SPM release via `release-spm-modular.sh` (note: file is `spm.sh`)
- Push release branch to remote
- Track success/failure arrays
- Print comprehensive summary

**Dependencies:**
- Sources `lib/release-common.sh`
- Calls `release/create-branch.sh`
- Calls `release/cocoapods.sh` (referenced as `release-cocoapods-modular.sh`)
- Calls `release/spm.sh` (referenced as `release-spm-modular.sh`)
- Expects `build.sh` script (for pre-release framework builds)

**Coupling Issues:**
- Hard-codes script paths like `$SCRIPT_DIR/release-cocoapods-modular.sh` but actual file is `cocoapods.sh`
- Tracks `COCOAPODS_SUCCESS`/`COCOAPODS_FAILED` arrays but doesn't actually parse child script output
- Assumes all pods succeeded if command returns 0 (lines 244-246)
- Hard-codes pod list: `"MSPSharedLibraries" "MSPFacebookAdapter" "MSPGoogleAdapter" "NovaAdapter" "AmazonAdapter" "PrebidAdapter" "MSPCore"`

---

### `release/cocoapods.sh` — CocoaPods Release Pipeline

**Responsibilities:**
- Update podspec versions and HTTP zip sources
- Update podspec dependencies
- Update adapter SDK versions in Swift code
- Create GitHub releases and upload zips
- Publish pods to CocoaPods trunk with retry
- Wait for pod availability with exponential backoff
- Release in staged order: MSPSharedLibraries → Adapters (parallel) → MSPCore
- Send Slack notifications
- Commit release changes

**Dependencies:**
- Sources `lib/release-common.sh`
- Sources `lib/cocoapods.sh`
- Uses `gh` CLI for GitHub releases
- Uses `sed` for file manipulation
- Calls `notify_release_success_with_summary`, `notify_release_failure`

**Coupling Issues:**
- Hard-codes adapter list: `"MSPFacebookAdapter" "MSPGoogleAdapter" "NovaAdapter" "AmazonAdapter" "PrebidAdapter"`
- Hard-codes pod release order in `POD_RELEASE_ORDER` (in `release-common.sh`)
- Duplicates podspec manipulation logic (also exists in `release-common.sh`)
- Parallel adapter release uses temp files in `/tmp/msp_parallel_release_$$`
- GitHub repo hard-coded: `ParticleMedia/msp-ios-sdk-public`

---

### `release/spm.sh` — SPM Release Pipeline

**Responsibilities:**
- Update `NovaCore/Package.swift` version
- Update `NovaAdapter/Package.swift` version and dependency
- Create git tags for SPM packages (`NovaCore-$VERSION`, `NovaAdapter-$VERSION`)
- Push tags to remote
- Send Slack notifications

**Dependencies:**
- Sources `lib/release-common.sh`
- Uses `sed` for Package.swift manipulation
- Uses `git tag` and `git push`

**Coupling Issues:**
- Hard-codes SPM packages: only `NovaCore` and `NovaAdapter`
- Assumes Package.swift structure with `let version = "..."`
- Hard-codes GitHub URL in dependency updates

---

### `release/create-branch.sh` — Release Branch Creation

**Responsibilities:**
- Create release branch from base branch
- Delete existing local/remote branch if needed
- Push new branch to remote

**Dependencies:**
- Sources `lib/release-common.sh`
- Uses standard `git` commands

**Coupling Issues:**
- Hard-codes default base branch: `newsbreak_msp_migration_spm_dist`
- No rollback mechanism if branch creation fails after cleanup

---

### `ci/ci_validate.sh` — CI Validation Pipeline

**Responsibilities:**
- Clean Pods and SPM environments
- Run `pod install` and `spm_sync_all.sh`
- Validate XCFrameworks
- Build Pods mode and validate state
- Build SPM mode and validate state
- Run round-trip stress tests
- Return to Pods mode

**Dependencies:**
- Calls `target-switching/cleanup_pods.sh`
- Calls `target-switching/cleanup_spm.sh`
- Calls `spm-sync/spm_sync_all.sh`
- Calls `target-switching/validate_xcframeworks.sh`
- Calls `target-switching/switch-target.sh`
- Calls `target-switching/round-trip-test.sh`
- Uses `xcodebuild` directly

**Coupling Issues:**
- Duplicates logging functions (`log_step`, `log_success`, `log_error`) instead of sourcing `lib/logging.sh`
- Duplicates validation functions (`validate_pods_mode_state`, `validate_spm_mode_state`) with `round-trip-test.sh`
- Hard-codes simulator destination: `iPhone 16`
- Hard-codes workspace/project paths

---

### `lib/release-common.sh` — Shared Release Utilities

**Responsibilities:**
- Define logging functions (with fallbacks)
- Define pod release order (`POD_RELEASE_ORDER`)
- Define dependency mapping (`get_pod_dependencies`)
- Provide retry logic with exponential backoff
- Podspec manipulation helpers
- GitHub release helpers
- **Slack notification system** (full implementation)
- **Release notes generation** (git, template, prompt)
- Config.plist version update

**Coupling Issues:**
- Massive file (~1050 lines) mixing many concerns
- Contains both low-level utilities AND business logic (pod order, dependencies)
- Slack implementation mixed with release logic
- Sources `lib/colors.sh` and `lib/ui.sh` optionally (defensive but complex)
- Hard-codes pod dependency graph

---

### `lib/cocoapods.sh` — CocoaPods Operations

**Responsibilities:**
- Validate CocoaPods environment
- Install/update pods
- Validate and publish podspecs
- Update specs repo
- Check pod availability
- Network troubleshooting with fallbacks
- Cache management

**Dependencies:**
- Sources `lib/common.sh`
- Sources `lib/logging.sh`
- Sources `lib/validation.sh`

**Coupling Issues:**
- Uses `bundle exec` prefix throughout (assumes Bundler)
- Network troubleshooting modifies Podfile (side effect)
- Very long file (~810 lines)

---

## 3. Structural Problems & Pain Points

### A. Responsibility Overlap

1. **Duplicate logging systems**
   - `lib/release-common.sh` defines `log_info`, `log_success`, etc.
   - `ci/ci_validate.sh` redefines the same functions
   - `target-switching/common.sh` has its own logging
   - `target-switching/round-trip-test.sh` has its own logging

2. **Duplicate validation logic**
   - `validate_pods_mode_state()` exists in both:
     - `ci/ci_validate.sh`
     - `target-switching/round-trip-test.sh`
   - Slightly different implementations

3. **Podspec manipulation in multiple places**
   - `release/cocoapods.sh` → `update_podspec_for_release()`
   - `lib/release-common.sh` → `update_podspec_to_zip_format()`
   - Similar but not identical logic

### B. Duplicated Logic

1. **Argument parsing** — Every entrypoint script has its own `parse_arguments()` function with similar patterns

2. **Retry with exponential backoff**
   - `lib/release-common.sh` → `retry_with_backoff()`
   - `lib/cocoapods.sh` → multiple retry loops
   - `release/cocoapods.sh` → `wait_for_pod_availability()` with custom backoff

3. **GitHub release creation**
   - `lib/release-common.sh` → `create_github_release_internal()`
   - `release/cocoapods.sh` → `create_github_release_for_pod()`
   - Nearly identical implementations

4. **Environment detection**
   - `lib/common.sh` → `detect_environment()`
   - `lib/release-common.sh` → `get_environment()`
   - Same logic, different function names

### C. Tight Coupling

1. **Orchestrator knows too much**
   - `modular.sh` hard-codes which pods exist
   - Changes to pod structure require editing multiple files

2. **Script path assumptions**
   - References to `release-cocoapods-modular.sh` but file is `cocoapods.sh`
   - Makes renaming risky

3. **Hard-coded lists everywhere**
   - Pod names in `release-common.sh`, `cocoapods.sh`, `modular.sh`
   - Simulator destinations in `ci_validate.sh`, `round-trip-test.sh`
   - GitHub repo URL in multiple files

### D. Hard-coded Assumptions

| Assumption | Location | Impact |
|------------|----------|--------|
| Base branch = `newsbreak_msp_migration_spm_dist` | `create-branch.sh` | Requires CLI override |
| GitHub repo = `ParticleMedia/msp-ios-sdk-public` | Multiple files | Cannot change without editing |
| Pods = specific list of 7 | `release-common.sh` | Cannot add/remove without editing |
| SPM packages = `NovaCore`, `NovaAdapter` | `spm.sh` | Ignores other packages |
| Simulator = `iPhone 16` | CI scripts | Breaks on older Xcode |

### E. Missing Capabilities

1. **No preflight validation** — Release can start and fail midway
2. **No rollback mechanism** — Partial releases cannot be undone
3. **No resume capability** — Cannot restart from last successful step
4. **No config-driven model** — All settings via CLI flags
5. **Notification system only on final success/failure** — No progress updates
6. **No structured error reporting** — Errors are logged but not aggregated

### F. Maintainability Concerns

1. **`lib/release-common.sh` is 1050+ lines** — Too large to maintain
2. **No unit tests for helper functions**
3. **Inconsistent error handling** — Some scripts use `set -e`, others don't
4. **No documentation of dependencies between scripts**

---

## 4. Proposed Target Structure

### Directory Layout

```text
Scripts/
├── msp-release.sh                    # 🆕 Single unified entrypoint
├── release/
│   ├── orchestrator.sh               # Core orchestration logic
│   ├── preflight.sh                  # 🆕 Pre-release validation
│   ├── pods/
│   │   ├── release.sh                # CocoaPods release pipeline
│   │   ├── publish.sh                # Pod publishing with retry
│   │   ├── podspec.sh                # Podspec manipulation
│   │   └── github.sh                 # GitHub release operations
│   ├── spm/
│   │   ├── release.sh                # SPM release pipeline
│   │   └── tagging.sh                # Git tagging operations
│   ├── config/
│   │   ├── release.yaml              # 🆕 Release configuration
│   │   ├── pods.yaml                 # Pod definitions & dependencies
│   │   └── spm.yaml                  # SPM package definitions
│   └── utils/
│       ├── git.sh                    # Git operations
│       ├── version.sh                # Version manipulation
│       ├── retry.sh                  # Retry/backoff utilities
│       └── state.sh                  # 🆕 State tracking for resume
├── notify/
│   ├── slack.sh                      # Slack notifications
│   ├── dm.sh                         # 🆕 Direct message on failure
│   └── config/
│       └── slack.conf                # Slack configuration
├── lib/                              # Generic utilities (unchanged)
│   ├── common.sh
│   ├── logging.sh
│   ├── colors.sh
│   ├── validation.sh
│   └── ...
├── ci/
│   ├── validate.sh                   # CI validation (refactored)
│   └── preflight.sh                  # 🆕 CI preflight checks
├── spm-sync/                         # (unchanged)
├── target-switching/                 # (unchanged)
└── xcframeworks/                     # (unchanged)
```

### Key Components

#### `msp-release.sh` — Unified Entrypoint

```bash
#!/bin/bash
# Usage:
#   msp-release.sh preflight           # Validate everything before release
#   msp-release.sh run 0.0.3           # Full release
#   msp-release.sh pods 0.0.3          # CocoaPods only
#   msp-release.sh spm 0.0.3           # SPM only
#   msp-release.sh verify 0.0.3        # Verify released version
#   msp-release.sh rollback 0.0.3      # Rollback failed release
#   msp-release.sh resume              # Resume from last checkpoint
```

#### `release/config/release.yaml` — Configuration File

```yaml
version: "0.0.3"
release_branch: "release/0.0.3"
base_branch: "newsbreak_msp_migration_spm_dist"

github:
  repo: "ParticleMedia/msp-ios-sdk-public"
  
notifications:
  slack:
    channel: "#releases"
    dm_on_failure: true
    
pods:
  enabled: true
  parallel_adapters: true
  
spm:
  enabled: true
  packages:
    - NovaCore
    - NovaAdapter
```

#### `release/preflight.sh` — Pre-release Validation

```bash
# Validates:
# 1. Git state (clean working tree, on correct branch)
# 2. All podspecs lint successfully
# 3. All XCFrameworks exist and are valid
# 4. ThirdParty/ matches Pods/
# 5. Package.swift is coherent
# 6. round-trip-test passes
# 7. Credentials available (gh, pod trunk)
```

### Migration Mapping

| Current Script | Target Location | Notes |
|----------------|-----------------|-------|
| `release/modular.sh` | `release/orchestrator.sh` | Simplified, delegates more |
| `release/cocoapods.sh` | `release/pods/release.sh` | Split into smaller modules |
| `release/spm.sh` | `release/spm/release.sh` | Minimal changes |
| `release/create-branch.sh` | `release/utils/git.sh` | Merged into git utilities |
| `lib/release-common.sh` | Split into `release/utils/*.sh` | Break up the monolith |
| Slack code in `release-common.sh` | `notify/slack.sh` | Dedicated notification module |

---

## 5. Migration Plan (High-level)

### Phase 1: Foundation (Week 1)
1. **Create `msp-release.sh` as thin wrapper**
   - Initially just delegates to existing `modular.sh`
   - Adds subcommand parsing (`run`, `preflight`, etc.)
   - No behavior change

2. **Extract notification system**
   - Move Slack code from `release-common.sh` to `notify/slack.sh`
   - Update `release-common.sh` to source new location
   - Add DM-on-failure capability

3. **Consolidate logging**
   - Ensure all scripts use `lib/logging.sh`
   - Remove duplicate definitions

### Phase 2: Configuration (Week 2)
4. **Create `release/config/release.yaml`**
   - Define structure for version, repos, flags
   - Write YAML parser in bash (or use `yq`)

5. **Create `release/config/pods.yaml`**
   - Move hard-coded pod lists here
   - Include dependency graph

6. **Update orchestrator to read config**
   - Replace hard-coded values with config lookups
   - CLI flags override config values

### Phase 3: Preflight (Week 2-3)
7. **Create `release/preflight.sh`**
   - Consolidate all validation logic
   - Call from `msp-release.sh preflight`
   - Call automatically before `msp-release.sh run`

8. **Add state tracking**
   - Create `.release-state.json` for resume capability
   - Track completed steps

### Phase 4: Restructure (Week 3-4)
9. **Split `release-common.sh`**
   - `release/utils/version.sh` — version manipulation
   - `release/utils/git.sh` — git operations
   - `release/utils/retry.sh` — retry/backoff
   - `release/utils/state.sh` — state tracking

10. **Split `release/cocoapods.sh`**
    - `release/pods/release.sh` — orchestration
    - `release/pods/publish.sh` — trunk publishing
    - `release/pods/podspec.sh` — spec manipulation
    - `release/pods/github.sh` — GitHub releases

### Phase 5: Polish (Week 4)
11. **Add `rollback` subcommand**
    - Delete tags, unpublish pods (if possible)

12. **Add `verify` subcommand**
    - Check that version is installable via pod/SPM

13. **Update CI to use new system**
    - `ci_validate.sh` calls `msp-release.sh preflight`

14. **Documentation**
    - Update README with new workflow
    - Add RELEASE_GUIDE.md

---

## 6. Open Questions / Assumptions

### Questions for Human Decision

1. **YAML parser choice**
   - Option A: Pure bash parsing (complex but no deps)
   - Option B: Use `yq` (cleaner but adds dependency)
   - Option C: Use simple key=value `.conf` files instead

2. **State tracking format**
   - JSON vs simple text file?
   - Store in repo or in temp directory?

3. **Rollback scope**
   - Can we actually unpublish from CocoaPods trunk?
   - Delete GitHub releases automatically?

4. **SPM packages scope**
   - Currently only releases `NovaCore` and `NovaAdapter`
   - Should ALL packages be released via SPM?

5. **Base branch naming**
   - Keep `newsbreak_msp_migration_spm_dist` as default?
   - Or change to `main` / `develop`?

### Assumptions Made

1. **Bash 4+ available** — Uses associative arrays in some places
2. **GitHub CLI (`gh`) installed** — Required for releases
3. **CocoaPods trunk authenticated** — For pod publishing
4. **Bundler installed** — Scripts use `bundle exec pod`
5. **Scripts run from repo root** — All paths are relative

### Risks

1. **Breaking existing CI** — Must maintain backwards compatibility initially
2. **Parallel adapter release** — Complex to test; prone to race conditions
3. **Network dependencies** — CocoaPods CDN, GitHub API can fail

---

## Summary

The current release system works but has significant technical debt:
- **1050+ line monolith** (`release-common.sh`)
- **Duplicated logic** across 4+ scripts
- **Hard-coded everything** (pods, repos, branches)
- **No preflight validation** — releases can fail midway
- **No config file** — all settings via CLI

The proposed refactoring introduces:
- **Single entrypoint** (`msp-release.sh`) with subcommands
- **Config-driven model** (`release.yaml`)
- **Proper separation of concerns** (pods/, spm/, notify/, utils/)
- **Preflight validation** before any release
- **State tracking** for resume capability

Migration is incremental and maintains backwards compatibility in Phase 1.

