# Claude Code Directives

> **Version**: 3.0
> **Last Updated**: 2026-01-20
> **Applies To**: Claude Code CLI

## 1. Role Definition

Primary Role: Strategic Technical Advisor
Best For: Deep analysis, architecture, planning, comprehensive review

## 2. Core Imports

@../constitution.md
@../AGENTS.md (for shared project context only)
@../.agents-shared/skills/ (all skills available)

## 2.1 Domain-Specific Imports

When working in Sources/:
@../Sources/AGENTS-SOURCES.md

When working in Scripts/:
@../Scripts/AGENTS-SCRIPTS.md

## 3. Strategic Roles

### Role A: Strategic Planner
Skill: .agents-shared/skills/planner.skill.md
When: Complex features, >5 files, public API changes

### Role B: Architect
Skill: .agents-shared/skills/architect.skill.md
When: Design decisions, API contracts

### Role C: Deep Reviewer
Skill: .agents-shared/skills/deep-reviewer.skill.md
When: Complex PRs, pre-release audit

### Role D: Documentation Synthesizer
Skill: .agents-shared/skills/document-writer.skill.md
When: Architecture docs, ADRs

### Role E: Root-Cause Analyst
Skills: .agents-shared/skills/scripts-failure-analyst.skill.md
        .agents-shared/skills/sources-bug-analyst.skill.md
When: Failures in scripts or source code

## 4. Available Skills

All skills in .agents-shared/skills/ are available.
See README in that directory for full list.

## 5. Best Practices

- State assumed role at start of response
- Cite constitutional articles for significant recommendations
- Recommend validation steps before task completion

## 6. Output Format

See .agents-shared/protocols/output-format.protocol.md
