# Research: AI Infrastructure Refactoring

**Branch**: `002-ai-infra-refactor` | **Date**: 2026-01-20

## Research Tasks Completed

### 1. Current State Analysis

**AGENTS.md Current State**:
- Line count: 330 lines
- Contains: Multi-agent architecture, task tier system, agent roles, shared capabilities, SOPs, Git workflow, read-only zones, escalation protocol, handoff protocol, output format
- Issues: Too much content, duplicates info in agent-specific files, contains obsolete escalation/handoff sections

**Decision**: Simplify to ~130 lines containing only shared project context
**Rationale**: Agent-specific rules belong in agent-specific files; escalation/handoff replaced by Speckit

### 2. Skills Distribution Analysis

**Currently in `.claude/skills/`** (8 files):
- architect.skill.md (strategic)
- constitutional-auditor.skill.md (shared duplicate)
- deep-reviewer.skill.md (strategic)
- document-writer.skill.md (strategic)
- planner.skill.md (strategic)
- scripts-failure-analyst.skill.md (shared duplicate)
- sources-bug-analyst.skill.md (shared duplicate)
- unit-test-generator.skill.md (shared duplicate)

**Currently in `.agents-shared/skills/`** (6 skills + 1 README):
- constitutional-auditor.skill.md
- quick-fix.skill.md
- refactor-pattern.skill.md
- scripts-failure-analyst.skill.md
- sources-bug-analyst.skill.md
- unit-test-generator.skill.md

**Decision**: Move these from `.claude/skills/` to `.agents-shared/skills/`:
- planner.skill.md
- architect.skill.md
- deep-reviewer.skill.md
- document-writer.skill.md

**Rationale**: Unified skills access for all agents; model recommendations instead of requirements
**Note**: 4 skills are duplicated between directories - the `.claude/` versions will be deleted

### 3. Protocols Analysis

**Currently in `.agents-shared/protocols/`**:
- escalation.protocol.md → DELETE (replaced by Speckit)
- handoff.protocol.md → DELETE (replaced by Speckit)
- model-selection.protocol.md → DELETE (manual model selection preferred)
- output-format.protocol.md → KEEP (useful for consistency)
- task-tier.protocol.md → KEEP (useful classification reference)
- README.md → UPDATE

**Decision**: Delete 3 protocols, keep 2, update README
**Rationale**: Speckit replaces agent-to-agent collaboration; model selection is manual

### 4. Model Recommendations Pattern

**Current Pattern** (in skills):
```yaml
required_model: opus
```

**New Pattern** (soft recommendation):
```yaml
recommended_model: opus  # For complex reasoning tasks - user may override
```

**Decision**: Replace `required_model` with `recommended_model` and add clarifying comment
**Rationale**: User has final say on model selection; recommendations guide but don't restrict

### 5. Agent Configuration Structure

**Target Structure for Each Agent File**:
1. Header (version, last updated, applies to)
2. Core Imports (constitution, shared skills reference)
3. Role Definition (what this agent is good at)
4. Available Skills (reference to `.agents-shared/skills/`)
5. Best Practices (agent-specific tips)
6. Output Format (standardized)

**Decision**: Align all three agent files to this structure
**Rationale**: Consistency reduces learning curve

### 6. AGENTS.md New Structure

**Sections to KEEP** (simplified):
1. Project Technical Context (Swift 5.0, iOS 15.0+, MVVM-Repo)
2. Shared Resources Locations
3. Basic Workflow (branching, commit format)
4. Read-Only Zones
5. Pre-Task Checklist

**Sections to REMOVE**:
- Multi-Agent Architecture Overview (goes to docs/AI_Agents.md)
- Task Tier System (reference task-tier.protocol.md instead)
- Agent Roles (each agent file is self-contained)
- Agent-Specific Configuration (each agent file is self-contained)
- Escalation Protocol
- Handoff Protocol
- Output Format (reference output-format.protocol.md instead)

**Decision**: AGENTS.md becomes minimal shared context file
**Rationale**: Single responsibility - project info only, not agent orchestration

## Alternatives Considered

### Alternative A: Keep Escalation/Handoff but Simplify
- **Rejected**: Speckit provides structured workflow that supersedes this
- **Reason**: Would create confusion with two parallel systems

### Alternative B: Keep Model Requirements as Warnings
- **Rejected**: "Required" language implies enforcement
- **Reason**: Soft recommendations with "Recommended" language is clearer

### Alternative C: Create Separate Model Guide Document
- **Rejected**: Adds another file to maintain
- **Reason**: Inline recommendations in skills are sufficient

## Unresolved Questions

None - all clarifications addressed in spec.
