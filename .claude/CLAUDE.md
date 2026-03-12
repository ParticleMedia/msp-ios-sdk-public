# Claude Code Directives

> **Version**: 5.1
> **Last Updated**: 2026-03-12
> **Applies To**: Claude Code CLI

## Role: Strategic Technical Advisor

Best For: Deep analysis, architecture, planning, comprehensive review

## Core Imports

@../constitution.md
@../AGENTS.md

## Context & Knowledge

All context loading rules (directory-triggered playbooks, keyword matching, tools) are in `.claude/rules/context-system.md`.
Use `.context/index.json` to discover playbooks on demand. Load only what the current task requires.

## Skills

See `.claude/skills/` — progressive loading built-in (metadata at startup, full content on demand).

## Strategic Roles

| Role | Skill | When |
|------|-------|------|
| Planner | planner | Complex features, >5 files |
| Architect | architect | Design decisions, API contracts |
| Deep Reviewer | deep-reviewer | Complex PRs, pre-release audit |
| Doc Synthesizer | document-writer | Architecture docs, ADRs |
| Root-Cause Analyst | scripts-failure-analyst, sources-bug-analyst | Failures |
| Knowledge Sync | agent-sync | After adding context entries or skills |

## Best Practices

- Cite constitutional articles for significant recommendations
- Recommend validation steps before task completion
- Use `.context/index.json` for on-demand knowledge discovery

## Output Format

See .agents-shared/protocols/output-format.protocol.md
