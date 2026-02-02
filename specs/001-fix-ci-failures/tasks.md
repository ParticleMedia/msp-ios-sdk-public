# Tasks: Restore CI Stability via Scripts Consolidation

**Input**: Design documents from `/specs/001-fix-ci-failures/`
**Prerequisites**: plan.md, spec.md, research.md
**Branch**: `001-fix-ci-failures`

**Organization**: Tasks follow the incremental refactoring plan (C-003: 1-2 jobs per PR) with config-driven development (C-005).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1=CI Passes, US2=Clear Failures, US3=Config Match)
- Include exact file paths in descriptions

## Path Conventions

- **Scripts**: `Scripts/ci/` for new CI wrapper scripts
- **Config**: `Scripts/config/` for YAML configuration files
- **Workflows**: `.github/workflows/` for CI YAML modifications

---

## Phase 1: Setup (Configuration Foundation - PR 0)

**Purpose**: Create config files that serve as single source of truth (C-005)

- [X] T001 [P] Create `Scripts/config/ci-build-stages.yml` defining XCFramework build order: stage1=[MSPiOSCore], stage2=[MSPSharedLibraries], stage3=[NovaCore, MSPGoogleAdsTypes], stage4=[MSPCore]
- [X] T002 [P] Create `Scripts/config/ci-pod-schemes.yml` defining Pod schemes to pre-build: [MSPKingfisher, SnapKit, lottie-ios, MSPPrebidAdapter, SwiftProtobuf]
- [X] T003 [P] Create `Scripts/config/ci-framework-deps.yml` defining verification requirements: stage2.requires=[MSPiOSCore], stage3.requires=[MSPiOSCore, MSPSharedLibraries], stage4.requires=[MSPiOSCore, MSPSharedLibraries, NovaCore, MSPGoogleAdsTypes]
- [X] T004 Validate YAML syntax for all config files using `yamllint` or equivalent

**Checkpoint**: Configuration foundation ready - scripts can now read from config files

---

## Phase 2: Foundational Scripts (Reusable Utilities)

**Purpose**: Create core utility scripts that will be reused across multiple CI jobs

**⚠️ CRITICAL**: All scripts MUST comply with Constitution Article VI (set -euo pipefail, POSIX-compliant, idempotent)

### Low-Complexity Scripts (Independent)

- [X] T005 [P] [US1] Create `Scripts/ci/ensure-xcodegen.sh` - ensure XcodeGen installed via Homebrew
- [X] T006 [P] [US1] Create `Scripts/ci/lint-podspecs.sh` - quick lint all *.podspec files with --allow-warnings flag
- [X] T007 [P] [US1] Create `Scripts/ci/validate-shell-syntax.sh` - validate shell script syntax in specified directory
- [X] T008 [P] [US1] Create `Scripts/ci/install-pods.sh` - CocoaPods install with fallback and --repo-update option
- [X] T009 [P] [US1] [US2] Create `Scripts/ci/verify-xcframework.sh` - verify single XCFramework exists with clear error messages

### Config-Driven Scripts (Depend on Phase 1)

- [X] T010 [US1] [US2] Create `Scripts/ci/verify-xcframework-deps.sh` - verify stage dependencies by reading `ci-framework-deps.yml`
- [X] T011 [US1] [US2] Create `Scripts/ci/validate-workspace-schemes.sh` - validate schemes exist by reading `ci-pod-schemes.yml`
- [X] T012 [US1] Create `Scripts/ci/prebuild-pod-deps.sh` - pre-build Pod dependencies by reading `ci-pod-schemes.yml`
- [X] T013 [US1] Create `Scripts/ci/generate-workspace.sh` - generate workspace and MSPDemoApp project via XcodeGen

### Local Validation

- [X] T014 Run `shellcheck` on all new scripts in `Scripts/ci/`
- [X] T015 Test each script locally to verify idempotency and error handling

**Checkpoint**: All reusable scripts ready - CI workflow refactoring can begin

---

## Phase 3: User Story 1 - CI Passes on Every PR (Priority: P1) 🎯 MVP

**Goal**: Make all CI jobs pass for valid PRs by replacing inline logic with script calls

**Independent Test**: Open a PR with no functional changes and confirm all CI jobs finish successfully

### PR 1: Quick Validation Job

- [X] T016 [US1] [US3] Update `.github/workflows/ci-pull-request.yml` job `quick-validation` step "Ensure XcodeGen" to call `Scripts/ci/ensure-xcodegen.sh`
- [X] T017 [US1] [US3] Update job `quick-validation` step "Lint Podspecs" to call `Scripts/ci/lint-podspecs.sh --allow-warnings`
- [X] T018 [US1] [US3] Update job `quick-validation` step "Shell Script Syntax Check" to call `Scripts/ci/validate-shell-syntax.sh Scripts`
- [ ] T019 [US1] Push PR 1 and verify `quick-validation` job passes

