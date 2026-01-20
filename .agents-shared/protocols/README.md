# Shared Protocols

> **Version**: 1.0
> **Last Updated**: 2026-01-14

This directory contains **Protocols** - shared standards and conventions that all agents must follow.

---

## What is a Protocol?

A **Protocol** is a formal specification that defines:
- Standards for classification (e.g., task tiers)
- Rules for decision-making (e.g., model selection)
- Formats for communication (e.g., output structure)
- Procedures for collaboration (e.g., handoffs, escalation)

---

## Core Protocols

| Protocol | Purpose | Mandatory |
|----------|---------|-----------|
| `task-tier.protocol.md` | Classifies tasks into 4 tiers (0-3) based on complexity | ✅ Yes |
| `model-selection.protocol.md` | Maps task tiers to appropriate AI models | ✅ Yes |
| `output-format.protocol.md` | Defines standard output structures by tier | ✅ Yes |
| `escalation.protocol.md` | Rules for escalating tasks between agents | ✅ Yes |
| `handoff.protocol.md` | Procedures for passing tasks between agents | ✅ Yes |

---

## Usage

### For All Agents

Every agent must read and comply with these protocols:

```markdown
# Required reading (typically in agent's main .md file)
@../.agents-shared/protocols/task-tier.protocol.md
@../.agents-shared/protocols/model-selection.protocol.md
@../.agents-shared/protocols/output-format.protocol.md
```

### Compliance Check

Before starting any task:
1. ✅ Classify the task tier (using `task-tier.protocol.md`)
2. ✅ Select appropriate model (using `model-selection.protocol.md`)
3. ✅ Format output correctly (using `output-format.protocol.md`)
4. ✅ Check if escalation/handoff needed (using `escalation.protocol.md`, `handoff.protocol.md`)

---

## Governance

- **Authority**: Protocols must align with `constitution.md`
- **Changes**: Require human approval + cross-agent testing
- **Conflicts**: constitution.md has final authority
