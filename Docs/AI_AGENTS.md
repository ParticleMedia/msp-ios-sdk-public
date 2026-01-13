# AI Agent Architecture

> **Version**: 1.0
> **Last Updated**: 2026-01-13

This document describes the AI agent infrastructure for the MSP iOS SDK project, enabling consistent collaboration between human developers and AI assistants.

## Overview

The project supports multiple AI agents (Claude, Cursor, Copilot, Codex, etc.) through a layered architecture that separates:

- **Shared Resources**: Tools and templates usable by all agents
- **Agent-Specific Config**: Claude-specific skills, commands, and agents
- **Governance**: Constitution and operational rules

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Human Developer                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
         ┌──────────────────┐    ┌──────────────────┐
         │      Claude      │    │  Cursor/Copilot  │
         │                  │    │     /Codex       │
         └────────┬─────────┘    └────────┬─────────┘
                  │                       │
                  │  .claude/             │
                  │  ├── commands/        │
                  │  ├── skills/          │
                  │  ├── agents/          │
                  │  └── tools/ ──────────┼──────┐
                  │         (wrappers)    │      │
                  │                       │      ▼
         ┌────────┴───────────────────────┴──────────────┐
         │              Shared Resources                  │
         │  ┌─────────────────┐  ┌─────────────────────┐ │
         │  │ Scripts/tools/  │  │   Sources/tools/    │ │
         │  │ Scripts/templates│  │   Tests/templates/ │ │
         │  └─────────────────┘  └─────────────────────┘ │
         └───────────────────────────────────────────────┘
                                │
         ┌──────────────────────┴──────────────────────┐
         │                 Governance                   │
         │  constitution.md    AGENTS.md    CLAUDE.md  │
         └─────────────────────────────────────────────┘
```

## Directory Structure

```
msp-ios-sdk/
├── AGENTS.md                    # Operations manual for ALL agents
├── constitution.md              # Supreme law (root)
│
├── Scripts/
│   ├── tools/                   # Shared automation tools
│   │   ├── get-test-template.sh
│   │   └── validate-script.sh
│   ├── templates/
│   │   └── release-notes-template.md
│   └── constitution.md          # Scripts-specific rules
│
├── Sources/
│   ├── tools/                   # Shared Swift development tools
│   │   ├── find-class.sh
│   │   ├── list-public-api.sh
│   │   └── check-imports.sh
│   └── constitution.md          # Sources-specific rules
│
├── Tests/
│   ├── templates/
│   │   └── unit_test_spec.swift.template
│   └── constitution.md          # Tests-specific rules
│
└── .claude/                     # Claude-specific configuration
    ├── CLAUDE.md                # Claude strategic directives
    ├── tools/                   # Tool wrappers (Claude syntax)
    ├── skills/                  # Reusable knowledge modules
    ├── commands/                # User-facing slash commands
    └── agents/                  # Autonomous sub-agents
```

## Capability Types

### For All Agents

| Type | Location | Description |
|------|----------|-------------|
| **Shared Tools** | `Scripts/tools/`, `Sources/tools/` | Executable shell scripts |
| **Templates** | `*/templates/` | Static files with `{{placeholder}}` syntax |
| **Constitution** | `*/constitution.md` | Rules and constraints |
| **AGENTS.md** | Root | Operational procedures |

### Claude-Specific

| Type | Location | Description |
|------|----------|-------------|
| **Tool** | `.claude/tools/` | Wrappers for shared scripts with `run:` syntax |
| **Skill** | `.claude/skills/` | Multi-step knowledge modules (`*.skill.md`) |
| **Command** | `.claude/commands/` | User slash commands (e.g., `/test`) |
| **Agent** | `.claude/agents/` | Autonomous specialists (`*.agent.md`) |

## Shared Tools Reference

### Scripts/tools/ (Automation)

| Tool | Usage | Description |
|------|-------|-------------|
| `get-test-template.sh` | `./Scripts/tools/get-test-template.sh` | Print unit test template |
| `validate-script.sh` | `./Scripts/tools/validate-script.sh <path>` | Validate shell script with shellcheck |

### Sources/tools/ (Swift Development)

| Tool | Usage | Description |
|------|-------|-------------|
| `find-class.sh` | `./Sources/tools/find-class.sh <TypeName>` | Find class/struct/protocol definition |
| `list-public-api.sh` | `./Sources/tools/list-public-api.sh <ModulePath>` | List public API surface |
| `check-imports.sh` | `./Sources/tools/check-imports.sh [ModulePath]` | Check for forbidden imports |

## Templates Reference

| Template | Location | Placeholders |
|----------|----------|--------------|
| Unit Test | `Tests/templates/unit_test_spec.swift.template` | `{{module_name}}`, `{{class_name}}` |
| Release Notes | `Scripts/templates/release-notes-template.md` | Various |

## Claude Capabilities

### Skills (`*.skill.md`)

| Skill | Purpose |
|-------|---------|
| `architect.skill.md` | Design architectural solutions |
| `constitutional-auditor.skill.md` | Check code compliance |
| `scripts-failure-analyst.skill.md` | Diagnose CI/CD failures |
| `sources-bug-analyst.skill.md` | Diagnose Swift bugs |
| `unit-test-generator.skill.md` | Generate test boilerplate |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/test` | `/test <ClassName>` | Generate unit test for a class |

