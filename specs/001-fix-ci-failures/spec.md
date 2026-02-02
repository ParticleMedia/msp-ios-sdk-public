# Feature Specification: Restore CI Stability

**Feature Branch**: `001-fix-ci-failures`
**Created**: January 21, 2026
**Status**: Draft
**Input**: User description: "我重构了整个项目 和 CI/CD 结果现在 CI 每次都失败 比如这个 https://github.com/ParticleMedia/msp-ios-sdk/actions/runs/21199631917/job/60982523131?pr=384 我现在的要求是把 CI 彻底跑成功"

## Clarifications

### Session 2026-01-27

- Q: CI 工作流是否应该复用现有的 Scripts 函数？ → A: CI 直接调用 Scripts；内联逻辑仅用于 CI 特有功能（artifacts、缓存、环境配置）
- Q: Scripts 应如何检测 CI 环境？ → A: 使用标准 `CI` 环境变量（GitHub Actions 自动设置）
- Q: CI 重构应采用什么策略？ → A: 渐进式重构，按 job 逐步将内联逻辑迁移到 Scripts 调用
- Q: 当现有 Scripts 不满足 CI 需求时如何处理？ → A: 在 `Scripts/ci/` 创建新封装脚本，调用现有 Scripts 并添加 CI 适配逻辑
- Q: 开发模式应遵循什么原则？ → A: Config-driven 开发模式，配置与逻辑分离，避免硬编码

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - CI Passes on Every PR (Priority: P1)

As a contributor, I need the CI pipeline to complete successfully for valid changes so that PRs can be merged with confidence.

**Why this priority**: CI stability is a release gate; repeated failures block development and reduce trust in the pipeline.

**Independent Test**: Open a PR with no functional changes and confirm all CI jobs finish successfully.

**Acceptance Scenarios**:

1. **Given** a PR with no code changes that should be buildable, **When** CI runs, **Then** all required jobs complete successfully.
2. **Given** a PR with unit test changes that compile and pass locally, **When** CI runs, **Then** all required jobs complete successfully.

---

### User Story 2 - Clear Failure Signals When Something Is Wrong (Priority: P2)

As a contributor, I need CI failures to be actionable so I can quickly identify and fix the issue.

**Why this priority**: When CI fails, the team needs fast feedback to restore green builds.

**Independent Test**: Intentionally introduce a test failure and confirm CI reports a clear failing job and reason.

**Acceptance Scenarios**:

1. **Given** a PR with a failing test, **When** CI runs, **Then** the failing job is reported with a clear failure reason.

---

### User Story 3 - CI Matches the Repository Configuration (Priority: P3)

As a maintainer, I need the CI pipeline configuration to match the refactored repository layout so it stays in sync with the project structure.

**Why this priority**: After refactors, mismatched paths or scripts are common sources of CI failures.

**Independent Test**: Validate CI uses the expected scripts, paths, and configuration consistent with the repo structure.

**Acceptance Scenarios**:

1. **Given** the refactored repository layout, **When** CI executes, **Then** all referenced paths, scripts, and configs resolve correctly.

---

### Edge Cases

- What happens when CI references a path that no longer exists after refactor?
- How does CI handle missing or misconfigured secrets required by the pipeline?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: CI MUST complete successfully for PRs that compile and pass tests in the repository.
- **FR-002**: CI MUST fail only when a real build/test error exists, not due to missing paths, scripts, or configuration drift.
- **FR-003**: CI MUST use repository scripts, paths, and configuration that reflect the current refactored layout.
- **FR-004**: Contributors MUST be able to identify which CI job failed and why from the CI run results.
- **FR-005**: CI MUST run all required checks that gate merges for this repository.

### Key Entities *(include if feature involves data)*

- **CI Job**: A required pipeline task with a clear success/failure status and error output.
- **Repository Layout**: The current file and directory structure that CI relies on for scripts and configs.
- **CI Configuration**: YAML/JSON files under `Scripts/config/` that define build stages, framework dependencies, and verification requirements (config-driven single source of truth).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of CI runs for valid PRs complete successfully without manual retries for two consecutive weeks.
- **SC-002**: CI failures have a clear, actionable error message in the failing job output in 95% of failures.
- **SC-003**: The median time to a green CI run after a code change is under 20 minutes.
- **SC-004**: Zero CI failures are caused by missing paths, scripts, or misaligned configuration after the refactor.

## Assumptions

- The refactor did not change the intended set of required CI checks, only their reliability.
- A "valid PR" is one that builds and passes tests in a clean environment using repository instructions.

## Constraints

- **C-001**: CI workflows MUST reuse existing `Scripts/` functions for build/validation logic; inline shell in CI YAML is limited to CI-specific concerns (artifact upload/download, caching, environment setup, GitHub Actions syntax).
- **C-002**: Scripts MUST use the standard `CI` environment variable (automatically set by GitHub Actions) to detect CI environment and adapt behavior (e.g., log format, error handling).
- **C-003**: CI refactoring MUST be incremental (1-2 jobs per PR), allowing independent validation and reducing risk of widespread breakage.
- **C-004**: Existing Scripts MUST NOT be modified; new CI-specific wrapper scripts MUST be created in `Scripts/ci/` to bridge gaps between existing Scripts and CI requirements.
- **C-005**: Development MUST follow config-driven principles:
  - Hardcoded values (module names, framework lists, paths) MUST be externalized to configuration files (YAML/JSON)
  - Scripts MUST read from configuration rather than embedding magic strings
  - Configuration files MUST be the single source of truth for:
    - XCFramework build order and dependencies
    - Required Pod schemes for pre-build
    - Framework verification requirements per CI stage
  - Example: `Scripts/config/ci-build-stages.yml` defines which frameworks each stage builds and depends on

## Out of Scope

- Introducing new CI features unrelated to restoring reliability (e.g., new platforms or test suites).
- Redesigning the entire CI strategy beyond what is needed to make the existing pipeline pass.
