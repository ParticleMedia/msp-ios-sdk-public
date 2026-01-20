# Implementation Plan: AI 基础设施重组

**Branch**: `ai-infra-reorg` | **Date**: 2026-01-20 | **Status**: Implemented | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/ai-infra-reorg/spec.md`

## Summary

重组 AI 基础设施配置，包括：将 spec 命名从数字前缀改为语义化名称、将架构模式（MVVM-Repo、config-driven）移至领域特定共享文件、统一三个 AI 工具（Claude、Codex、Cursor）的分层配置、删除冗余的根目录 CLAUDE.md、补充 Sources/constitution.md 的最佳实践、修复 speckit 对分层 constitution 的检查。

## Technical Context

**Language/Version**: Bash (POSIX-compliant), Markdown
**Primary Dependencies**: speckit workflow scripts, git
**Storage**: N/A (documentation/configuration refactoring)
**Testing**: Manual validation + script execution verification
**Target Platform**: macOS/Linux (development environment)
**Project Type**: Configuration/Documentation refactoring
**Performance Goals**: N/A (no runtime code)
**Constraints**: Must comply with Federal Constitution Article I (Automation First)
**Scale/Scope**: ~20 markdown files to create/modify, 2 bash scripts to modify

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Federal Constitution Compliance

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| I.1 (Automation First) | Manual operations > 2x must be scripted | ✅ PASS | Script modifications follow this principle |
| I.2 (Deterministic Builds) | No direct .xcodeproj modification | ✅ N/A | This feature doesn't touch Xcode projects |
| I.3 (SSOT) | Podfile is single source for dependencies | ✅ N/A | No dependency changes |
| I.4 (Sanctity of Automated Process) | No temporary manual workarounds | ✅ PASS | All changes via scripts/configs |
| II.1 (Validation Loop) | Changes must pass automated validation | ✅ PASS | Will validate via script execution |
| II.2 (Local Verification) | Run round-trip-test.sh before commit | ✅ PASS | Will include in validation |
| III.1 (Module Cohesion) | Core/Adapters separation | ✅ N/A | No code module changes |
| III.2 (Protocol-Oriented Design) | Use protocols | ✅ N/A | No Swift code changes |

### Scripts Constitution Compliance

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| VI.1 (Error Handling) | Scripts must use `set -euo pipefail` | ✅ PASS | Modified scripts will maintain this |
| VI.2 (Idempotency) | Scripts should be idempotent | ✅ PASS | Spec migration will be idempotent |
| VI.3 (POSIX Compliance) | Shell scripts must be POSIX-compliant | ✅ PASS | Will ensure compliance |

### Sources Constitution Compliance

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| IV.1-4.3 (Swift Practices) | Swift code standards | ✅ N/A | No Swift code changes |
| V.1-5.2 (TDD) | Red-Green-Refactor, Quick/Nimble | ✅ N/A | No Swift code changes |

**GATE RESULT**: ✅ PASS - All applicable articles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/ai-infra-reorg/           # Note: Will be renamed from 003-ai-infra-reorg
├── plan.md                     # This file
├── research.md                 # Phase 0 output
├── data-model.md               # Phase 1 output
├── quickstart.md               # Phase 1 output
└── tasks.md                    # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
# Configuration files to CREATE
Sources/AGENTS-SOURCES.md       # NEW: MVVM-Repo architecture guide
Scripts/AGENTS-SCRIPTS.md       # NEW: Config-driven development guide

# Configuration files to MODIFY
AGENTS.md                       # Remove MVVM-Repo, add Recent Changes, add XCodeGen workflow
.claude/CLAUDE.md               # Add @import for shared rules
.codex/CODEX.md                 # Add @import for shared rules
.cursor/CURSOR.md               # Add @import for shared rules
Sources/constitution.md         # Add logging, error handling, XCodeGen rule (precision)

# Configuration files to DELETE
CLAUDE.md                       # Root CLAUDE.md (redundant)

# Scripts to MODIFY
.specify/scripts/bash/create-new-feature.sh    # Semantic naming
.specify/scripts/bash/update-agent-context.sh  # Update AGENTS.md instead

# Speckit prompts to MODIFY (for constitutional review)
.codex/prompts/speckit-plan.md  # Multi-constitution check
.claude/skills/*.md             # If needed for constitutional review

# Directories to RENAME (spec migration)
specs/001-unit-test-setup/      → specs/unit-test-setup/
specs/002-ai-infra-refactor/    → specs/ai-infra-refactor/
specs/003-ai-infra-reorg/       → specs/ai-infra-reorg/
```

**Structure Decision**: Configuration/Documentation refactoring with no new code directories. All changes are to existing markdown files and bash scripts.

## Complexity Tracking

> No constitutional violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
