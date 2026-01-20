# Data Model: AI Infrastructure Configuration Files

**Branch**: `002-ai-infra-refactor` | **Date**: 2026-01-20

## Configuration File Hierarchy

```
constitution.md (UNCHANGED - Supreme Law)
    │
    ├── AGENTS.md (SIMPLIFIED - Shared Project Context Only)
    │
    ├── .agents-shared/
    │   ├── skills/ (EXPANDED - All skills unified here)
    │   │   ├── planner.skill.md (MOVED from .claude/)
    │   │   ├── architect.skill.md (MOVED from .claude/)
    │   │   ├── deep-reviewer.skill.md (MOVED from .claude/)
    │   │   ├── document-writer.skill.md (MOVED from .claude/)
    │   │   ├── constitutional-auditor.skill.md (EXISTS)
    │   │   ├── quick-fix.skill.md (EXISTS)
    │   │   ├── refactor-pattern.skill.md (EXISTS)
    │   │   ├── scripts-failure-analyst.skill.md (EXISTS)
    │   │   ├── sources-bug-analyst.skill.md (EXISTS)
    │   │   ├── unit-test-generator.skill.md (EXISTS)
    │   │   └── README.md (UPDATE)
    │   │
    │   └── protocols/ (REDUCED)
    │       ├── task-tier.protocol.md (KEEP - UPDATE model requirements)
    │       ├── output-format.protocol.md (KEEP)
    │       └── README.md (UPDATE)
    │
    ├── .claude/
    │   ├── CLAUDE.md (SELF-CONTAINED)
    │   ├── skills/ (EMPTY or DELETED - all moved to shared)
    │   ├── agents/
    │   └── commands/
    │
    ├── .codex/
    │   ├── CODEX.md (ALIGNED with Claude structure)
    │   └── tools.yml (KEEP)
    │
    └── .cursor/
        └── CURSOR.md or .cursorrules (ALIGNED)
```

## Entity Definitions

### 1. constitution.md (No Changes)

**Responsibility**: Project-level immutable rules
**Content**: Articles I-III (Automation, Validation, Modularity)
**Status**: UNCHANGED

---

### 2. AGENTS.md (Simplified)

**Responsibility**: Shared project context for all agents
**Target Line Count**: ~130 lines (from 330)

**New Structure**:
```markdown
# AI Agent Shared Context

> **Version**: 3.0
> **Last Updated**: [DATE]
> **Applies To**: All AI Agents

## 1. Project Technical Context

**Language**: Swift 5.0
**Target**: iOS 15.0+
**Architecture**: MVVM-Repo pattern
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1

## 2. Pre-Task Checklist

- [ ] Clean working directory (`git status`)
- [ ] On correct branch
- [ ] In development mode (`./Scripts/switch-target.sh pods-dev`)

## 3. Shared Resources

### Skills
Location: `.agents-shared/skills/`
All agents can use all skills.

### Protocols
Location: `.agents-shared/protocols/`
- task-tier.protocol.md - Task classification guide
- output-format.protocol.md - Standardized output format

### Tools
- Scripts/tools/ - Automation scripts
- Sources/tools/ - Swift development tools
- Tests/templates/ - Test templates

## 4. Basic Workflow

### Branching
- feature/, fix/, chore/ prefixes
- Conventional Commits v1.0.0

### Commit Format
<type>(<scope>): <subject>

## 5. Read-Only Zones

These files require human approval to modify:
- constitution.md (all versions)
- ARCHITECTURE.md
- README.md

## 6. Reference Documents

- constitution.md - Supreme law
- .claude/CLAUDE.md - Claude-specific rules
- .codex/CODEX.md - Codex-specific rules
- .cursor/CURSOR.md - Cursor-specific rules
```

---

### 3. .claude/CLAUDE.md (Self-Contained)

**Responsibility**: Complete Claude Code operational rules
**New Structure**:

```markdown
# Claude Code Directives

> **Version**: 3.0
> **Applies To**: Claude Code CLI

## 1. Role Definition

Primary Role: Strategic Technical Advisor
Best For: Deep analysis, architecture, planning, comprehensive review

## 2. Core Imports

@../constitution.md
@../AGENTS.md (for shared project context only)
@../.agents-shared/skills/ (all skills available)

## 3. Strategic Roles

### Role A: Strategic Planner
Skill: .agents-shared/skills/planner.skill.md
When: Complex features, >5 files, public API changes

### Role B: Architect
Skill: .agents-shared/skills/architect.skill.md
When: Design decisions, API contracts

### Role C: Deep Reviewer
Skill: .agents-shared/skills/deep-reviewer.skill.md
When: Complex PRs, pre-release audit

### Role D: Documentation Synthesizer
Skill: .agents-shared/skills/document-writer.skill.md
When: Architecture docs, ADRs

### Role E: Root-Cause Analyst
Skills: .agents-shared/skills/scripts-failure-analyst.skill.md
        .agents-shared/skills/sources-bug-analyst.skill.md
When: Failures in scripts or source code

## 4. Available Skills

All skills in .agents-shared/skills/ are available.
See README in that directory for full list.

## 5. Best Practices

- State assumed role at start of response
- Cite constitutional articles for significant recommendations
- Recommend validation steps before task completion

## 6. Output Format

See .agents-shared/protocols/output-format.protocol.md
```

