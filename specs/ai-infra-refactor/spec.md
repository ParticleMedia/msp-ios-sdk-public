# Feature Specification: AI Infrastructure Refactoring

**Feature Branch**: `ai-infra-refactor``
**Created**: 2026-01-20
**Status**: Implemented
**Input**: User description: "重构 AI 基建：简化 AGENTS.md，对齐 Claude/Codex/Cursor 能力，删除 escalation/handoff，明确各配置文件职责边界"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clear Configuration File Responsibilities (Priority: P1)

As a developer (human or AI agent), I want each configuration file to have a clear, non-overlapping responsibility so that I know exactly where to find and modify specific rules.

**Why this priority**: This is the foundation of the refactoring - without clear boundaries, all other changes will create confusion.

**Independent Test**: Can be fully tested by reading each configuration file and confirming no duplicate content exists across files, and each file's purpose is immediately clear from its content.

**Acceptance Scenarios**:

1. **Given** a developer needs to understand project-level immutable rules, **When** they read `constitution.md`, **Then** they find ONLY automation, validation, and modularity principles (no agent-specific content)
2. **Given** a developer needs basic project technical info (Swift version, architecture pattern), **When** they read `AGENTS.md`, **Then** they find ONLY shared project context (no escalation, handoff, or agent comparisons)
3. **Given** a Claude Code user wants to know Claude's capabilities, **When** they read `.claude/CLAUDE.md`, **Then** they find complete Claude operational rules without needing to read AGENTS.md

---

### User Story 2 - Unified Agent Capabilities (Priority: P1)

As an AI agent user, I want all agents (Claude, Codex, Cursor) to have access to the same skills so that I can freely choose which agent to use based on my workflow preference, not capability limitations.

**Why this priority**: Removing artificial capability barriers enables more flexible workflows and reduces confusion about "which agent can do what".

**Independent Test**: Can be tested by verifying all skills are accessible from any agent's configuration and no skill is marked as "exclusive" to one agent.

**Acceptance Scenarios**:

1. **Given** a skill exists in `.agents-shared/skills/`, **When** any agent (Claude, Codex, Cursor) is configured, **Then** that agent can reference and use the skill
2. **Given** skills previously marked as "Claude-exclusive" (planner, architect, deep-reviewer, document-writer), **When** I check the new structure, **Then** they are moved to `.agents-shared/skills/` and accessible to all agents

---

### User Story 3 - Remove Obsolete Protocols (Priority: P2)

As a developer, I want obsolete protocols (escalation, handoff) removed so that the configuration is simpler and doesn't contain unused mechanisms.

**Why this priority**: These protocols were designed for multi-agent collaboration workflows that are now replaced by Speckit. Removing them reduces maintenance burden and confusion.

**Independent Test**: Can be tested by searching for escalation/handoff references and confirming they no longer exist in active configuration files.

**Acceptance Scenarios**:

1. **Given** the `escalation.protocol.md` and `handoff.protocol.md` files exist, **When** the refactoring is complete, **Then** these files are deleted
2. **Given** `AGENTS.md` contains Sections 9 (Escalation Protocol) and 10 (Handoff Protocol), **When** the refactoring is complete, **Then** these sections are removed
3. **Given** `.claude/CLAUDE.md`, `.codex/CODEX.md`, `.cursor/CURSOR.md` reference escalation rules, **When** the refactoring is complete, **Then** these references are removed

---

### User Story 4 - Convert Model Restrictions to Recommendations (Priority: P2)

As an AI agent user, I want model restrictions converted to soft recommendations so that I can manually choose which model to use while still having guidance available.

**Why this priority**: Model selection is better handled manually by the user based on task complexity, but having recommendations helps new users make informed choices.

**Independent Test**: Can be tested by verifying skills contain optional model recommendations (not requirements) and `model-selection.protocol.md` is deleted.

**Acceptance Scenarios**:

1. **Given** skills previously required specific models (e.g., "Requires Opus"), **When** the refactoring is complete, **Then** model requirements are converted to soft recommendations (e.g., "Recommended: Opus for deep reasoning tasks")
2. **Given** `model-selection.protocol.md` exists, **When** the refactoring is complete, **Then** this file is deleted
3. **Given** a skill contains model recommendations, **When** a user reads the skill, **Then** the recommendation is clearly marked as optional guidance, not a requirement

---

### User Story 5 - Cursor Configuration Alignment (Priority: P3)

As a Cursor IDE user, I want Cursor's configuration to follow the same structure as Claude and Codex so that the experience is consistent across all agents.

**Why this priority**: Consistency across agents reduces learning curve and maintenance effort.

**Independent Test**: Can be tested by comparing the structure of `.cursor/` with `.claude/` and `.codex/` and confirming they follow a similar organizational pattern.

**Acceptance Scenarios**:

1. **Given** `.cursor/CURSOR.md` exists but doesn't follow Cursor's `.cursorrules` conventions, **When** the refactoring is complete, **Then** it is updated to follow Cursor IDE conventions
2. **Given** Cursor needs to reference shared skills, **When** the refactoring is complete, **Then** `.cursor/` configuration properly imports from `.agents-shared/`

---

### Edge Cases

- What happens if a skill references a deleted protocol (escalation/handoff)? → Update the skill to remove the reference
- What happens if external documentation references the old structure? → `docs/AI_Agents.md` must be updated to reflect the new structure
- What happens if an agent configuration imports a deleted file? → All import statements must be verified and updated

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `constitution.md` MUST contain ONLY project-level immutable rules (automation, validation, modularity) - no changes needed if already clean
- **FR-002**: `AGENTS.md` MUST be simplified to contain ONLY: Swift/iOS version, architecture pattern (MVVM-Repo), shared resources locations, basic workflow (branching, commit format), read-only zones
- **FR-003**: `.claude/CLAUDE.md` MUST be self-contained with complete Claude operational rules
- **FR-004**: `.codex/CODEX.md` MUST be aligned with Claude's structure and have access to all shared skills
- **FR-005**: `.cursor/CURSOR.md` (or `.cursorrules`) MUST be aligned with the other agents' structure
- **FR-006**: All skills previously in `.claude/skills/` MUST be moved to `.agents-shared/skills/`
- **FR-007**: `escalation.protocol.md` and `handoff.protocol.md` MUST be deleted
- **FR-008**: `model-selection.protocol.md` MUST be deleted
- **FR-009**: All references to escalation/handoff in agent configurations MUST be removed
- **FR-010**: Model requirements in skills MUST be converted to soft recommendations (e.g., "Recommended: Opus" instead of "Requires: Opus")
- **FR-011**: `docs/AI_Agents.md` MUST be updated to reflect the new architecture

### Key Entities

- **Configuration File**: A markdown file that defines rules for agents or the project (constitution.md, AGENTS.md, CLAUDE.md, etc.)
- **Skill**: A reusable multi-step procedure that agents can invoke (.skill.md files)
- **Protocol**: A standard definition for agent behavior (.protocol.md files) - some to be deleted
- **Agent Directory**: A directory containing agent-specific configuration (.claude/, .codex/, .cursor/)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Total line count of AGENTS.md reduced by at least 60% (from ~330 lines to ~130 lines)
- **SC-002**: Zero duplicate content between constitution.md, AGENTS.md, and agent-specific CLAUDE.md/CODEX.md/CURSOR.md files
- **SC-003**: All skills (including former Claude-exclusive) accessible from `.agents-shared/skills/` (100% skill availability to all agents)
- **SC-004**: Zero references to escalation, handoff, or model-selection protocols in active configuration files
- **SC-005**: A developer can determine each file's responsibility within 30 seconds by reading only the file header

## Clarifications

### Session 2026-01-20

- Q: Should model restrictions be completely removed or converted to soft recommendations? → A: Convert to soft recommendations (optional guidance, not requirements)

## Assumptions

- Speckit workflows have fully replaced the need for agent-to-agent escalation and handoff mechanisms
- Users prefer manual model selection with optional guidance over configuration-enforced model restrictions
- The `.cursor/` directory structure can be adapted to follow Cursor IDE conventions if needed
- No archived files needed - obsolete files will be deleted entirely
