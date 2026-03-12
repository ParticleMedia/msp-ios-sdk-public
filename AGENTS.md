# AI Agent Shared Context

> **Version**: 5.1
> **Last Updated**: 2026-03-12
> **Applies To**: All AI Agents

## Project Technical Context

**Language**: Swift 5.0 | **Target**: iOS 15.0+ | **UI**: UIKit
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1
**Build**: CocoaPods, XcodeGen

## Pre-Task Checklist

- [ ] Clean working directory (`git status`)
- [ ] On correct branch
- [ ] In development mode (`make open` or `./Scripts/switch-target.sh pods-dev`)

## Domain-Specific Context

Deep content lives in playbooks — discover via `.context/index.json`.
- Sources/ development → `Sources/AGENTS-SOURCES.md` (loading guide)
- Scripts/ development → `Scripts/AGENTS-SCRIPTS.md` (loading guide)

## Workflow

### Branching & Commits
- Prefixes: feature/, fix/, chore/
- Format: `<type>(<scope>): <subject>` (Conventional Commits v1.0.0)

### Project Configuration (Article I.2)
1. Edit `*.yml.template` (never `.xcodeproj` directly)
2. Run `xcodegen generate`
3. Commit template only

## Shared Resources

| Location | Content |
|----------|---------|
| `.agents-shared/skills/` | All agent skills |
| `.agents-shared/protocols/` | Output format, task tiers |
| `Scripts/tools/` | Automation scripts |
| `packages/test-cases/` | YAML test case definitions |
| `packages/mock-data/` | JSON fixture data |
| `Makefile` | Developer workflow shortcuts (setup, open, test, release, etc.) |

## Context System

Knowledge base in `.context/` — discover entries via `.context/index.json`.

**Keyword → Domain**: release/pod → `release` | ci/build → `ci` | crash/compile → `integration` | migration → `compatibility` | test/mock → `testing`

After debugging (3+ rounds, root cause found): suggest `/context.add`.

## Cross-Agent Sync Protocol

All agents (Claude, Cursor, Codex) share `.context/` and `.agents-shared/skills/`.
When any agent modifies these shared resources, it MUST run the sync chain:

```bash
python Scripts/tools/generate-context-index.py   # SSOT: .context/index.json
python Scripts/tools/sync-agent-rules.py          # Propagate to agent rule files
```

This is auto-triggered by `add-context.sh` and `init-context.sh`. For manual edits, run both commands.
See `.claude/rules/agent-sync.md` or `.cursor/rules/agent-sync.mdc` for full protocol.

## Read-Only Zones

constitution.md (all), ARCHITECTURE.md, README.md — require human approval.

## Reference Documents

- constitution.md — Supreme law
- .claude/CLAUDE.md | .codex/CODEX.md | .cursor/CURSOR.md — Agent directives

## Active Technologies
- Bash (POSIX-compatible), Ruby (YAML parsing), Python 3 (test case validation) + GitHub Actions, existing Scripts/ infrastructure (step_lifecycle.sh, build_module.sh, etc.) (ci-self-hosted-migration)
- N/A (filesystem-based, no database) (ci-self-hosted-migration)

## Recent Changes
- duplicate-deps-cleanup: Removed lottie-ios dependency from NovaCore (replaced with UIView animation), moved OMSDK from MSPNovaAdapter to MSPSharedLibraries, fixed MSPSnapKit unexported symbols
- makefile: Added Makefile with developer workflow targets (setup, open, test, validate, rtt, ci, beta, release, resume, clean)
- ci-self-hosted-migration: Added Bash (POSIX-compatible), Ruby (YAML parsing), Python 3 (test case validation) + GitHub Actions, existing Scripts/ infrastructure (step_lifecycle.sh, build_module.sh, etc.)