---

### 4. .codex/CODEX.md (Aligned)

**Responsibility**: Complete Codex CLI operational rules
**New Structure**:

```markdown
# Codex CLI Directives

> **Version**: 2.0
> **Applies To**: Codex CLI

## 1. Role Definition

Primary Role: Tactical Code Executor
Interaction Mode: Single-shot execution
Best For: Quick fixes, batch operations, test generation

## 2. Core Imports

@../constitution.md
@../AGENTS.md (for shared project context only)
@../.agents-shared/skills/ (all skills available)

## 3. Available Skills

All skills in .agents-shared/skills/ are available.
Commonly used:
- unit-test-generator.skill.md
- quick-fix.skill.md
- constitutional-auditor.skill.md

## 4. Security Policy

See tools.yml for allowed/denied commands.

## 5. Output Format

### Trivial Tasks
✓ [one-line summary]
File: path/to/file.swift:L42

### Standard Tasks
See .agents-shared/protocols/output-format.protocol.md

## 6. Best Practices

- One-shot execution mindset
- Clear, specific task descriptions
- Verify with suggested commands
```

---

### 5. .cursor/CURSOR.md (Aligned)

**Responsibility**: Complete Cursor IDE operational rules
**New Structure**:

```markdown
# Cursor IDE Directives

> **Version**: 2.0
> **Applies To**: Cursor IDE

## 1. Role Definition

Primary Role: Interactive Development Partner
Interaction Mode: IDE-integrated, real-time feedback
Best For: Interactive refactoring, code exploration, iterative development

## 2. Core Imports

@../constitution.md
@../AGENTS.md (for shared project context only)
@../.agents-shared/skills/ (all skills available)

## 3. Cursor-Specific Features

### Chat Mode (Cmd+L)
Best for: Analysis, explanation, planning
Usage: @codebase, @file:path, @folder:path

### Inline Edit (Cmd+K)
Best for: Quick, localized changes

### Composer Mode
Best for: Multi-file changes

## 4. Available Skills

All skills in .agents-shared/skills/ are available.

## 5. Best Practices

- Match existing code style
- Use meaningful variable names
- Follow Quick/Nimble BDD style for tests
```

---

### 6. Skill File Structure (Updated)

**New Frontmatter Pattern**:
```yaml
---
name: planner
description: Strategic task planning and breakdown
category: strategic
shared: true
applicable_agents: [claude-code, codex, cursor]
recommended_model: opus  # For complex reasoning - user may override
allowed-tools: [Read, Glob, Grep]
---
```

**Changes from Current**:
- `shared: false` → `shared: true`
- `applicable_agents: [claude-code]` → `applicable_agents: [claude-code, codex, cursor]`
- `required_model: opus` → `recommended_model: opus  # For complex reasoning - user may override`

---

## Files to Delete

| File | Reason |
|------|--------|
| `.agents-shared/protocols/escalation.protocol.md` | Replaced by Speckit |
| `.agents-shared/protocols/handoff.protocol.md` | Replaced by Speckit |
| `.agents-shared/protocols/model-selection.protocol.md` | Manual selection preferred |
| `.claude/skills/planner.skill.md` | Moved to shared |
| `.claude/skills/architect.skill.md` | Moved to shared |
| `.claude/skills/deep-reviewer.skill.md` | Moved to shared |
| `.claude/skills/document-writer.skill.md` | Moved to shared |
| `.claude/skills/constitutional-auditor.skill.md` | Duplicate of shared |
| `.claude/skills/scripts-failure-analyst.skill.md` | Duplicate of shared |
| `.claude/skills/sources-bug-analyst.skill.md` | Duplicate of shared |
| `.claude/skills/unit-test-generator.skill.md` | Duplicate of shared |

---

## Validation Rules

1. **No Duplicates**: Each skill exists in exactly one location (`.agents-shared/skills/`)
2. **Self-Contained Agent Files**: Each agent file can be read standalone
3. **SSOT**: AGENTS.md is SSOT for project technical context
4. **No Model Requirements**: Only model recommendations exist
5. **No Escalation/Handoff**: Zero references to these protocols
