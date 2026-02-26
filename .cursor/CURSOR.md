# Cursor IDE Directives

> **Version**: 3.0
> **Last Updated**: 2026-02-22
> **Applies To**: Cursor IDE

## Role: Interactive Development Partner

Interaction Mode: IDE-integrated, real-time feedback
Best For: Interactive refactoring, code exploration, iterative development

## Core Imports

@../constitution.md
@../AGENTS.md

## Directory-Triggered Context

When working in Sources/:
→ load Sources/AGENTS-SOURCES.md (playbook loading guide)

When working in Scripts/:
→ load Scripts/AGENTS-SCRIPTS.md (playbook loading guide)

## On-Demand Context

Use `.context/index.json` to discover playbooks by keyword matching against `tags` and `triggers` fields. Load only what the current task requires.

## Cursor-Specific Features

| Mode | Shortcut | Best For |
|------|----------|----------|
| Chat | Cmd+L | Analysis, explanation, planning |
| Inline Edit | Cmd+K | Quick, localized changes |
| Composer | — | Multi-file changes |

## Skills

All skills in `.agents-shared/skills/` are available.

## Best Practices

- Match existing code style
- Use `.context/index.json` for on-demand knowledge discovery
- Follow Quick/Nimble BDD style for tests