### PR 2: Build Core Stage 1

- [X] T020 [US1] [US3] Update job `build-core-stage1` step "Ensure XcodeGen" to call `Scripts/ci/ensure-xcodegen.sh`
- [X] T021 [US1] [US3] Update job `build-core-stage1` step "Install Root Dependencies" to call `Scripts/ci/install-pods.sh --repo-update`
- [X] T022 [US1] [US3] Update job `build-core-stage1` step "Verify XCFramework" to call `Scripts/ci/verify-xcframework.sh MSPiOSCore`
- [ ] T023 [US1] Push PR 2 and verify `build-core-stage1` job passes

### PR 3: Build Core Stage 2

- [X] T024 [US1] [US3] Update job `build-core-stage2` step "Ensure XcodeGen" to call `Scripts/ci/ensure-xcodegen.sh`
- [X] T025 [US1] [US3] Update job `build-core-stage2` step "Install Root Dependencies" to call `Scripts/ci/install-pods.sh --repo-update`
- [X] T026 [US1] [US3] Update job `build-core-stage2` step "Verify Required XCFrameworks" to call `Scripts/ci/verify-xcframework-deps.sh stage2`
- [X] T027 [US1] [US3] Update job `build-core-stage2` step "Verify XCFramework" to call `Scripts/ci/verify-xcframework.sh MSPSharedLibraries`
- [ ] T028 [US1] Push PR 3 and verify `build-core-stage2` job passes

### PR 4: Build Core Stage 3 (Medium Risk)

- [X] T029 [US1] [US3] Update job `build-core-stage3` step "Ensure XcodeGen" to call `Scripts/ci/ensure-xcodegen.sh`
- [X] T030 [US1] [US3] Update job `build-core-stage3` step "Verify Required XCFrameworks" to call `Scripts/ci/verify-xcframework-deps.sh stage3`
- [X] T031 [US1] [US3] Update job `build-core-stage3` step "Generate Workspace and MSPDemoApp Project" to call `Scripts/ci/generate-workspace.sh`
- [X] T032 [US1] [US3] Update job `build-core-stage3` step "Install Root Dependencies" to call `Scripts/ci/install-pods.sh --repo-update`
- [X] T033 [US1] [US3] Update job `build-core-stage3` step "Verify Workspace and Schemes" to call `Scripts/ci/validate-workspace-schemes.sh msp-ios-sdk.xcworkspace`
- [X] T034 [US1] [US3] Update job `build-core-stage3` step "Pre-build Pod Dependencies" to call `Scripts/ci/prebuild-pod-deps.sh`
- [X] T035 [US1] [US3] Update job `build-core-stage3` step "Verify XCFramework" to call `Scripts/ci/verify-xcframework.sh ${{ matrix.module }}`
- [ ] T036 [US1] Push PR 4 and verify `build-core-stage3` job passes for both NovaCore and MSPGoogleAdsTypes

### PR 5: Adapters & Stage 4

- [X] T037 [US1] [US3] Update job `build-adapter-xcframeworks` to reuse `Scripts/ci/ensure-xcodegen.sh`, `install-pods.sh`, `verify-xcframework.sh`
- [X] T038 [US1] [US3] Update job `build-core-stage4` step "Verify Required XCFrameworks" to call `Scripts/ci/verify-xcframework-deps.sh stage4`
- [X] T039 [US1] [US3] Update job `build-core-stage4` to reuse all established script patterns
- [ ] T040 [US1] Push PR 5 and verify `build-adapter-xcframeworks` and `build-core-stage4` jobs pass

### PR 6: DemoApp & Consistency

- [X] T041 [US1] [US3] Update job `build-demoapp` to reuse `Scripts/ci/ensure-xcodegen.sh`, `install-pods.sh`
- [X] T042 [US1] [US3] Update job `consistency-check` to reuse established script patterns
- [ ] T043 [US1] Push PR 6 and verify `build-demoapp` and `consistency-check` jobs pass
- [ ] T044 [US1] Verify full CI pipeline passes (all jobs green)

**Checkpoint**: User Story 1 complete - CI passes on every valid PR

---

## Phase 4: User Story 2 - Clear Failure Signals (Priority: P2)

**Goal**: Ensure CI failures provide actionable error messages

**Independent Test**: Intentionally introduce a failure and confirm clear error output

