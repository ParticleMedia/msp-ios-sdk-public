# Codex CLI Directives

> **Version**: 5.1
> **Last Updated**: 2026-03-12
> **Applies To**: Codex CLI

## Role: Tactical Code Executor

Interaction Mode: Single-shot execution
Best For: Quick fixes, batch operations, test generation

## Core Imports

@../constitution.md
@../AGENTS.md

## Progressive Disclosure

Codex uses `instructions.md` as its single always-active entry point.
All rules, context inventory, and skills are loaded there.

### What's in instructions.md
- **Inlined Hard Rules** — 24 Swift/UIKit HR + Script HR (NEVER-DO list)
- **Context Inventory** — auto-generated from `.context/index.json` (full entry list with triggers)
- **Skills Registry** — auto-generated from `.agents-shared/skills/` (full skill list)
- **Condensed Skill Guides** — quick-reference for common skills
- **Shared Tools** — 5 shell scripts for code analysis/validation
- **Cross-Agent Sync** — protocol for keeping Claude/Cursor/Codex in sync

### Auto-generated sections
Sections between `<!-- BEGIN:GENERATED:* -->` / `<!-- END:GENERATED:* -->` markers
are maintained by `Scripts/tools/sync-agent-rules.py`. Do not edit them manually.

## Directory-Triggered Context

When working in Sources/:
→ load Sources/AGENTS-SOURCES.md (playbook loading guide)

When working in Scripts/:
→ load Scripts/AGENTS-SCRIPTS.md (playbook loading guide)

## On-Demand Context

Use `.context/index.json` to discover playbooks by keyword matching against `tags` and `triggers` fields. Load only what the current task requires.

## Skills

All skills in `.agents-shared/skills/` are available.
Registry with descriptions is in `instructions.md` (auto-generated).

## Security Policy

See tools.yml for allowed/denied commands.

## Cross-Agent Sync

After modifying `.context/` entries or `.agents-shared/skills/`:
```bash
python3 Scripts/tools/generate-context-index.py
python3 Scripts/tools/sync-agent-rules.py
```

## Output Format

See .agents-shared/protocols/output-format.protocol.md
