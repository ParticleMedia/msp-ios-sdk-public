# AI Agent Architecture

> **Version**: 2.0
> **Last Updated**: 2026-01-14

This document describes the comprehensive AI agent infrastructure for the MSP iOS SDK project, enabling consistent collaboration between human developers and multiple AI assistants.

---

## Overview

The project supports a multi-agent architecture with three primary AI assistants:

| Agent | Type | Primary Use Case | Task Tiers |
|-------|------|------------------|------------|
| **Claude Code** | CLI | Strategic analysis, architecture, planning | Tier 2-3 |
| **Codex CLI** | CLI | Quick execution, one-shot tactical tasks | Tier 0-1 |
| **Cursor IDE** | IDE | Interactive development, real-time feedback | Tier 1-2 |

The architecture separates concerns into:
- **Governance Layer**: Constitution and operational rules
- **Shared Capability Layer**: Tools, skills, protocols for all agents
- **Agent-Specific Layer**: Specialized configurations per agent

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Human Developer                                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Claude Code    │    │   Codex CLI      │    │   Cursor IDE     │
│   (Opus/Sonnet)  │    │   (Haiku/Sonnet) │    │   (Sonnet)       │
│   Tier 2-3       │    │   Tier 0-1       │    │   Tier 1-2       │
│                  │    │                  │    │                  │
│   Strategic      │    │   Tactical       │    │   Interactive    │
│   Advisor        │    │   Executor       │    │   Partner        │
└────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
         │  .claude/             │  .codex/              │  .cursor/
         │  ├─ CLAUDE.md         │  ├─ CODEX.md          │  ├─ CURSOR.md
         │  ├─ skills/           │  └─ tools.yml         │  └─ settings/
         │  │  (strategic)       │                       │
         │  ├─ agents/           │                       │
         │  └─ commands/         │                       │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                                 ▼
         ┌───────────────────────────────────────────────────────┐
         │              .agents-shared/ (Shared Layer)           │
         │  ┌─────────────────────┐  ┌─────────────────────────┐ │
         │  │     protocols/      │  │        skills/          │ │
         │  │  ├─ task-tier       │  │  ├─ constitutional-     │ │
         │  │  ├─ model-selection │  │  │   auditor           │ │
         │  │  ├─ escalation      │  │  ├─ scripts-failure-   │ │
         │  │  ├─ handoff         │  │  │   analyst           │ │
         │  │  └─ output-format   │  │  ├─ sources-bug-       │ │
         │  └─────────────────────┘  │  │   analyst           │ │
         │                           │  ├─ unit-test-         │ │
         │                           │  │   generator         │ │
         │                           │  ├─ quick-fix          │ │
         │                           │  └─ refactor-pattern   │ │
         │                           └─────────────────────────┘ │
         └───────────────────────────────────────────────────────┘
                                 │
                                 ▼
         ┌───────────────────────────────────────────────────────┐
         │              Shared Resources (Executable)            │
         │  ┌─────────────────────┐  ┌─────────────────────────┐ │
         │  │   Scripts/tools/    │  │     Sources/tools/      │ │
         │  │   Scripts/templates/│  │     Tests/templates/    │ │
         │  └─────────────────────┘  └─────────────────────────┘ │
         └───────────────────────────────────────────────────────┘
                                 │
                                 ▼
         ┌───────────────────────────────────────────────────────┐
         │                  Governance Layer                      │
         │  constitution.md    AGENTS.md    ARCHITECTURE.md       │
         │       │                                                │
         │       ├── Sources/constitution.md                      │
         │       ├── Scripts/constitution.md                      │
         │       └── Tests/constitution.md                        │
         └───────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
