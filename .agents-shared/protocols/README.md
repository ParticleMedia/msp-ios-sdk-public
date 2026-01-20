# Shared Protocols

> **Version**: 2.0
> **Last Updated**: 2026-01-20

This directory contains **Protocols** - shared standards and conventions that all agents must follow.

---

## What is a Protocol?

A **Protocol** is a formal specification that defines:
- Standards for classification (e.g., task tiers)
- Formats for communication (e.g., output structure)

---

## Core Protocols

| Protocol | Purpose | Mandatory |
|----------|---------|-----------|
| `task-tier.protocol.md` | Classifies tasks into 4 tiers (0-3) based on complexity | ✅ Yes |
| `output-format.protocol.md` | Defines standard output structures by tier | ✅ Yes |

---

## Usage

### For All Agents

Every agent must read and comply with these protocols:

```markdown
# Required reading (typically in agent's main .md file)
@../.agents-shared/protocols/task-tier.protocol.md
@../.agents-shared/protocols/output-format.protocol.md
```

### Compliance Check

Before starting any task:
1. ✅ Classify the task tier (using `task-tier.protocol.md`)
2. ✅ Format output correctly (using `output-format.protocol.md`)

---

## Governance

- **Authority**: Protocols must align with `constitution.md`
- **Changes**: Require human approval + cross-agent testing
- **Conflicts**: constitution.md has final authority
