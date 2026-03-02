# Research: CI Self-Hosted Runner Migration

**Date**: 2026-02-27
**Feature**: CI Self-Hosted Runner Migration

## R1: Self-Hosted Runner Configuration for GitHub Actions

**Decision**: Use label set `[self-hosted, macOS, ARM64, bj_ios]` on the Beijing runner.

**Rationale**: This matches the existing SwiftLint workflow pattern already validated in the project. The `bj_ios` label uniquely identifies the Beijing iOS build machine, preventing accidental scheduling on other self-hosted runners.

**Alternatives considered**:
- Single `self-hosted` label — too broad, could match non-macOS runners
- `macos-latest` — this is a GitHub-hosted label, not self-hosted
- Custom label only (e.g., `bj_ios`) — less discoverable; the `self-hosted, macOS, ARM64` labels follow GitHub's conventions

## R2: Job Architecture (2 Jobs vs 1 Job)

**Decision**: Split into 2 sequential jobs — `validate` (quick) and `build-and-test` (full).

**Rationale**:
- Developers get lint/syntax feedback in ~5 minutes without waiting 40+ minutes for builds
- Build failures don't require re-running validation
- GitHub PR UI shows two independent check statuses, making failure diagnosis instant
- `validate` has no build dependencies (no Xcode project needed), so it runs fast

**Alternatives considered**:
- 1 monolithic job — simpler but no fast feedback; developers wait for entire pipeline
- 11 jobs (current architecture) — maximum parallelism but extreme artifact overhead (~2 GB transfers), complex YAML (1224 lines), and high GitHub-hosted billing
- 3+ jobs (validate + build + test) — unnecessary on a single machine; serial execution means no benefit from job separation beyond validate/build split

## R3: Module List Source (SSOT)

**Decision**: Read module build order from `Scripts/config/release.yaml` at runtime.

**Rationale**: `release.yaml` is already the SSOT for module ordering (Article I.3, Article VI.5). Creating a separate `ci-build-stages.yml` would duplicate this and inevitably drift out of sync.

**Alternatives considered**:
- `ci-build-stages.yml` (original approach) — was deleted because it contained outdated stage groupings; violates SSOT
- Hardcoded list in CI script — would require manual updates when modules change
- Separate CI config file — adds maintenance burden with no benefit on a single-machine runner

## R4: Artifact Strategy

**Decision**: Only upload test results (`TestResults.xcresult` + `coverage.json`). No inter-job artifact transfers.

**Rationale**: On a single self-hosted machine, all steps run sequentially in the same workspace. There is no need to upload/download build artifacts between jobs — they persist on disk. Only test results are uploaded for historical reference and PR review.

**Alternatives considered**:
- Full artifact upload (original 11-job design) — 35 downloads + 18 uploads per run, ~2 GB transfer
- No artifacts at all — loses test result history for debugging
- Upload XCFrameworks — unnecessary for CI validation; they're only needed for release

## R5: Failure Handling Strategy

**Decision**: Two-tier failure model — critical steps (env, workspace, XCFramework builds) fail fast; non-critical steps (DemoApp, consistency check) collect errors and continue.

**Rationale**: If a core module fails to build, all subsequent modules will also fail — continuing wastes time. But if the DemoApp build fails, the unit test results are still valuable. The final summary reports all failures.

**Alternatives considered**:
- All fail-fast — misses useful information from independent steps
- All continue-on-error — wastes time building on broken foundations
- Per-module continue — would hide cascading build failures

## R6: Concurrency Control

**Decision**: Use `concurrency: group: ci-${{ github.ref }}` with `cancel-in-progress: true`.

**Rationale**: When a developer pushes multiple commits quickly, only the latest run matters. Cancelling in-progress runs prevents queue buildup on the single runner.

**Alternatives considered**:
- No concurrency control — leads to queue buildup on single runner
- Queue without cancelling — developer waits for stale runs to finish
- Per-job concurrency — too granular; the whole pipeline should restart
