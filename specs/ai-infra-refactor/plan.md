# Implementation Plan: AI Infrastructure Refactoring

**Branch**: `002-ai-infra-refactor` | **Date**: 2026-01-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-ai-infra-refactor/spec.md`

## Summary

Refactor the AI agent infrastructure to establish clear responsibility boundaries between configuration files. This involves:
1. Simplifying `AGENTS.md` to contain only shared project context (Swift/iOS version, MVVM-Repo pattern, shared resources)
2. Making agent-specific files (`.claude/CLAUDE.md`, `.codex/CODEX.md`, `.cursor/CURSOR.md`) self-contained
3. Unifying skills by moving Claude-exclusive skills to `.agents-shared/skills/`
4. Removing obsolete protocols (escalation, handoff, model-selection)
5. Converting model requirements to soft recommendations

## Technical Context

**Language/Version**: Markdown configuration files (no code compilation)
**Primary Dependencies**: N/A (documentation/configuration refactoring)
**Storage**: N/A
**Testing**: Manual verification via grep searches and line count checks
**Target Platform**: All AI agents (Claude Code, Codex CLI, Cursor IDE)
**Project Type**: Configuration refactoring (not source code)
**Performance Goals**: N/A
**Constraints**: Must maintain compatibility with existing agent workflows
**Scale/Scope**: ~15 files to modify/delete, ~5 files to create/reorganize

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Requirement | Compliance |
|---------|-------------|------------|
| I.1 (Automation First) | N/A - this is configuration refactoring, not repeated manual operation | PASS |
| I.2 (Deterministic Builds) | N/A - not modifying .xcodeproj | PASS |
| I.3 (SSOT) | AGENTS.md will become SSOT for shared project context; each agent file will be SSOT for that agent | PASS |
| I.4 (Sanctity of Automation) | N/A - no build/dependency issues | PASS |
| II.1 (Validation Loop) | Verification via grep searches for removed content | PASS |
| II.2 (Local Verification) | N/A - no code changes requiring round-trip test | PASS |
| III.1 (Module Cohesion) | Each configuration file will have single responsibility | PASS |
| III.2 (Protocol-Oriented) | N/A - not modifying Swift code | PASS |

**Gate Status**: PASS - No violations detected.

## Project Structure

### Documentation (this feature)

```text
specs/002-ai-infra-refactor/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (configuration file structure)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Configuration Files (repository root)

```text
# Files to MODIFY
AGENTS.md                           # Simplify to ~130 lines
.claude/CLAUDE.md                   # Make self-contained
.codex/CODEX.md                     # Align with Claude structure
.cursor/CURSOR.md                   # Align with Claude/Codex structure
docs/AI_Agents.md                   # Update to reflect new architecture

# Files to DELETE
.agents-shared/protocols/escalation.protocol.md
.agents-shared/protocols/handoff.protocol.md
.agents-shared/protocols/model-selection.protocol.md

# Files to MOVE (from .claude/skills/ to .agents-shared/skills/)
.claude/skills/planner.skill.md     → .agents-shared/skills/planner.skill.md
.claude/skills/architect.skill.md   → .agents-shared/skills/architect.skill.md
.claude/skills/deep-reviewer.skill.md → .agents-shared/skills/deep-reviewer.skill.md
.claude/skills/document-writer.skill.md → .agents-shared/skills/document-writer.skill.md

# Files to UPDATE (remove model requirements, add soft recommendations)
.agents-shared/skills/*.skill.md    # All skills get model recommendations instead of requirements
```

**Structure Decision**: This is a configuration refactoring task, not source code modification. The structure follows the existing repository layout with modifications to the `.claude/`, `.codex/`, `.cursor/`, and `.agents-shared/` directories.

## Complexity Tracking

No complexity violations - this is a simplification refactoring that reduces complexity.
