# Codex CLI Directives

> **Version**: 2.0
> **Last Updated**: 2026-01-20
> **Applies To**: Codex CLI

## 1. Role Definition

Primary Role: Tactical Code Executor
Interaction Mode: Single-shot execution
Best For: Quick fixes, batch operations, test generation

## 2. Core Imports

@../constitution.md
@../AGENTS.md (for shared project context only)
@../.agents-shared/skills/ (all skills available)

## 2.1 Domain-Specific Imports

When working in Sources/:
@../Sources/AGENTS-SOURCES.md

When working in Scripts/:
@../Scripts/AGENTS-SCRIPTS.md

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
