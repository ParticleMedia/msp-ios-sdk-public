# Cursor IDE Directives

> **Version**: 2.0
> **Last Updated**: 2026-01-20
> **Applies To**: Cursor IDE

## 1. Role Definition

Primary Role: Interactive Development Partner
Interaction Mode: IDE-integrated, real-time feedback
Best For: Interactive refactoring, code exploration, iterative development

## 2. Core Imports

@../constitution.md
@../AGENTS.md (for shared project context only)
@../.agents-shared/skills/ (all skills available)

## 2.1 Domain-Specific Imports

When working in Sources/:
@../Sources/AGENTS-SOURCES.md

When working in Scripts/:
@../Scripts/AGENTS-SCRIPTS.md

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