msp-ios-sdk/
├── AGENTS.md                       # Operations manual for ALL agents (v2.0)
├── constitution.md                 # Supreme law (root)
│
├── .agents-shared/                 # Shared capability layer
│   ├── README.md                   # Overview
│   ├── protocols/                  # Shared standards
│   │   ├── task-tier.protocol.md
│   │   ├── model-selection.protocol.md
│   │   ├── escalation.protocol.md
│   │   ├── handoff.protocol.md
│   │   └── output-format.protocol.md
│   └── skills/                     # Shared skills
│       ├── constitutional-auditor.skill.md
│       ├── scripts-failure-analyst.skill.md
│       ├── sources-bug-analyst.skill.md
│       ├── unit-test-generator.skill.md
│       ├── quick-fix.skill.md
│       └── refactor-pattern.skill.md
│
├── .claude/                        # Claude Code configuration
│   ├── CLAUDE.md                   # Strategic directives (v2.0)
│   ├── skills/                     # Claude-exclusive skills
│   │   ├── planner.skill.md
│   │   ├── architect.skill.md
│   │   ├── deep-reviewer.skill.md
│   │   └── document-writer.skill.md
│   ├── agents/                     # Sub-agents
│   │   └── code-reviewer.agent.md
│   └── commands/                   # Slash commands
│
├── .codex/                         # Codex CLI configuration
│   ├── CODEX.md                    # Operational rules
│   └── tools.yml                   # Security policy
│
├── .cursor/                        # Cursor IDE configuration
│   ├── CURSOR.md                   # IDE guidance
│   ├── settings/
│   │   └── rules.json
│   └── commands/
│       └── README.md
│
├── Scripts/
│   ├── tools/                      # Shared automation tools
│   │   ├── get-test-template.sh
│   │   └── validate-script.sh
│   ├── templates/
│   │   └── release-notes-template.md
│   └── constitution.md
│
├── Sources/
│   ├── tools/                      # Shared Swift development tools
│   │   ├── find-class.sh
│   │   ├── list-public-api.sh
│   │   └── check-imports.sh
│   └── constitution.md
│
└── Tests/
    ├── templates/
    │   └── unit_test_spec.swift.template
    └── constitution.md
