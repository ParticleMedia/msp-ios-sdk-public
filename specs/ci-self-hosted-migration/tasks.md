# Tasks: CI Self-Hosted Runner Migration

**Input**: Design documents from `specs/ci-self-hosted-migration/`
**Prerequisites**: plan.md (required), spec.md (required), research.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Directory structure and foundational infrastructure

- [x] T001 Create `.github/workflows/` directory for new workflow files
- [x] T002 [P] Verify existing scripts referenced by the pipeline are present and executable: `Scripts/ci/validate-shell-syntax.sh`, `Scripts/ci/lint-podspecs.sh`, `Scripts/ci/ensure-xcodegen.sh`, `Scripts/ci/generate-workspace.sh`, `Scripts/ci/install-pods.sh`, `Scripts/ci/prebuild-pod-deps.sh`, `Scripts/ci/verify-xcframework.sh`, `Scripts/xcframeworks/build_module.sh`
- [x] T003 [P] Verify `Scripts/lib/shared/step_lifecycle.sh` is sourceable and exports expected functions (`step`, `step_done`, `step_fail`, `step_skip`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before any user story scripts can be created

**No foundational tasks** — this feature creates new files only and reuses existing infrastructure. All dependencies (step_lifecycle, build_module, etc.) already exist.

**Checkpoint**: Setup verified — user story implementation can now begin

---

## Phase 3: User Story 1 — Developer Opens a Pull Request (Priority: P1)

**Goal**: CI automatically runs validation and build checks on the self-hosted runner when a PR is opened, consuming zero GitHub-hosted macOS billing minutes.

**Independent Test**: Open a PR and verify that GitHub Actions dispatches both jobs to the `bj_ios` runner and reports pass/fail status on the PR checks.

### Implementation for User Story 1

- [x] T004 [US1] Create workflow file `.github/workflows/ci.yml` with trigger rules for push (main, feature/**, fix/**) and pull_request (main, develop, release/*, feature/*, fix/*)
- [x] T005 [US1] Configure concurrency control in `.github/workflows/ci.yml`: group `ci-${{ github.ref }}` with `cancel-in-progress: true`
- [x] T006 [US1] Define `validate` job in `.github/workflows/ci.yml` with `runs-on: [self-hosted, macOS, ARM64, bj_ios]`, timeout 15 min, calling `bash Scripts/ci/ci-validate-quick.sh`
- [x] T007 [US1] Define `build-and-test` job in `.github/workflows/ci.yml` with `needs: validate`, `runs-on: [self-hosted, macOS, ARM64, bj_ios]`, timeout 60 min, calling `bash Scripts/ci/ci-pipeline.sh`
- [x] T008 [US1] Add test result artifact upload step in `.github/workflows/ci.yml`: upload `build/TestResults.xcresult` and `build/coverage.json` with 7-day retention
- [x] T009 [US1] Validate `.github/workflows/ci.yml` YAML syntax with `ruby -e "require 'yaml'; YAML.load_file(...)"`

**Checkpoint**: Workflow file complete — PR triggers will dispatch to self-hosted runner

---

## Phase 4: User Story 2 — Developer Gets Fast Feedback on Code Quality (Priority: P1)

**Goal**: Quick validation job completes within 15 minutes covering shell syntax, config validation, asset verification, test cases, bash tests, podspec lint, and SPM resolve.

**Independent Test**: Introduce a deliberate shell syntax error and verify the validation job catches it within 15 minutes while the build job does not start.

### Implementation for User Story 2

- [x] T010 [US2] Create `Scripts/ci/ci-validate-quick.sh` with shebang, `set -euo pipefail`, and script/root directory resolution
- [x] T011 [US2] Add step lifecycle sourcing and state tracking infrastructure (FAILURES counter, STEP_RESULTS array, run_step helper) in `Scripts/ci/ci-validate-quick.sh`
- [x] T012 [P] [US2] Implement shell syntax validation step in `Scripts/ci/ci-validate-quick.sh` — delegate to `Scripts/ci/validate-shell-syntax.sh` with inline fallback
- [x] T013 [P] [US2] Implement CI config YAML validation step in `Scripts/ci/ci-validate-quick.sh` — validate `release.yaml`, `test-config.yaml`, `ci-framework-deps.yml` via Ruby YAML parser
- [x] T014 [P] [US2] Implement asset verification step in `Scripts/ci/ci-validate-quick.sh` — source and call `Scripts/lib/asset_validation.sh`
- [x] T015 [P] [US2] Implement test case validation step in `Scripts/ci/ci-validate-quick.sh` — call `Scripts/tools/test-cases.py validate`
- [x] T016 [P] [US2] Implement bash unit test step in `Scripts/ci/ci-validate-quick.sh` — call `Scripts/tests/unit/run_all.sh`
- [x] T017 [P] [US2] Implement bash integration test step in `Scripts/ci/ci-validate-quick.sh` — call `Scripts/tests/release_state/run_all.sh`
- [x] T018 [P] [US2] Implement podspec lint step in `Scripts/ci/ci-validate-quick.sh` — call `Scripts/ci/lint-podspecs.sh --allow-warnings`
- [x] T019 [P] [US2] Implement Swift package resolve step in `Scripts/ci/ci-validate-quick.sh` — conditionally run `swift package resolve` if `Package.swift` exists
- [x] T020 [US2] Add summary output and `$GITHUB_STEP_SUMMARY` markdown table generation in `Scripts/ci/ci-validate-quick.sh`
- [x] T021 [US2] Make `Scripts/ci/ci-validate-quick.sh` executable (`chmod +x`)
- [x] T022 [US2] Validate `Scripts/ci/ci-validate-quick.sh` with `bash -n` and `shellcheck -S warning`

**Checkpoint**: Quick validation script complete — fast feedback within 15 minutes

---

## Phase 5: User Story 3 — CI Maintainer Manages the Pipeline (Priority: P2)

**Goal**: Full build+test pipeline in a single well-structured script that reads module list from release.yaml (SSOT), builds all XCFrameworks, builds DemoApp, runs consistency checks, and runs unit tests.

**Independent Test**: Review the script for clarity, modify it to add a new step, and verify the change only requires editing the script file (not the workflow YAML).

### Implementation for User Story 3

- [x] T023 [US3] Create `Scripts/ci/ci-pipeline.sh` with shebang, `set -euo pipefail`, directory resolution, and library sourcing (step_lifecycle, config_loader_ext)
- [x] T024 [US3] Add two-tier failure tracking infrastructure in `Scripts/ci/ci-pipeline.sh`: `run_critical_step` (fail-fast) and `run_optional_step` (continue + collect) helpers
- [x] T025 [US3] Implement environment validation step in `Scripts/ci/ci-pipeline.sh` — check Xcode, Ruby, CocoaPods, XcodeGen, Python 3, jq, and `release.yaml` existence
- [x] T026 [US3] Implement workspace generation + Pod install step in `Scripts/ci/ci-pipeline.sh` — delegate to `Scripts/ci/generate-workspace.sh` and `Scripts/ci/install-pods.sh`
- [x] T027 [US3] Implement Pod dependency pre-build step in `Scripts/ci/ci-pipeline.sh` — delegate to `Scripts/ci/prebuild-pod-deps.sh`
- [x] T028 [US3] Implement XCFramework build step in `Scripts/ci/ci-pipeline.sh` — read modules from `release.yaml` via Ruby, loop `build_module.sh` + `verify-xcframework.sh` per module with progress counter
- [x] T029 [US3] Implement DemoApp build step (non-critical) in `Scripts/ci/ci-pipeline.sh` — use `xcodebuild -workspace ... -scheme MSPDemoApp`
- [x] T030 [US3] Implement Pods/SPM consistency check step (non-critical) in `Scripts/ci/ci-pipeline.sh` — delegate to `Scripts/target-switching/round-trip-test.sh --stress=1`
- [x] T031 [US3] Implement Swift unit test step in `Scripts/ci/ci-pipeline.sh` — use `xcodebuild test -scheme MSPTests` with coverage and result bundle output
- [x] T032 [US3] Wire all steps in execution order in `Scripts/ci/ci-pipeline.sh`: critical steps fail-fast (env → workspace → prebuild → XCFrameworks → unit tests), optional steps continue (DemoApp, consistency)
- [x] T033 [US3] Make `Scripts/ci/ci-pipeline.sh` executable (`chmod +x`)
- [x] T034 [US3] Validate `Scripts/ci/ci-pipeline.sh` with `bash -n` and `shellcheck -S warning`

**Checkpoint**: Full pipeline script complete — single script orchestrates entire build+test flow

---

## Phase 6: User Story 4 — Build Failure Diagnosis (Priority: P2)

**Goal**: Pipeline produces structured output with per-step timing, clear error messages, and test result artifacts for fast failure diagnosis.

**Independent Test**: Introduce a deliberate build failure and verify CI output clearly identifies the failing step with actionable error details.

### Implementation for User Story 4

- [x] T035 [US4] Add per-step timing tracking to `run_critical_step` and `run_optional_step` in `Scripts/ci/ci-pipeline.sh`
- [x] T036 [US4] Add pipeline summary table output (result, time, step name) at end of `Scripts/ci/ci-pipeline.sh`
- [x] T037 [US4] Add `$GITHUB_STEP_SUMMARY` markdown table generation in `Scripts/ci/ci-pipeline.sh` with pass/fail/warning icons
- [x] T038 [US4] Add coverage report generation in `Scripts/ci/ci-pipeline.sh` — run `xcrun xccov view --report --json` after tests
- [x] T039 [US4] Add per-step timing tracking and summary table to `Scripts/ci/ci-validate-quick.sh`

**Checkpoint**: Both scripts produce structured, diagnosable output for CI logs and GitHub PR summary

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and verification

- [x] T040 Run `bash -n` syntax check on both `Scripts/ci/ci-validate-quick.sh` and `Scripts/ci/ci-pipeline.sh`
- [x] T041 Run `shellcheck -S warning` on both scripts and fix any warnings
- [x] T042 Validate `.github/workflows/ci.yml` YAML syntax
- [x] T043 Verify line counts meet spec targets: ci.yml < 80 lines, scripts are well-structured
- [x] T044 Run `Scripts/ci/ci-validate-quick.sh` locally to verify it passes
- [x] T045 Review quickstart.md in `specs/ci-self-hosted-migration/quickstart.md` for accuracy

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: No blocking tasks (all dependencies pre-exist)
- **US1 (Phase 3)**: Depends on Setup — creates workflow YAML
- **US2 (Phase 4)**: Depends on Setup — creates validation script
- **US3 (Phase 5)**: Depends on Setup — creates pipeline script
- **US4 (Phase 6)**: Depends on US2 + US3 (adds diagnostic features to both scripts)
- **Polish (Phase 7)**: Depends on US1 + US2 + US3 + US4

### User Story Dependencies

- **US1 (Workflow)**: Can start after Setup — references scripts from US2/US3 by path but doesn't depend on their content
- **US2 (Validation Script)**: Can start after Setup — fully independent
- **US3 (Pipeline Script)**: Can start after Setup — fully independent
- **US4 (Diagnostics)**: Depends on US2 + US3 — adds features to their scripts

### Within Each User Story

- T004-T009 (US1): Sequential — building one YAML file
- T010-T022 (US2): T010-T011 first, then T012-T019 in parallel, then T020-T022 sequential
- T023-T034 (US3): T023-T024 first, then T025-T031 mostly sequential (build order matters), then T032-T034
- T035-T039 (US4): Can be applied in parallel to both scripts

### Parallel Opportunities

- **US1, US2, US3** can all be implemented in parallel (different files, no dependencies)
- Within US2: steps T012-T019 touch the same file but are independent functions — can be written in any order
- Within US3: steps T025-T031 touch the same file but are independent functions — can be written in any order
- **US4** must wait for US2 + US3 scripts to exist

---

## Parallel Example: User Stories 1-3

```bash
# These three user stories can be implemented simultaneously:
# Developer A: US1 — .github/workflows/ci.yml
# Developer B: US2 — Scripts/ci/ci-validate-quick.sh
# Developer C: US3 — Scripts/ci/ci-pipeline.sh
```

---

## Implementation Strategy

### MVP First (US1 + US2 — Fast Feedback)

1. Complete Phase 1: Setup (verify dependencies)
2. Complete US2: Create validation script (fast feedback for developers)
3. Complete US1: Create workflow YAML (triggers on PR)
4. **STOP and VALIDATE**: Push branch, open PR, verify validation job runs on self-hosted runner
5. This alone eliminates most macOS billing for quick validation

### Full Delivery

1. Setup → US1 + US2 + US3 (parallel) → US4 → Polish
2. Total: 45 tasks across 7 phases
3. Each user story checkpoint is independently verifiable

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All scripts must use `set -euo pipefail` per Article VI.1
- Module list must come from `release.yaml` per Article I.3 (SSOT)
- No `ci-build-stages.yml` — eliminated per research decision R3
- Commit after each task or logical group
