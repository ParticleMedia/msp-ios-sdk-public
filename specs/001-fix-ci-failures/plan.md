# Implementation Plan: Restore CI Stability via Scripts Consolidation

**Branch**: `001-fix-ci-failures` | **Date**: 2026-01-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-fix-ci-failures/spec.md`

## Summary

Restore CI stability by consolidating ~300 lines of duplicated inline shell logic from CI workflows into reusable scripts under `Scripts/ci/`. This approach aligns with the Federal Constitution Article I.1 (Automation First) and enables local/CI parity while maintaining incremental refactoring (1-2 jobs per PR).

## Technical Context

**Language/Version**: Bash (POSIX-compliant per Scripts/constitution.md Article VI.3)
**Primary Dependencies**: GitHub Actions, XcodeGen, CocoaPods, Xcode 16.4
**Storage**: N/A (CI configuration only)
**Testing**: Local script execution + CI run validation
**Target Platform**: GitHub Actions runners (macOS-15, macos-latest)
**Project Type**: CI/CD infrastructure refactoring
**Performance Goals**: CI median time < 20 minutes (SC-003)
**Constraints**: Existing Scripts MUST NOT be modified (C-004); incremental refactoring (C-003); config-driven development (C-005)
**Scale/Scope**: 6 workflow files, focus on `ci-pull-request.yml` (1235 lines)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| I.1 (Automation First) | Manual operations repeated >2x must be scripted | ✅ PASS | Extracting inline logic to Scripts aligns with this |
| I.2 (Deterministic Builds) | No direct .xcodeproj modifications | ✅ PASS | Not modifying Xcode project files |
| I.4 (Sanctity of Automated Process) | No temporary manual workarounds | ✅ PASS | Fixing scripts at root cause |
| II.1 (Validation Loop) | Changes must pass automated validation | ✅ PASS | CI itself is the validation gate |
| II.2 (Local Verification First) | Run round-trip-test.sh before commit | ⚠️ MONITOR | New scripts should be locally testable |
| VI.1 (Error Handling) | Scripts must use `set -euo pipefail` | ✅ REQUIRED | All new scripts must comply |
| VI.2 (Idempotency) | Scripts should be idempotent | ✅ REQUIRED | All new scripts must comply |
| VI.3 (POSIX Compliance) | New shell scripts must be POSIX-compliant | ✅ REQUIRED | All new scripts must comply |

**Gate Result**: ✅ PASS - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-ci-failures/
├── plan.md              # This file
├── research.md          # Phase 0 output (CI analysis findings)
├── spec.md              # Feature specification
└── tasks.md             # Phase 2 output (from /speckit.tasks)
```

### Source Code (repository root)

```text
.github/workflows/
├── ci-pull-request.yml  # Primary target for refactoring
├── unit-tests.yml       # Secondary target
├── release.yml          # Low priority
├── manual-build.yml     # Low priority
├── asset-validation.yml # Low priority
└── pr-labeler.yml       # No changes needed

Scripts/ci/
├── ensure-xcodegen.sh              # NEW: XcodeGen installation
├── verify-xcframework.sh           # NEW: Single framework verification
├── verify-xcframework-deps.sh      # NEW: Multi-framework dependency check
├── prebuild-pod-deps.sh            # NEW: Pod dependency pre-build
├── generate-workspace.sh           # NEW: Workspace generation wrapper
├── install-pods.sh                 # NEW: CocoaPods install with fallback
├── validate-workspace-schemes.sh   # NEW: Scheme validation
├── lint-podspecs.sh                # NEW: Podspec linting
├── validate-shell-syntax.sh        # NEW: Shell syntax validation
├── ci_validate.sh                  # EXISTING
├── fix-artifact-paths.sh           # EXISTING
├── jenkins-slack.sh                # EXISTING
├── test-release-notes.sh           # EXISTING
└── test-slack.sh                   # EXISTING

Scripts/config/
├── ci-build-stages.yml             # NEW: XCFramework build order & dependencies (C-005)
├── ci-pod-schemes.yml              # NEW: Pod schemes to pre-build per stage (C-005)
└── ci-framework-deps.yml           # NEW: Framework verification requirements (C-005)
```

**Structure Decision**: Scripts are organized under `Scripts/ci/` following existing convention. Each script is a focused, single-purpose utility that can be composed in CI workflows. Configuration files under `Scripts/config/` serve as the single source of truth for build stages, dependencies, and verification requirements (per C-005 config-driven constraint).

## Complexity Tracking

> No violations requiring justification. All changes align with Constitution.

## Extraction Priority Matrix

| Script | Priority | Jobs Affected | Lines Saved | Risk |
|--------|----------|---------------|-------------|------|
| ensure-xcodegen.sh | High | 7 | 42 | Low |
| verify-xcframework.sh | High | 5 | 40 | Low |
| verify-xcframework-deps.sh | High | 3 | 90 | Low |
| prebuild-pod-deps.sh | High | 1 | 60 | Medium |
| generate-workspace.sh | High | 1 | 34 | Medium |
| install-pods.sh | High | 7 | 21 | Low |
| validate-workspace-schemes.sh | Medium | 1 | 46 | Low |
| lint-podspecs.sh | Medium | 1 | 7 | Low |
| validate-shell-syntax.sh | Medium | 1 | 7 | Low |

## Incremental Refactoring Plan

Per constraint C-003, refactoring should be 1-2 jobs per PR. Per C-005, config files must be created first.

### PR 0: Configuration Foundation (C-005 Prerequisite)
- Create: `Scripts/config/ci-build-stages.yml` - defines stage order and framework dependencies
- Create: `Scripts/config/ci-pod-schemes.yml` - defines Pod schemes to pre-build
- Create: `Scripts/config/ci-framework-deps.yml` - defines verification requirements per stage
- Jobs: None (config only, no CI changes yet)
- Risk: Low
- Validation: YAML syntax check, schema validation

### PR 1: Quick Validation Job
- Extract: `ensure-xcodegen.sh`, `lint-podspecs.sh`, `validate-shell-syntax.sh`
- Jobs: `quick-validation`
- Risk: Low

### PR 2: Build Core Stage 1
- Extract: `verify-xcframework.sh`, `install-pods.sh`
- Jobs: `build-core-stage1`
- Risk: Low

### PR 3: Build Core Stage 2
- Reuse: `ensure-xcodegen.sh`, `verify-xcframework.sh`, `install-pods.sh`
- Extract: `verify-xcframework-deps.sh`
- Jobs: `build-core-stage2`
- Risk: Low

### PR 4: Build Core Stage 3
- Extract: `generate-workspace.sh`, `validate-workspace-schemes.sh`, `prebuild-pod-deps.sh`
- Jobs: `build-core-stage3`
- Risk: Medium (complex orchestration)

### PR 5: Adapters & Stage 4
- Reuse all existing scripts
- Jobs: `build-adapter-xcframeworks`, `build-core-stage4`
- Risk: Low

### PR 6: DemoApp & Consistency
- Reuse all existing scripts
- Jobs: `build-demoapp`, `consistency-check`
- Risk: Low

## Next Steps

1. Run `/speckit.tasks` to generate detailed task breakdown
2. Implement PR 1 scripts and validate locally
3. Open PR 1 and verify CI passes
4. Iterate through remaining PRs