```

---

## Task Tier System

Tasks are classified into 4 tiers based on complexity:

### Tier Classification Matrix

| Tier | Name | Description | Model | Cost |
|------|------|-------------|-------|------|
| **0** | Trivial | Mechanical, no logic decisions | Haiku | ~$0.15 |
| **1** | Standard | Pattern-based, known solutions | Sonnet 3.5 | ~$2 |
| **2** | Complex | Requires analysis and judgment | Sonnet 4 | ~$8 |
| **3** | Strategic | Architectural, high-stakes decisions | Opus 4.5 | ~$15+ |

### Classification Dimensions

1. **Impact Scope**: Local (1 file) → Module → Cross-module → System-wide
2. **Risk Level**: Easily reversible → Requires planning → Irreversible
3. **API Surface**: Internal → Package-private → Public → Breaking change
4. **Cognitive Requirement**: Mechanical → Pattern → Analysis → Synthesis
5. **Domain Knowledge**: None → Single domain → Multi-domain → Architectural
6. **Decision Authority**: Pre-approved → Guideline-bound → Judgment → Strategic

---

## Agent Roles

### Claude Code (Strategic Advisor)

**Primary Use**: Deep analysis, architecture, comprehensive review

**Task Tiers**: 2-3

**Exclusive Skills**:
- `planner.skill.md` - Multi-phase task planning
- `architect.skill.md` - Architectural design
- `deep-reviewer.skill.md` - 6-dimensional code review
- `document-writer.skill.md` - Technical documentation synthesis

**Best For**:
- Planning complex multi-step implementations
- Making architectural decisions
- Comprehensive PR reviews (>500 lines)
- Writing system documentation
- Root cause analysis when Codex is blocked

**Example Usage**:
```bash
$ claude
> Plan the implementation of OAuth authentication
> Design the caching API for ad responses
> Review PR #123 (500+ lines, touches Core)
> Write architecture documentation for adapter system
```

---

### Codex CLI (Tactical Executor)

**Primary Use**: Quick, one-shot execution

**Task Tiers**: 0-1

**Configuration**:
- `CODEX.md` - Operational rules
- `tools.yml` - Security policy

**Best For**:
- Fixing typos and simple bugs
- Adding unit tests from templates
- Running constitutional audits
- Applying quick fixes
- Batch operations

**Example Usage**:
```bash
$ codex "fix typo in README.md"
$ codex "add unit test for BidLoader class"
$ codex "audit BidLoader.swift for constitution compliance"
$ codex "fix force unwrap on line 42"
```

---

### Cursor IDE (Interactive Partner)

**Primary Use**: Real-time, interactive development

**Task Tiers**: 1-2

**Modes**:
- **Chat (Cmd+L)**: Analysis, explanation, questions
- **Composer (Cmd+I)**: Multi-file editing
- **Inline (Cmd+K)**: Quick local edits

**Best For**:
- Interactive refactoring
- Real-time feedback while coding
- Exploring code with context
- Implementing features with guidance

**Example Usage**:
```
[Chat] @file:BidLoader.swift Explain how bid loading works
[Composer] Implement caching layer following discussed approach
[Inline] Add guard let to safely unwrap bidResponse
```

---

## Skill Organization

### Shared Skills (`.agents-shared/skills/`)

All agents can use these procedural, repeatable skills:

**Analysis Skills**:
| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `constitutional-auditor` | Check compliance | Before commit, during review |
| `scripts-failure-analyst` | Diagnose CI/CD failures | When scripts fail |
| `sources-bug-analyst` | Diagnose Swift crashes | When app crashes |

**Generation Skills**:
| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `unit-test-generator` | Generate tests | After implementing feature |
| `quick-fix` | Mechanical fixes | Linter violations, typos |
| `refactor-pattern` | Apply refactoring | Code smell detected |

### Claude-Exclusive Skills (`.claude/skills/`)

Only Claude Code can use these strategic skills (require Opus):

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `planner` | Task planning | Complex features, >5 files |
| `architect` | API design | New modules, public API |
| `deep-reviewer` | Comprehensive review | Complex PRs, pre-release |
| `document-writer` | Documentation | Architecture docs, ADRs |

---

## Protocols

### Task Tier Protocol (`.agents-shared/protocols/task-tier.protocol.md`)

Defines how to classify tasks:

```yaml
task:
  description: "Add unit test for BidLoader"
  dimensions:
    impact_scope: "single_file"
    risk_level: "low"
    api_surface: "none"
    cognitive: "pattern"
    domain: "single"
    authority: "guideline"
  tier: 1
  agent: codex
  model: sonnet-3-5
```

### Escalation Protocol (`.agents-shared/protocols/escalation.protocol.md`)

Defines when to escalate:

**Automatic Triggers**:
- Public API modification
- Constitution/SSOT changes
- >150 lines diff, >5 files
- Error repeats twice
- New/major dependency change
- Root cause unclear
- Task requires Opus

### Handoff Protocol (`.agents-shared/protocols/handoff.protocol.md`)

Defines agent-to-agent transfers:

**Downward**: Claude Code → Codex/Cursor (planning → execution)
**Upward**: Codex/Cursor → Claude Code (blocked → analysis)
**Lateral**: Codex ↔ Cursor (mode switch)

---

## Model Selection

### Model Capabilities

| Model | Best For | Cost (1M tokens) |
|-------|----------|------------------|
| **Opus 4.5** | Deep reasoning, synthesis | $15 input / $75 output |
| **Sonnet 4** | Complex analysis, review | $3 input / $15 output |
| **Sonnet 3.5** | Standard code generation | $3 input / $15 output |
| **Haiku 3.5** | Simple, fast tasks | $0.25 input / $1.25 output |

### Tier → Model Mapping

| Tier | Primary Model | Fallback |
|------|---------------|----------|
| 0 (Trivial) | Haiku 3.5 | Sonnet 3.5 |
| 1 (Standard) | Sonnet 3.5 | Sonnet 4 |
| 2 (Complex) | Sonnet 4 | Opus 4.5 |
| 3 (Strategic) | **Opus 4.5** | N/A (require Opus) |

---

## Governance Hierarchy

```
constitution.md (Root)              ← Supreme law for ALL
    │
    ├── Sources/constitution.md     ← Swift code rules
    ├── Scripts/constitution.md     ← Shell script rules
    └── Tests/constitution.md       ← Testing rules

