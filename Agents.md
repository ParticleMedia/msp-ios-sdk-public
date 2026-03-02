# AI Agent Shared Context

> **Version**: 4.0
> **Last Updated**: 2026-02-22
> **Applies To**: All AI Agents

## Project Technical Context

**Language**: Swift 5.0 | **Target**: iOS 15.0+ | **UI**: UIKit
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1
**Build**: CocoaPods, XcodeGen

## Pre-Task Checklist

- [ ] Clean working directory (`git status`)
- [ ] On correct branch
- [ ] In development mode (`./Scripts/switch-target.sh pods-dev`)

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

## Context System

Knowledge base in `.context/` — discover entries via `.context/index.json`.

**Keyword → Domain**: release/pod → `release` | ci/build → `ci` | crash/compile → `integration` | migration → `compatibility` | test/mock → `testing`

After debugging (3+ rounds, root cause found): suggest `/context.add`.

## Read-Only Zones

constitution.md (all), ARCHITECTURE.md, README.md — require human approval.

## Reference Documents

- constitution.md — Supreme law
- .claude/CLAUDE.md | .codex/CODEX.md | .cursor/CURSOR.md — Agent directives

## Active Technologies
- Bash (POSIX-compatible), Ruby (YAML parsing), Python 3 (test case validation) + GitHub Actions, existing Scripts/ infrastructure (step_lifecycle.sh, build_module.sh, etc.) (ci-self-hosted-migration)
- N/A (filesystem-based, no database) (ci-self-hosted-migration)

## Recent Changes
- ci-self-hosted-migration: Added Bash (POSIX-compatible), Ruby (YAML parsing), Python 3 (test case validation) + GitHub Actions, existing Scripts/ infrastructure (step_lifecycle.sh, build_module.sh, etc.)
