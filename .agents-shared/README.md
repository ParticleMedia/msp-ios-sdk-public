# Shared Agent Capabilities

> **Version**: 1.0
> **Last Updated**: 2026-01-14

This directory contains capabilities shared across all AI agents (Claude Code, Codex, Cursor).

## Directory Structure

```
.agents-shared/
├── skills/      # Reusable multi-step procedures
├── protocols/   # Shared standards and rules
└── templates/   # Template index (points to actual templates)
```

## Purpose

The `.agents-shared/` directory serves as the **Shared Capability Layer** in our multi-agent infrastructure. It contains:

- **Skills**: Reusable capabilities that any agent can invoke
- **Protocols**: Standards that all agents must follow
- **Templates**: Shared templates for consistent output

## Usage

### For Claude Code
```markdown
@../.agents-shared/skills/unit-test-generator.skill.md
@../.agents-shared/protocols/task-tier.protocol.md
```

### For Codex
Read and follow procedures in relevant skill files. Check protocols for standards.

### For Cursor
Reference via `@file` in Chat/Composer:
```
@.agents-shared/skills/unit-test-generator.skill.md
```

## Directory Structure

```
.agents-shared/
├── README.md              (this file)
├── skills/                # Shared procedural knowledge
│   └── README.md
├── protocols/             # Shared standards and rules
│   ├── task-tier.protocol.md
│   └── output-format.protocol.md
└── templates/             # Template index
    └── README.md
```

## Governance

- **Owner**: All agents (shared ownership)
- **Modification**: Requires human approval
- **Authority**: Must comply with `constitution.md`
