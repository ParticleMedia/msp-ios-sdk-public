---
name: agent-sync
description: Synchronize shared resources (context entries, skills) across all agents (Claude, Cursor, Codex) to prevent stale configurations
category: knowledge-management
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Bash, Read, Grep]
---

# Agent Sync Skill

> **Type**: Knowledge Management Skill
> **Shared**: Yes (All agents MUST use)
> **Purpose**: Keep Claude, Cursor, and Codex configurations in sync after shared resource changes

---

## Purpose

Three agents share `.context/` entries and `.agents-shared/skills/`. When any agent creates
or modifies these shared resources, all agents' derived files must be updated. This skill
defines the exact sync procedure to prevent configuration drift.

**Task Tier**: Tier 0-1 (Mechanical, automated)

---

## Scope

**Does**:
- Regenerate `.context/index.json` from context entry frontmatter
- Update auto-generated sections in `.cursor/rules/context-system.mdc` (context inventory)
- Update auto-generated sections in `.cursor/rules/skills-sync.mdc` (skills list)
- Mirror skill files between `.agents-shared/skills/` and `.claude/skills/`
- Validate sync results

**Does NOT**:
- Create new context entries (use `context-add` skill)
- Create new skills (use skill-creator)
- Modify hand-written rule content (only regenerates marker-delimited sections)

---

## When to Use

### MANDATORY Triggers (MUST sync after these actions)

1. **After adding a context entry** — via `add-context.sh`, `init-context.sh`, or manual creation
2. **After editing a context entry** — title, tags, triggers, status, domain, layer changed
3. **After adding a skill** — new `.skill.md` file in `.agents-shared/skills/` or `.claude/skills/`
4. **After modifying a skill** — description, category, or content changed
5. **After deleting/archiving a context entry or skill**

### Detection (how to know sync is needed)

- You just created a `.context/` file → sync needed
- You just edited frontmatter of a `.context/` file → sync needed
- You just created or edited a `.skill.md` file → sync needed
- User says "add context" / "save this experience" → sync after context-add completes
- User says "create a skill" → sync after skill creation completes

### Trigger Phrases

- "sync agents" / "同步 agent 规则"
- "update agent rules" / "更新 agent 配置"
- Implicit: after ANY use of `context-add`, `context-init`, or skill creation

---

## Procedure

### Step 1: Regenerate Context Index (SSOT)

```bash
python3 Scripts/tools/generate-context-index.py
```

This reads all `.context/{domain}/{layer}/ctx-*.md` files, extracts YAML frontmatter,
and rebuilds `.context/index.json` — the single source of truth for context entries.

**Expected output**: "Index generated: .context/index.json" with entry count

**If fails**: Check that context entry files have valid YAML frontmatter (id, title, domain, layer, tags, triggers, summary, status)

### Step 2: Sync Agent Rule Files

```bash
python3 Scripts/tools/sync-agent-rules.py
```

This reads `.context/index.json` and `.agents-shared/skills/` to regenerate
auto-generated sections (between `<!-- BEGIN:GENERATED:* -->` / `<!-- END:GENERATED:* -->` markers)
across all three agents.

**Files updated**:
- `.cursor/rules/context-system.mdc` → context inventory table
- `.cursor/rules/skills-sync.mdc` → skills list table
- `.codex/instructions.md` → context inventory + skills list
- `.claude/rules/context-system.md` → context inventory table
- `.claude/rules/skills-sync.md` → skills list table

**Expected output**: "Sync complete: N file(s) updated"

### Step 3: Mirror Skills (if skill changed)

If a skill was added or modified:

```bash
# If change was in .agents-shared/skills/:
cp .agents-shared/skills/{name}.skill.md .claude/skills/{name}.skill.md

# If change was in .claude/skills/:
cp .claude/skills/{name}.skill.md .agents-shared/skills/{name}.skill.md
```

Both directories must have identical `.skill.md` files at all times.

### Step 4: Validate

```bash
./Scripts/tools/validate-agent-sync.sh
```

Runs 6 automated checks: line counts, index references, playbook ID coverage,
JSON validity, staleness detection (dry-run sync), and skills mirror consistency.

**Expected**: "ALL CHECKS PASSED"

---

## One-Liner (Quick Sync)

For the common case of full sync after any change:

```bash
python3 Scripts/tools/generate-context-index.py && python3 Scripts/tools/sync-agent-rules.py
```

---

## Integration with Other Skills

### After `context-add` Skill

The `add-context.sh` script automatically calls both sync steps. However, if you manually
create a context file (e.g., writing the `.md` file directly), you MUST run the sync manually.

### After Skill Creation

When creating a new skill:
1. Create in `.agents-shared/skills/{name}.skill.md`
2. Copy to `.claude/skills/{name}.skill.md`
3. Run `python3 Scripts/tools/sync-agent-rules.py`

### After `context-init` Skill

The `init-context.sh` script automatically calls sync after batch-creating context entries.

---

## What Gets Synced (Data Flow)

```
.context/ctx-*.md (SSOT: entries)       .agents-shared/skills/*.skill.md (SSOT: skills)
       │                                           │
       ▼                                           │
generate-context-index.py                          │
       │                                           │
       ▼                                           │
.context/index.json                                │
       │                                           │
       └──────────────┬────────────────────────────┘
                      ▼
            sync-agent-rules.py
                      │
       ┌──────────────┼──────────────┐
       ▼              ▼              ▼
  Cursor rules   Codex rules    .claude/skills/
  - context-     - instructions  (mirror)
    system.mdc     .md
  - skills-
    sync.mdc
                      │
                      ▼
           validate-agent-sync.sh
           (9 automated checks)
```

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| "No valid frontmatter" | Context .md missing `---` block | Add YAML frontmatter to the file |
| "Missing fields [...]" | Required frontmatter fields absent | Add: id, title, domain, layer, tags, triggers, summary, status |
| "Markers not found" | Rule file missing `<!-- BEGIN:GENERATED:* -->` | Re-create the rule file from template |
| Skills count mismatch | `.agents-shared/skills/` ≠ `.claude/skills/` | Manual mirror: copy missing files |

---

## Verification Checklist

Run `./Scripts/tools/validate-agent-sync.sh` — it automates all of these:
- [ ] Agent entry point files under line limits
- [ ] All agents reference `.context/index.json`
- [ ] Playbook IDs in loading guides exist in `index.json`
- [ ] `index.json` is valid JSON
- [ ] Canonical `AGENTS.md` naming is enforced
- [ ] Auto-generated sections match current source data (staleness check)
- [ ] `.claude/skills/` and `.agents-shared/skills/` have identical file sets
- [ ] Generated sections are identical across Claude / Cursor / Codex

---

## Related Skills

- `context-add` — Creates context entries (triggers this skill automatically)
- `context-init` — Batch-creates from git history (triggers this skill automatically)
- `context-list` — Browse and search context (read-only, no sync needed)

---

## Constitutional Compliance

- **Federal I.1** (Automation First) — Sync is automated, not manual
- **Federal III.1** (Module Cohesion) — Each agent's config is independently functional but derived from shared SSOT