AGENTS.md                           ← Operations for ALL agents
    │
    ├── .claude/CLAUDE.md           ← Claude strategic directives
    │       │
    │       ├── Scripts/.claude/CLAUDE.md  ← DevOps role
    │       └── Sources/.claude/CLAUDE.md  ← iOS Architect role
    │
    ├── .codex/CODEX.md             ← Codex operational rules
    │
    └── .cursor/CURSOR.md           ← Cursor IDE guidance
```

---

## Usage Examples

### Claude Code - Strategic Planning

```bash
$ claude
> Plan the implementation of a caching layer for ad responses

[Uses planner.skill.md]
[Analyzes scope, assesses risks]
[Produces multi-phase implementation plan]
[Assigns subtasks to Codex/Cursor by tier]
```

### Codex CLI - Quick Execution

```bash
# Tier 0: Fix typo
$ codex "fix typo 'Respone' to 'Response' in BidLoader.swift"

# Tier 1: Add test
$ codex "generate unit test for BidLoader class"

# Tier 1: Constitutional audit
$ codex "audit Sources/Core/MSPCore/BidLoader.swift"
```

### Cursor IDE - Interactive Development

```
# Chat Mode (Cmd+L)
@file:Sources/Core/MSPCore/BidLoader.swift
Explain how the bid loading process works

# Composer Mode (Cmd+I)
Add caching layer to BidLoader
Requirements:
- LRU cache with max 100 entries
- Thread-safe using NSCache
@file:Sources/Core/MSPCore/BidLoader.swift

# Inline Mode (Cmd+K)
[Select code] Add guard let to safely unwrap bidResponse
```

### Multi-Agent Collaboration

```
1. Human: "Implement OAuth authentication"

2. Claude Code [Tier 3]:
   - Uses planner.skill.md
   - Produces 4-phase plan
   - Identifies 12 subtasks by tier

3. Claude Code → Codex [Handoff]:
   - Tier 0-1 subtasks delegated
   - "Add AuthManager class" (Tier 1)
   - "Generate unit tests" (Tier 1)

4. Codex executes subtasks

5. Codex → Claude Code [Escalation]:
   - "OAuth flow unclear, need design decision"

6. Claude Code [Tier 3]:
   - Uses architect.skill.md
   - Designs OAuth flow
   - Updates plan

7. Continue until complete
```

---

## Adding New Capabilities

### New Shared Skill

1. Create `.agents-shared/skills/<name>.skill.md`
2. Include YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: Brief description
   category: analysis | generation
   shared: true
   applicable_agents: [claude-code, codex, cursor]
   allowed-tools: [Read, Edit, Grep]
   ---
   ```
3. Document in `AGENTS.md` Section 3.2

### New Claude-Exclusive Skill

1. Create `.claude/skills/<name>.skill.md`
2. Include frontmatter with `shared: false`, `required_model: opus`
3. Document in `.claude/CLAUDE.md` Section 5

### New Protocol

1. Create `.agents-shared/protocols/<name>.protocol.md`
2. Define purpose, rules, examples
3. Reference in `AGENTS.md` Section 3.1

---

## Related Documents

- [AGENTS.md](../AGENTS.md) - Operations manual for all agents
- [constitution.md](../constitution.md) - Project governance rules
- [.claude/CLAUDE.md](../.claude/CLAUDE.md) - Claude strategic directives
- [.codex/CODEX.md](../.codex/CODEX.md) - Codex operational rules
- [.cursor/CURSOR.md](../.cursor/CURSOR.md) - Cursor IDE guidance
