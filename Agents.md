# AI Agent Interaction Protocol

> **Version**: 2.0
> **Last Updated**: 2026-01-14
> **Applies To**: All AI Agents (Claude Code, Codex CLI, Cursor IDE, GitHub Copilot, etc.)

This document is the primary operational manual for all AI Agents contributing to this project. It defines rules, SOPs, and safety protocols. Adherence is mandatory.

---

## 0. Pre-Task Checklist

Before starting any task, verify:
- [ ] Clean Working Directory (`git status`).
- [ ] On the correct branch.
- [ ] In development mode (`./Scripts/switch-target.sh pods-dev`).

---

## 1. Multi-Agent Architecture Overview

This project supports three primary AI agents with distinct roles:

| Agent | Type | Best For | Tier Range |
|-------|------|----------|------------|
| **Claude Code** | CLI | Deep analysis, architecture, planning | Tier 2-3 |
| **Codex CLI** | CLI | Quick execution, one-shot tasks | Tier 0-1 |
| **Cursor IDE** | IDE | Interactive development, real-time feedback | Tier 1-2 |

### Task Tier System

| Tier | Name | Description | Agent | Model |
|------|------|-------------|-------|-------|
| **0** | Trivial | Mechanical changes, no logic | Codex | Haiku |
| **1** | Standard | Pattern-based implementation | Codex/Cursor | Sonnet 3.5 |
| **2** | Complex | Requires analysis and judgment | Claude/Cursor | Sonnet 4 |
| **3** | Strategic | Architectural decisions, public API | Claude | Opus |

### Agent Selection Guide

**Use Claude Code when:**
- Task requires deep reasoning or synthesis
- Architectural decisions needed
- Complex multi-step planning
- Comprehensive code review
- Task tier is 2-3

**Use Codex CLI when:**
- Quick, one-shot execution needed
- Task is mechanical and well-defined
- Batch operations on multiple files
- Task tier is 0-1

**Use Cursor IDE when:**
- Interactive development preferred
- Real-time feedback needed
- Working within single file context
- Task tier is 1-2

---

## 2. Core Principles

**Foundation**: All actions must adhere to the principles in all applicable `constitution.md` files.

**Prime Directive**: When in doubt, ask for clarification.

**Tool-First Approach**: Always prefer using existing automation scripts.

**Cost Awareness**: Use appropriate model for task complexity (Haiku for trivial, Opus for strategic).

---

## 3. Shared Capability Layer

All agents share access to capabilities in `.agents-shared/`:

### 3.1 Shared Protocols (`.agents-shared/protocols/`)

| Protocol | Purpose |
|----------|---------|
| `task-tier.protocol.md` | Task classification system |
| `model-selection.protocol.md` | Model choice guidance |
| `escalation.protocol.md` | When to escalate tasks |
| `handoff.protocol.md` | Agent-to-agent transfers |
| `output-format.protocol.md` | Standardized output format |

### 3.2 Shared Skills (`.agents-shared/skills/`)

**Analysis Skills**:
| Skill | Purpose | Tier |
|-------|---------|------|
| `constitutional-auditor.skill.md` | Check constitution compliance | 1 |
| `scripts-failure-analyst.skill.md` | Diagnose CI/CD failures | 2 |
| `sources-bug-analyst.skill.md` | Diagnose Swift crashes | 2 |

**Generation Skills**:
| Skill | Purpose | Tier |
|-------|---------|------|
| `unit-test-generator.skill.md` | Generate Quick/Nimble tests | 1 |
| `quick-fix.skill.md` | Apply mechanical code fixes | 0-1 |
| `refactor-pattern.skill.md` | Apply refactoring patterns | 1-2 |

### 3.3 Shared Tools

