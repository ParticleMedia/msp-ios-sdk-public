# Shared Skills

> **Version**: 2.0
> **Last Updated**: 2026-01-20

This directory contains **Skills** - reusable multi-step procedures that any agent can invoke.

---

## What is a Skill?

A **Skill** is a documented procedure for completing a specific type of task. It includes:
- **Objective**: What the skill accomplishes
- **When to Use**: Scenarios where this skill applies
- **Procedure**: Step-by-step instructions
- **Output Format**: Expected result structure

---

## Current Skills

### Strategic Skills
| Skill | Description | Applicable Agents | Recommended Model |
|-------|-------------|-------------------|-------------------|
| `planner.skill.md` | Complex task planning and multi-phase breakdown | All | Opus |
| `architect.skill.md` | Architectural design and API contracts | All | Opus |
| `deep-reviewer.skill.md` | Comprehensive code review | All | Opus |
| `document-writer.skill.md` | Technical documentation synthesis | All | Opus |

### Analysis Skills
| Skill | Description | Applicable Agents |
|-------|-------------|-------------------|
| `constitutional-auditor.skill.md` | Check code/changes against constitution.md | All |
| `scripts-failure-analyst.skill.md` | Diagnose script failures (CI/CD, release) | All |
| `sources-bug-analyst.skill.md` | Analyze code bugs and crashes | All |

### Generation Skills
| Skill | Description | Applicable Agents |
|-------|-------------|-------------------|
| `unit-test-generator.skill.md` | Generate Quick/Nimble unit test boilerplate | All |
| `quick-fix.skill.md` | Apply simple, well-defined fixes | All |
| `refactor-pattern.skill.md` | Execute pattern-based refactoring | All |

---

## How to Use a Skill

### Claude Code
```markdown
# Reference in CLAUDE.md or other skills
@../.agents-shared/skills/unit-test-generator.skill.md
```

### Codex
Codex auto-loads condensed skill references from `.codex/instructions.md` on startup. For detailed procedures, read the full skill file:
```bash
# Skills are automatically available via instructions.md
# For full details, reference the skill file:
cat .agents-shared/skills/unit-test-generator.skill.md
```

### Cursor
```
# In Chat/Composer
@file:.agents-shared/skills/unit-test-generator.skill.md
Please follow this skill to generate a test for BidLoader
```

---

## Adding a New Skill

1. **Determine if skill should be shared**
   - Shared: Procedural, repeatable, useful across agents
   - Agent-specific: Requires unique capabilities (e.g., Opus-only deep reasoning)

2. **Create skill file**
   ```markdown
   ---
   name: skill-name
   description: Brief description
   allowed-tools: [tool1, tool2]
   ---

   ## Objective
   ...

   ## Procedure
   ...
   ```

3. **Update this README**
   - Add to the appropriate table above

4. **Test**
   - Verify multiple agents can use it successfully