### Agents (`*.agent.md`)

| Agent | Purpose |
|-------|---------|
| `code-reviewer.agent.md` | Full PR review with constitutional audit |

## Composition Rules

```
┌─────────────┐
│  Commands   │ ─── User entry points (slash commands)
└──────┬──────┘
       │ invoke
       ▼
┌─────────────┐
│   Skills    │ ─── Multi-step procedures
└──────┬──────┘
       │ use
       ▼
┌─────────────┐     ┌─────────────┐
│ .claude/    │ ──► │ Shared      │
│ tools/      │     │ Scripts     │
│ (wrappers)  │     │ (actual)    │
└─────────────┘     └─────────────┘

┌─────────────┐
│   Agents    │ ─── Autonomous, isolated context
└──────┬──────┘
       │ invoke
       ▼
┌─────────────┐
│   Skills    │
└─────────────┘
```

### Key Differences

| Aspect | Slash Commands | Skills | Sub-agents |
|--------|---------------|--------|------------|
| Caller | User | AI | AI |
| Mode | Imperative | Declarative | Delegative |
| Context | Shared | Shared | **Isolated** |
| Discovery | User remembers | AI semantic match | AI delegates |
| Use Case | Repetitive tasks | Domain knowledge | Complex reasoning |

## Governance Hierarchy

```
constitution.md (Root)           ← Supreme law
    │
    ├── Sources/constitution.md  ← Swift-specific rules
    ├── Scripts/constitution.md  ← Shell-specific rules
    └── Tests/constitution.md    ← Testing rules

AGENTS.md                        ← Operations for ALL agents
    │
    └── .claude/CLAUDE.md        ← Claude-specific directives
            │
            ├── Scripts/.claude/CLAUDE.md  ← DevOps role
            └── Sources/.claude/CLAUDE.md  ← iOS Architect role
```

## Usage Examples

### Non-Claude Agent (Cursor/Copilot)

```bash
# Find a class definition
./Sources/tools/find-class.sh BidLoader

# Check imports in Core
./Sources/tools/check-imports.sh Sources/Core/MSPCore

# Get test template
./Scripts/tools/get-test-template.sh
```

### Claude

```
User: /test BidLoader
Claude: [Invokes unit-test-generator skill, uses get-test-template tool]

User: Review this PR
Claude: [Delegates to code-reviewer agent, which invokes constitutional-auditor skill]
```

## Adding New Capabilities

### New Shared Tool

1. Create script in `Scripts/tools/` or `Sources/tools/`
2. Make executable: `chmod +x path/to/tool.sh`
3. Document in `AGENTS.md` Section 3.1
4. (Optional) Create Claude wrapper in `.claude/tools/`

### New Claude Skill

1. Create `.claude/skills/<name>.skill.md`
2. Include YAML frontmatter with `name`, `description`, `allowed-tools`
3. Reference in `CLAUDE.md` if tied to a role

### New Template

1. Create in appropriate `*/templates/` directory
2. Use `{{placeholder}}` syntax
3. Document in `AGENTS.md` Section 3.2

## Related Documents

- [AGENTS.md](../AGENTS.md) - Operations manual for all agents
- [constitution.md](../constitution.md) - Project governance rules
- [.claude/CLAUDE.md](../.claude/CLAUDE.md) - Claude strategic directives
