# Phase 0 Research: Restore CI Stability

**Feature**: Restore CI Stability via Scripts Consolidation
**Date**: 2026-01-27
**Status**: Complete

---

## Decision 1: CI Source of Truth

- **Decision**: Treat GitHub Actions workflows as the authoritative CI configuration and align all referenced paths/scripts to the refactored repo layout.
- **Rationale**: The failing run is a GitHub Actions job; aligning workflows to the new layout directly addresses path/config drift after refactors.
- **Alternatives considered**: Rely on Jenkins pipelines only; deprecate GitHub Actions. Rejected because the reported failures are on GitHub Actions and must be fixed to restore CI.

## Decision 2: Script Extraction Strategy

- **Decision**: Extract inline shell logic into individual, focused scripts under `Scripts/ci/`
- **Rationale**:
  - Aligns with Federal Constitution Article I.1 (Automation First)
  - Enables local testing before CI execution
  - Reduces YAML file complexity (~300 lines of duplication)
  - Facilitates maintenance as same logic used across 7+ jobs
- **Alternatives considered**:
  - Composite GitHub Actions: Rejected - harder to test locally
  - Keep inline but standardize: Rejected - still violates DRY

## Decision 3: CI Environment Detection

- **Decision**: Use standard `CI` environment variable (automatically set by GitHub Actions)
- **Rationale**:
  - Industry standard approach
  - Already partially used in codebase (e.g., `Scripts/workspace/update.sh`)
  - GitHub Actions sets `CI=true` automatically
- **Alternatives considered**:
  - Custom `MSP_CI_MODE` variable: Rejected - non-standard

## Decision 4: Incremental Refactoring

- **Decision**: Refactor 1-2 CI jobs per PR, starting with `quick-validation`
- **Rationale**:
  - Reduces risk of breaking entire CI pipeline
  - Allows validation of each extraction before proceeding
  - Constraint C-003 explicitly requires this approach
- **Alternatives considered**:
  - Big bang refactor: Rejected - too risky

## Decision 5: Config-Driven Development (C-005)

- **Decision**: Externalize all hardcoded values (module names, framework lists, paths) to YAML configuration files under `Scripts/config/`
- **Rationale**:
  - Aligns with project's config-driven development philosophy
  - Single source of truth for build stages, dependencies, and verification requirements
  - Scripts become generic and reusable; behavior controlled by config
  - Easier to maintain and extend without modifying script logic
  - Reduces risk of inconsistencies between CI stages
- **Alternatives considered**:
  - Hardcode values in scripts: Rejected - violates DRY, harder to maintain
  - Environment variables only: Rejected - harder to version control and review
  - GitHub Actions matrix: Rejected - couples config to CI platform

### Configuration Files Design

| Config File | Purpose | Example Content |
|-------------|---------|-----------------|
| `ci-build-stages.yml` | XCFramework build order | `stage1: [MSPiOSCore]`, `stage2: [MSPSharedLibraries]` |
| `ci-pod-schemes.yml` | Pod schemes to pre-build | `schemes: [MSPKingfisher, SnapKit, lottie-ios]` |
| `ci-framework-deps.yml` | Verification requirements | `stage2.requires: [MSPiOSCore]` |

---

## Current Script Usage Analysis

### Scripts Already Called from CI

| Script Path | Jobs Using It |
|-------------|---------------|
| `Scripts/validation/validate_assets.sh` | quick-validation |
| `Scripts/xcframeworks/build_module.sh` | build-core-stage1, stage2, stage3, adapters, stage4 |
| `Scripts/ci/fix-artifact-paths.sh` | 6 jobs (stage2, stage3, adapters, stage4, demoapp, consistency) |
| `Scripts/workspace/update.sh` | build-core-stage3, build-demoapp, unit-tests |
| `Scripts/tests/run-unit-tests.sh` | unit-tests |
| `Scripts/spm-sync/generate_package_swift.sh` | consistency-check |
| `Scripts/validation/verify_pods_spm_consistency.sh` | consistency-check |

### Inline Logic Patterns Identified

