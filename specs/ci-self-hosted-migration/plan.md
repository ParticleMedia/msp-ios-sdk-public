# Implementation Plan: CI Self-Hosted Runner Migration

**Branch**: `ci-self-hosted-migration` | **Date**: 2026-02-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/ci-self-hosted-migration/spec.md`

## Summary

Migrate the CI pipeline from 11 GitHub-hosted macOS jobs (1224 lines YAML, ~90 min/run) to 2 self-hosted jobs (43 lines YAML) running on a Beijing ARM64 macOS runner, eliminating all GitHub-hosted macOS billing. The new architecture delegates all logic to two shell scripts, eliminating inter-job artifact transfers (~2 GB/run) and cloud caching overhead while providing faster developer feedback through a separated validation job.

## Technical Context

**Language/Version**: Bash (POSIX-compatible), Ruby (YAML parsing), Python 3 (test case validation)
**Primary Dependencies**: GitHub Actions, existing Scripts/ infrastructure (step_lifecycle.sh, build_module.sh, etc.)
**Storage**: N/A (filesystem-based, no database)
**Testing**: Bash unit tests (`Scripts/tests/unit/run_all.sh`), shellcheck static analysis, Swift unit tests (Quick/Nimble)
**Target Platform**: macOS ARM64 (self-hosted runner), GitHub Actions workflow
**Project Type**: DevOps/CI infrastructure
**Performance Goals**: Validation < 15 min, full pipeline < 60 min
**Constraints**: Single runner (serial execution), zero GitHub-hosted macOS billing
**Scale/Scope**: 11 SDK modules, 1 self-hosted runner, 1 DemoApp

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Gate | Status | Notes |
|---------|------|--------|-------|
| I.1 (Automation First) | All CI operations must be scripted | PASS | All logic in `ci-validate-quick.sh` and `ci-pipeline.sh` |
| I.2 (Deterministic Builds) | No direct `.xcodeproj` modification | PASS | Uses XcodeGen via existing `generate-workspace.sh` |
| I.3 (SSOT) | Module list from `release.yaml` | PASS | `ci-pipeline.sh` reads modules from `release.yaml` at runtime |
| I.4 (Sanctity of Process) | No manual workarounds | PASS | Scripts reuse existing automation (`build_module.sh`, `install-pods.sh`) |
| II.1 (Validation Loop) | Changes pass automated validation | PASS | Both scripts validated: `bash -n`, `shellcheck -S warning`, YAML lint |
| VI.1 (Error Handling) | `set -euo pipefail` | PASS | Both scripts use `set -euo pipefail` |
| VI.2 (Idempotency) | Scripts can re-run safely | PASS | Each run starts fresh (checkout + generate workspace) |
| VI.5 (Centralized Config) | `release.yaml` is SSOT | PASS | No duplicate config files created |

**Post-design re-check**: All gates remain PASS. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/ci-self-hosted-migration/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: Design decisions and alternatives
├── quickstart.md        # Phase 1: Developer guide
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
.github/workflows/
└── ci.yml                          # NEW: 2-job workflow (43 lines)

Scripts/ci/
├── ci-validate-quick.sh            # NEW: Quick validation script (263 lines)
├── ci-pipeline.sh                  # NEW: Full build+test pipeline (460 lines)
├── build_module.sh                 # EXISTING: reused by ci-pipeline.sh
├── verify-xcframework.sh           # EXISTING: reused by ci-pipeline.sh
├── validate-shell-syntax.sh        # EXISTING: reused by ci-validate-quick.sh
├── lint-podspecs.sh                # EXISTING: reused by ci-validate-quick.sh
├── ensure-xcodegen.sh              # EXISTING: reused by ci-pipeline.sh
├── generate-workspace.sh           # EXISTING: reused by ci-pipeline.sh
├── install-pods.sh                 # EXISTING: reused by ci-pipeline.sh
└── prebuild-pod-deps.sh            # EXISTING: reused by ci-pipeline.sh

Scripts/lib/shared/
└── step_lifecycle.sh               # EXISTING: reused for structured CI logging
```

**Structure Decision**: No new directories created. New files placed alongside existing CI scripts in `Scripts/ci/` and workflow in `.github/workflows/`. This follows the existing convention and avoids structural changes.

## Complexity Tracking

No constitutional violations to justify. All new code follows existing patterns and reuses existing infrastructure.

## Design Decisions

See [research.md](research.md) for detailed decision records:

| ID | Decision | Rationale |
|----|----------|-----------|
| R1 | Runner labels: `[self-hosted, macOS, ARM64, bj_ios]` | Matches existing SwiftLint workflow |
| R2 | 2-job architecture (validate + build-and-test) | Fast feedback + clear PR status |
| R3 | Module list from `release.yaml` (SSOT) | Article I.3 compliance, no config drift |
| R4 | Upload only test results (no inter-job artifacts) | Single machine, no transfer needed |
| R5 | Two-tier failure: critical (fail-fast) + non-critical (continue) | Balance between speed and information |
| R6 | Concurrency: cancel-in-progress per branch | Prevent queue buildup on single runner |

## Implementation Approach

> **Note**: Phase numbering below is conceptual grouping. See `tasks.md` for the actual execution order (Phases 1-7 organized by user story).

### Phase 1: Create Validation Script

Create `Scripts/ci/ci-validate-quick.sh` that:
- Sources `step_lifecycle.sh` for structured logging
- Runs 8 validation steps via `run_step` helper (track pass/fail + timing)
- Reuses existing scripts: `validate-shell-syntax.sh`, `lint-podspecs.sh`
- Writes markdown summary to `$GITHUB_STEP_SUMMARY`
- Exits 0 on all pass, 1 on any failure

### Phase 2: Create Pipeline Script

Create `Scripts/ci/ci-pipeline.sh` that:
- Validates environment (Xcode, Ruby, CocoaPods, XcodeGen versions)
- Generates workspace and installs Pods via existing scripts
- Pre-builds Pod dependencies for Core module builds
- Reads module list from `release.yaml` and builds each XCFramework in order
- Builds DemoApp (non-critical)
- Runs consistency check (non-critical)
- Runs Swift unit tests with coverage
- Writes markdown summary to `$GITHUB_STEP_SUMMARY`

### Phase 3: Create Workflow

Create `.github/workflows/ci.yml` that:
- Triggers on push to main/feature/fix branches and PRs to main/develop/release/feature/fix
- Uses `concurrency` group to cancel in-progress runs
- Defines 2 jobs: `validate` → `build-and-test` (sequential)
- Both jobs use `runs-on: [self-hosted, macOS, ARM64, bj_ios]`
- Uploads test results artifact with 7-day retention

### Phase 4: Validation

- `bash -n` syntax check on both scripts
- `shellcheck -S warning` passes with zero warnings
- YAML validation via Ruby
- Local dry-run of validation script
