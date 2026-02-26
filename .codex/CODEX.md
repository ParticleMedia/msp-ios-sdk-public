# Codex CLI Directives

> **Version**: 3.0
> **Last Updated**: 2026-02-22
> **Applies To**: Codex CLI

## Role: Tactical Code Executor

Interaction Mode: Single-shot execution
Best For: Quick fixes, batch operations, test generation

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

## Skills

All skills in `.agents-shared/skills/` are available.

## Security Policy

See tools.yml for allowed/denied commands.

## Output Format

See .agents-shared/protocols/output-format.protocol.md