- [X] T045 [US2] Review all scripts in `Scripts/ci/` for clear error messages (prefix with ❌ for failures, ✅ for success)
- [X] T046 [US2] Ensure `verify-xcframework.sh` outputs missing framework path and suggestion to check build logs
- [X] T047 [US2] Ensure `verify-xcframework-deps.sh` lists ALL missing frameworks, not just first one
- [X] T048 [US2] Ensure `validate-workspace-schemes.sh` lists missing schemes with reference to config file
- [X] T049 [US2] Test failure scenarios locally: missing framework, missing scheme, pod install failure
- [X] T050 [US2] Verify CI failure outputs are actionable (contributor can identify issue from error message alone)

**Checkpoint**: User Story 2 complete - failures are clear and actionable

---

## Phase 5: User Story 3 - CI Matches Repository Configuration (Priority: P3)

**Goal**: Ensure CI configuration matches refactored repository layout

**Independent Test**: Validate all CI paths/scripts resolve correctly

- [X] T051 [US3] Audit `.github/workflows/ci-pull-request.yml` for hardcoded paths and replace with config-driven references
- [X] T052 [US3] Verify all `Scripts/ci/` scripts read from `Scripts/config/` for module lists
- [X] T053 [US3] Ensure no inline magic strings remain in CI YAML (module names, framework lists)
- [X] T054 [US3] Add CI validation step to check config file syntax at start of pipeline
- [X] T055 [US3] Document config file schema in `Scripts/config/README.md`

**Checkpoint**: User Story 3 complete - CI fully config-driven

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation

- [X] T056 [P] Update `Scripts/ci/README.md` documenting all new scripts with usage examples
- [X] T057 [P] Update `Scripts/config/README.md` documenting config file schema and how to add new stages
- [ ] T058 Run full CI pipeline validation (all jobs, both pods-dev and pods-release modes)
- [ ] T059 Measure CI median time and verify < 20 minutes (SC-003)
- [X] T060 Archive inline logic removal metrics (~347 lines removed from CI YAML)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup (Config Files)
    ↓
Phase 2: Foundational (Scripts)
    ↓
Phase 3: User Story 1 (CI Refactoring) ←── MVP DELIVERY POINT
    ↓
Phase 4: User Story 2 (Error Messages)
    ↓
Phase 5: User Story 3 (Config Alignment)
    ↓
Phase 6: Polish
```

### PR Dependencies (C-003 Incremental)

```
PR 0 (Config) → PR 1 (quick-validation) → PR 2 (stage1) → PR 3 (stage2) → PR 4 (stage3) → PR 5 (adapters/stage4) → PR 6 (demoapp)
```

### User Story Dependencies

- **US1 (CI Passes)**: Depends on all PRs merging successfully
- **US2 (Clear Failures)**: Can start after Phase 2, improved incrementally
- **US3 (Config Match)**: Addressed in each PR, verified at Phase 5

### Parallel Opportunities

**Within Phase 1** (all can run in parallel - different config files):
```
T001 (ci-build-stages.yml) || T002 (ci-pod-schemes.yml) || T003 (ci-framework-deps.yml)
```

**Within Phase 2** (low-complexity scripts can run in parallel):
```
T005 (ensure-xcodegen.sh) || T006 (lint-podspecs.sh) || T007 (validate-shell-syntax.sh) || T008 (install-pods.sh) || T009 (verify-xcframework.sh)
```

**Within Phase 6** (documentation tasks):
```
T056 (Scripts/ci/README.md) || T057 (Scripts/config/README.md)
```

---

## Implementation Strategy

### MVP First (PR 0-1)

1. Complete Phase 1: Config files
2. Complete Phase 2: Foundational scripts (T005-T015)
3. Complete PR 1: Quick validation job
4. **STOP and VALIDATE**: Verify `quick-validation` passes
5. Continue with PR 2-6 incrementally

### Incremental Delivery (Per C-003)

Each PR is independently valuable:
- PR 0: Config foundation (no CI change, safe)
- PR 1: quick-validation refactored (fast feedback)
- PR 2: stage1 refactored (first XCFramework build)
- PR 3-6: Remaining jobs (progressive stability)

### Rollback Strategy

If any PR breaks CI:
1. Revert the PR immediately
2. Debug locally using the extracted script
3. Fix and re-submit

---

## Success Metrics

| Metric | Target | Validation |
|--------|--------|------------|
| SC-001 | 100% CI pass for 2 weeks | Monitor after full rollout |
| SC-002 | 95% failures have clear message | Manual review of failure logs |
| SC-003 | Median CI time < 20 min | Measure after optimization |
| SC-004 | Zero path/config failures | Track failure root causes |

---

## Notes

- All scripts MUST use `set -euo pipefail` (Constitution VI.1)
- All scripts MUST be POSIX-compliant (Constitution VI.3)
- Existing scripts in `Scripts/` MUST NOT be modified (C-004)
- Configuration is the single source of truth (C-005)
- Commit after each task for easy rollback
- Test each script locally before CI integration
