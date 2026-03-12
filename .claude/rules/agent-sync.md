# Cross-Agent Sync Protocol

## The Problem

Three agents (Claude, Cursor, Codex) share resources. Changes made by one agent
can leave the others stale. This rule enforces automatic sync.

## Shared Resources (Single Source of Truth)

| Resource | SSOT Location | Derived Files |
|----------|---------------|---------------|
| Context entries | `.context/{domain}/{layer}/ctx-*.md` | `.context/index.json`, `.cursor/rules/context-system.mdc` |
| Context index | `.context/index.json` (generated) | `.cursor/rules/context-system.mdc` inventory section |
| Skills | `.agents-shared/skills/*.skill.md` | `.claude/skills/` (mirror), `.cursor/rules/skills-sync.mdc` |
| Agent rules | Each agent owns its own | Sync conceptual parity, not file copies |

## Sync Triggers & Actions

### After Adding Context Entry

When a new `.context/` entry is created (via `add-context.sh` or manually):

```bash
python Scripts/tools/generate-context-index.py
python Scripts/tools/sync-agent-rules.py
```

Both steps are REQUIRED. The sync script updates auto-generated sections in Cursor rules.

### After Modifying Context Entry

When an existing `.context/` entry is edited:

```bash
python Scripts/tools/generate-context-index.py
python Scripts/tools/sync-agent-rules.py
```

### After Adding/Modifying Skills

When skills change in `.agents-shared/skills/`:

1. Mirror to `.claude/skills/` (bidirectional — see skills-sync.md)
2. Run `python Scripts/tools/sync-agent-rules.py` to update Cursor skills list

### After Modifying Agent Rules

When `.claude/rules/*.md` or `.cursor/rules/*.mdc` is modified:
- Evaluate if the conceptual change applies to other agents
- If yes, apply equivalent change to the other agents' rules

## Quick Sync Command

```bash
python Scripts/tools/generate-context-index.py && python Scripts/tools/sync-agent-rules.py
```