**Scripts/tools/** (Automation & CI):
| Tool | Usage | Purpose |
|------|-------|---------|
| `get-test-template.sh` | `./Scripts/tools/get-test-template.sh` | Print unit test template |
| `validate-script.sh` | `./Scripts/tools/validate-script.sh <path>` | Run shellcheck on script |

**Sources/tools/** (Swift Development):
| Tool | Usage | Purpose |
|------|-------|---------|
| `find-class.sh` | `./Sources/tools/find-class.sh <TypeName>` | Find type definition |
| `list-public-api.sh` | `./Sources/tools/list-public-api.sh <ModulePath>` | List public API surface |
| `check-imports.sh` | `./Sources/tools/check-imports.sh [ModulePath]` | Check for forbidden imports |

### 3.4 Shared Templates

| Template | Location | Purpose |
|----------|----------|---------|
| Unit Test | `Tests/templates/unit_test_spec.swift.template` | Quick/Nimble test boilerplate |
| Release Notes | `Scripts/templates/release-notes-template.md` | Changelog entry format |

**Placeholders**: Use `{{placeholder_name}}` syntax.

---

## 4. Agent-Specific Configuration

### 4.1 Claude Code (`.claude/`)

Claude Code has access to strategic skills requiring deep reasoning:

| Skill | Purpose | Model |
|-------|---------|-------|
| `planner.skill.md` | Complex task planning | Opus |
| `architect.skill.md` | Architectural design | Opus |
| `deep-reviewer.skill.md` | Comprehensive code review | Opus |
| `document-writer.skill.md` | Technical documentation | Opus |

**Configuration**: `.claude/CLAUDE.md`

### 4.2 Codex CLI (`.codex/`)

Codex CLI is optimized for quick, tactical execution:

**Configuration**: `.codex/CODEX.md`
**Security Policy**: `.codex/tools.yml`

### 4.3 Cursor IDE (`.cursor/`)

Cursor IDE provides interactive development support:

**Configuration**: `.cursor/CURSOR.md`
**Rules**: `.cursor/settings/rules.json`

---

## 5. Authorized Toolbox

| Script | Function |
|--------|----------|
| `./Scripts/switch-target.sh <mode>` | Switches the SDK's operational mode |
| `./Scripts/target-switching/round-trip-test.sh` | Performs a full round-trip validation |
| `./Scripts/msp-release.sh --tier Preflight <ver>` | Executes a pre-release validation |
| `pod install` | Installs CocoaPods dependencies |
| `XcodeGen` | Generates the Xcode project |

---

## 6. Standard Operating Procedures (SOPs)

### SOP-6.1: General Workflow

1. Create a new branch.
2. Make code changes.
3. Write or update tests according to the constitution.
4. Write a Conventional Commit message.

### SOP-6.2: Domain-Specific Workflow: `Sources/`

- **Context**: When working on Swift/Objective-C files inside `Sources/`.
- **Procedure**: Follow SOP-6.1, and additionally ensure all new public APIs are documented with Swift DocC.

### SOP-6.3: Writing Unit Tests

- **Context**: When asked to write unit tests.
- **Procedure**:
  1. Adhere to all TDD principles in `Sources/constitution.md` and readability principles in `Tests/constitution.md`.
  2. Use **Quick & Nimble**.
  3. Use the template at `Tests/templates/unit_test_spec.swift.template` for boilerplate.
  4. Place files correctly: Specs in `Tests/<Module>Tests/Specs/`, Mocks in `Tests/<Module>Tests/Mocks/`.
  5. Follow the BDD style (`describe-context-it`).

---

## 7. Git & Pull Request (PR) Workflow

**Core Tenet**: A disciplined Git workflow is essential.

### 7.1 Branching

Use `feature/`, `fix/`, or `chore/` prefixes.

### 7.2 Commits

Must follow Conventional Commits v1.0.0.

### 7.3 PRs

- Title must be clear (e.g., `[MSP-123] feat: ...`)
- Must be rebased on `main` and pass all checks before review

---

## 8. Read-Only Zone

The following files are read-only for tactical agents (Codex, Cursor, Copilot):
- `constitution.md` (all versions)
- `.claude/` (the entire directory)
- `ARCHITECTURE.md`
- `README.md`

---

## 9. Escalation Protocol

**[Critical]** If any of the following conditions are met, the Agent **must halt** and recommend escalation.

### Automatic Escalation (Must Escalate)

| Rule | Condition | Escalate To |
|------|-----------|-------------|
| E-1 | Any modification to a `public` or `open` API | Claude Code / Human |
| E-2 | Any attempt to modify `constitution.md` or SSOT files | Human |
| E-3 | Diff exceeds 150 lines, spans >5 files, or affects `Sources/Core/` | Claude Code |
| E-4 | Same error occurs twice in a row | Claude Code / Human |
| E-5 | New dependency added or major version changed | Human |
| E-6 | Root cause unclear after initial investigation | Claude Code |
| E-7 | Task requires model upgrade (Haiku → Opus) | Claude Code |

### Recommended Escalation (Consider Escalating)

| Condition | Recommendation |
|-----------|----------------|
| Multi-module changes | Consider Claude Code for planning |
| Performance optimization | Consider Claude Code for analysis |
| Security-sensitive code | Consider Claude Code / Human review |

---

## 10. Handoff Protocol

### Downward Handoff (Planning → Execution)

Claude Code plans, delegates to Codex/Cursor for execution:

```yaml
handoff:
  type: downward
  from: claude-code
  to: codex
  context:
    task: "Add unit test for BidLoader"
    skill: ".agents-shared/skills/unit-test-generator.skill.md"
    template: "Tests/templates/unit_test_spec.swift.template"
  verification:
    command: "swift test --filter BidLoaderSpec"
    criteria: "All tests pass"
```

### Upward Handoff (Blocked → Analysis)

Codex/Cursor blocked, escalates to Claude Code:

```yaml
handoff:
  type: upward
  from: codex
  to: claude-code
  reason: "root_cause_unclear"
  context:
    error: "Test fails with unexpected nil"
    attempts: 2
    files_touched: ["BidLoader.swift", "BidLoaderSpec.swift"]
  request: "Analyze root cause of nil crash"
```

### Lateral Handoff (Mode Switch)

Codex CLI → Cursor IDE for interactive work:

```yaml
handoff:
  type: lateral
  from: codex
  to: cursor
  reason: "interactive_preferred"
  context:
    current_file: "Sources/Core/MSPCore/BidLoader.swift"
    task: "Refactor bid validation logic"
```

---

## 11. Output Format

All agents should follow standardized output format from `.agents-shared/protocols/output-format.protocol.md`:

```yaml
---
task_tier: [0|1|2|3]
model: [model-id]
agent: [agent-name]
timestamp: [ISO8601]
---
```

---

## 12. Related Documents

- [constitution.md](constitution.md) - Project governance rules
- [.agents-shared/](/.agents-shared/) - Shared capability layer
- [.claude/CLAUDE.md](.claude/CLAUDE.md) - Claude strategic directives
- [.codex/CODEX.md](.codex/CODEX.md) - Codex operational rules
- [.cursor/CURSOR.md](.cursor/CURSOR.md) - Cursor IDE guidance
- [Docs/AI_AGENTS.md](Docs/AI_AGENTS.md) - Detailed AI architecture documentation