| Pattern | Jobs | Lines | Extraction Script |
|---------|------|-------|-------------------|
| XcodeGen ensure/install | 7 | 42 | `ensure-xcodegen.sh` |
| XCFramework verification | 5 | 40 | `verify-xcframework.sh` |
| XCFramework dependency check | 3 | 90 | `verify-xcframework-deps.sh` |
| Pod pre-build orchestration | 1 | 60 | `prebuild-pod-deps.sh` |
| Workspace generation | 1 | 34 | `generate-workspace.sh` |
| CocoaPods install | 7 | 21 | `install-pods.sh` |
| Scheme validation | 1 | 46 | `validate-workspace-schemes.sh` |
| Podspec linting | 1 | 7 | `lint-podspecs.sh` |
| Shell syntax validation | 1 | 7 | `validate-shell-syntax.sh` |

**Total**: ~347 lines of duplicated inline logic to extract

---

## Script Design Specifications

### 1. ensure-xcodegen.sh

**Purpose**: Ensure XcodeGen is installed and available
**Arguments**: None
**Exit Codes**: 0 = success, 1 = installation failed
**Idempotent**: Yes

### 2. verify-xcframework.sh

**Purpose**: Verify an XCFramework exists at expected path
**Arguments**: `<framework-name>` (e.g., "MSPCore")
**Exit Codes**: 0 = exists, 1 = not found
**Idempotent**: Yes (read-only)

### 3. verify-xcframework-deps.sh

**Purpose**: Verify multiple required XCFrameworks exist
**Arguments**: `<stage>` (e.g., "stage2", "stage3") - reads requirements from `ci-framework-deps.yml`
**Exit Codes**: 0 = all exist, 1 = one or more missing
**Config-driven**: Reads `Scripts/config/ci-framework-deps.yml` for stage requirements

### 4. prebuild-pod-deps.sh

**Purpose**: Pre-build Pod dependencies for iOS and Simulator platforms
**Arguments**: `[--stage <stage>]` (optional) - reads schemes from `ci-pod-schemes.yml`
**Exit Codes**: 0 = success, 1 = build failed
**Config-driven**: Reads `Scripts/config/ci-pod-schemes.yml` for scheme list

### 5. generate-workspace.sh

**Purpose**: Generate workspace and MSPDemoApp project via XcodeGen
**Arguments**: None
**Exit Codes**: 0 = success, 1 = generation failed

### 6. install-pods.sh

**Purpose**: Install CocoaPods dependencies with fallback
**Arguments**: `[--repo-update]` (optional)
**Exit Codes**: 0 = success, 1 = install failed

### 7. validate-workspace-schemes.sh

**Purpose**: Validate required schemes exist in workspace
**Arguments**: `<workspace>` - reads required schemes from `ci-pod-schemes.yml`
**Exit Codes**: 0 = all found, 1 = one or more missing
**Config-driven**: Reads `Scripts/config/ci-pod-schemes.yml` for required scheme list

### 8. lint-podspecs.sh

**Purpose**: Quick lint all podspec files in repository root
**Arguments**: `[--allow-warnings]` (optional)
**Exit Codes**: 0 = all pass, 1 = lint errors

### 9. validate-shell-syntax.sh

**Purpose**: Validate shell script syntax in specified directory
**Arguments**: `[directory]` (defaults to "Scripts")
**Exit Codes**: 0 = all pass, 1 = syntax errors

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Script extraction breaks CI | Medium | High | Incremental refactoring, test locally first |
| POSIX incompatibility | Low | Medium | Use shellcheck, test on macOS and Linux |
| Environment differences | Low | Medium | Use `CI` variable detection |

---

## Open Questions (All Resolved)

1. ✅ CI/Scripts reuse strategy → Direct calls to Scripts
2. ✅ CI environment detection → Standard `CI` variable
3. ✅ Refactoring strategy → Incremental (1-2 jobs/PR)
4. ✅ Handling gaps → New scripts in `Scripts/ci/`
5. ✅ Development approach → Config-driven (hardcoded values externalized to YAML)
