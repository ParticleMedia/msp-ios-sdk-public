# Feature Specification: CI Self-Hosted Runner Migration

**Feature Branch**: `ci-self-hosted-migration`
**Created**: 2026-02-26
**Status**: Draft
**Input**: Migrate GitHub Actions CI from GitHub-hosted macOS runners to a self-hosted Beijing ARM64 macOS runner to eliminate macOS billing costs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer Opens a Pull Request (Priority: P1)

A developer pushes code to a feature branch and opens a pull request against main. The CI system automatically runs validation and build checks on the self-hosted Beijing runner, providing fast feedback on code quality and build correctness without consuming any GitHub-hosted macOS billing minutes.

**Why this priority**: This is the primary use case — every PR triggers CI. Moving this to self-hosted directly eliminates the macOS billing problem.

**Independent Test**: Can be fully tested by opening a PR on the repository and verifying that GitHub Actions dispatches both jobs to the self-hosted runner and reports pass/fail status on the PR checks.

**Acceptance Scenarios**:

1. **Given** a developer pushes to a feature branch and opens a PR, **When** CI is triggered, **Then** both validation and build jobs run on the self-hosted runner (not GitHub-hosted) and report status back to the PR.
2. **Given** the CI pipeline is running, **When** a second push is made to the same branch, **Then** the previous run is cancelled and a new run starts (concurrency control).
3. **Given** the developer's code has lint or syntax errors, **When** the quick validation job runs, **Then** the developer receives feedback within 15 minutes without waiting for the full build.

---

### User Story 2 - Developer Gets Fast Feedback on Code Quality (Priority: P1)

A developer wants to know quickly whether their code passes basic quality checks (shell syntax, podspec lint, test validation) before the longer build process completes. The CI separates quick validation from full build so developers can iterate faster on obvious issues.

**Why this priority**: Fast feedback loops are essential for developer productivity. Separating validation from build lets developers fix lint/syntax issues in minutes rather than waiting 40+ minutes for a full build to fail.

**Independent Test**: Can be tested by introducing a deliberate shell syntax error and verifying that the validation job catches it within 15 minutes, while the build job does not start.

**Acceptance Scenarios**:

1. **Given** the CI pipeline starts, **When** the quick validation job runs, **Then** it completes within 15 minutes and covers shell syntax, CI config validation, asset verification, test case validation, bash unit/integration tests, and podspec lint.
2. **Given** the quick validation job fails, **When** the developer checks CI status, **Then** the build job has not started (it depends on validation passing).
3. **Given** the quick validation job passes, **When** the build job starts, **Then** it runs the full pipeline: environment checks, workspace generation, XCFramework builds, DemoApp build, consistency checks, and unit tests.

---

### User Story 3 - CI Maintainer Manages the Pipeline (Priority: P2)

A CI maintainer needs to understand, modify, and debug the CI pipeline. The new pipeline uses a minimal workflow file (~60 lines) that delegates to well-structured shell scripts, making it far easier to maintain than the previous 1224-line, 11-job YAML configuration.

**Why this priority**: Long-term maintainability reduces operational burden. The current 1224-line workflow with 11 jobs and 73 action invocations is extremely difficult to debug and modify.

**Independent Test**: Can be tested by reviewing the workflow file and scripts, verifying they are self-documenting, and making a minor modification (e.g., adding a new validation step) to confirm ease of change.

**Acceptance Scenarios**:

1. **Given** a CI maintainer needs to add a new validation check, **When** they edit the validation script, **Then** the change requires modifying only the script file, not the workflow YAML.
2. **Given** the CI pipeline fails at a specific step, **When** the maintainer reviews the logs, **Then** each step has clear status output with timing information.
3. **Given** a CI maintainer wants to understand the full pipeline, **When** they read the workflow file, **Then** the entire workflow definition fits in ~60 lines with clear job names and descriptions.

---

### User Story 4 - Build Failure Diagnosis (Priority: P2)

When a build or test fails, the developer can diagnose the issue from CI logs and uploaded test result artifacts. The pipeline provides structured output with per-step timing, clear error messages, and test result files.

**Why this priority**: Fast diagnosis of failures is critical for developer velocity. Without good failure output, developers waste time reproducing issues locally.

**Independent Test**: Can be tested by introducing a deliberate build failure and verifying that the CI output clearly identifies the failing step, provides actionable error details, and uploads test result artifacts.

**Acceptance Scenarios**:

1. **Given** an XCFramework build fails for a specific module, **When** the developer reads CI logs, **Then** the failing module name, build command, and error output are clearly visible.
2. **Given** unit tests fail, **When** the CI run completes, **Then** test result artifacts are uploaded and retained for 7 days.
3. **Given** a non-critical step fails (e.g., DemoApp build), **When** the pipeline continues, **Then** all errors are collected and reported in a final summary, not silently swallowed.

---

