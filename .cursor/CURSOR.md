# Cursor IDE Directives

> **Version**: 5.1
> **Last Updated**: 2026-03-12
> **Applies To**: Cursor IDE

## Role: Interactive Development Partner

Interaction Mode: IDE-integrated, real-time feedback
Best For: Interactive refactoring, code exploration, iterative development

## Core Imports

@../constitution.md
@../AGENTS.md

## Progressive Disclosure (Rules System)

Cursor rules live in `.cursor/rules/` and auto-load based on context:

### Layer 0 — Always Active
| Rule File | Purpose |
|-----------|---------|
| `context-system.mdc` | Keyword→domain mapping, playbook discovery protocol |
| `skills-sync.mdc` | Keep skill files in sync across agents |

### Layer 1 — Directory-Triggered (auto-loaded by file glob)
| Rule File | Triggers On | Content |
|-----------|-------------|---------|
| `sources-swift.mdc` | `Sources/**/*.swift` | Swift/UIKit Hard Rules (inlined) + playbook loading |
| `scripts-directory.mdc` | `Scripts/**/*.sh,py,rb` | Shell/Python scripting standards |
| `tests-swift.mdc` | `Tests/**/*.swift` | Quick/Nimble BDD testing rules |

### Layer 2 — On-Demand Playbooks (read from `.context/`)
Discovered via `.context/index.json`. Loaded only when task requires deep knowledge.

## Directory-Triggered Context

When working in Sources/:
→ Rule `sources-swift.mdc` auto-loads
→ Must read playbooks listed in `Sources/AGENTS-SOURCES.md`

When working in Scripts/:
→ Rule `scripts-directory.mdc` auto-loads
→ Must read playbooks listed in `Scripts/AGENTS-SCRIPTS.md`

When working in Tests/:
→ Rule `tests-swift.mdc` auto-loads

## On-Demand Context

Use `.context/index.json` to discover playbooks by keyword matching against `tags` and `triggers` fields. Load only what the current task requires.

## Skills

All skills in `.agents-shared/skills/` are available.
Skills use progressive loading: metadata at startup, full content on demand.

## Best Practices

- Match existing code style
- Use `.context/index.json` for on-demand knowledge discovery
- Follow Quick/Nimble BDD style for tests
- Cite constitutional articles for significant recommendations
- Validate before marking task complete