### Edge Cases

- What happens when the self-hosted runner is offline or unreachable? Jobs queue until the runner comes back online; GitHub shows "Queued" status on the PR.
- What happens when multiple PRs trigger CI simultaneously on a single runner? Concurrency groups cancel in-progress runs for the same branch; different branches queue sequentially since there is only 1 runner.
- What happens when required tools (Xcode, CocoaPods, XcodeGen) are missing or wrong version on the runner? The pipeline's environment validation step fails early with a clear error message listing missing/wrong-version tools.
- What happens when the module list in release.yaml changes? The pipeline dynamically reads the module list at runtime, so no CI configuration update is needed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: CI MUST run all jobs on the self-hosted runner labeled `[self-hosted, macOS, ARM64, bj_ios]`, consuming zero GitHub-hosted macOS billing minutes.
- **FR-002**: CI MUST be structured as two sequential jobs: a quick validation job and a full build-and-test job.
- **FR-003**: The quick validation job MUST complete within 15 minutes and cover: shell syntax checking, CI config validation, asset verification, test case validation, bash unit tests, bash integration tests, and podspec linting.
- **FR-004**: The full build job MUST validate the build environment (tool versions) before starting any builds.
- **FR-005**: The full build job MUST read the module list from `release.yaml` (single source of truth) rather than maintaining a separate CI-specific module list.
- **FR-006**: The full build job MUST build all XCFrameworks in dependency order and verify each one after building.
- **FR-007**: The full build job MUST build the DemoApp to validate integration.
- **FR-008**: The full build job MUST run Pods/SPM consistency checks.
- **FR-009**: The full build job MUST run Swift unit tests and generate coverage reports.
- **FR-010**: CI MUST support concurrency control — cancelling in-progress runs when new commits are pushed to the same branch.
- **FR-011**: CI MUST upload test result artifacts with a 7-day retention period.
- **FR-012**: The pipeline MUST distinguish between critical failures (stop immediately) and non-critical failures (continue and collect errors for final summary).
- **FR-013**: The pipeline MUST output a structured summary with per-step status and timing to the CI summary view.
- **FR-014**: CI MUST trigger on pushes to main and feature/fix branches, and on pull requests to main, develop, release, feature, and fix branches.
- **FR-015**: The workflow YAML SHOULD be under 80 lines total.
- **FR-016**: The pipeline scripts MUST be runnable locally for debugging purposes.

### Key Entities

- **Workflow**: The GitHub Actions workflow definition that dispatches jobs to the self-hosted runner. Contains trigger rules, concurrency settings, and job definitions.
- **Validation Script**: A shell script that runs all quick, non-build validation checks. Fails fast on code quality issues.
- **Pipeline Script**: A shell script that orchestrates the full build-and-test sequence. Reads module configuration, builds frameworks, runs tests, and produces summaries.
- **Module List**: The ordered list of SDK modules to build, sourced from `release.yaml` (SSOT).
- **Self-Hosted Runner**: The Beijing ARM64 macOS machine registered with GitHub Actions under the labels `self-hosted, macOS, ARM64, bj_ios`.

## Assumptions

- The Beijing self-hosted runner is registered at the **organization level** (ParticleMedia) — not at the repo level. The org admin must add `msp-ios-sdk` to the runner group's repository access list for jobs to be dispatched.
- The runner has the labels `self-hosted, macOS, ARM64, bj_ios`.
- The runner has macOS 15.x, Xcode 16.4, Ruby 3.1+, CocoaPods, XcodeGen, Python 3, and jq pre-installed.
- There is exactly 1 self-hosted runner, so jobs run sequentially (no parallelism between different PRs). If the runner is offline, jobs queue indefinitely — GitHub shows "Queued" status on the PR. There is no built-in timeout or alerting for this; consider adding a Slack notification if queue time exceeds 30 minutes in a future iteration.
- The existing disabled workflow (`ci-pull-request.yml`) has been archived to `workflows-disabled/` for reference.
- Existing CI helper scripts (e.g., `build_module.sh`, `verify-xcframework.sh`, `lint-podspecs.sh`, `step_lifecycle.sh`) will be reused by the new pipeline scripts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: CI runs consume zero GitHub-hosted macOS billing minutes per month after migration.
- **SC-002**: Developers receive code quality feedback (validation job result) within 15 minutes of pushing code.
- **SC-003**: The complete CI pipeline (validation + build + test) completes within 60 minutes for a full run.
- **SC-004**: The workflow definition is under 80 lines of YAML, reduced from 1224 lines (>93% reduction).
- **SC-005**: Network transfer for artifact handling is reduced from ~2 GB per run (inter-job artifact uploads/downloads) to under 10 MB (only test results uploaded).
- **SC-006**: CI failures produce actionable diagnostic output — a developer can identify the failing component and error from CI logs without reproducing locally in 90% of cases.
