# MSP iOS SDK Documentation

> **Last Updated**: 2026-01-14

## Navigation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System structure, module responsibilities, AI infrastructure |
| [RELEASE.md](RELEASE.md) | Release semantics and lifecycle |
| [TARGET_SWITCHING.md](TARGET_SWITCHING.md) | Mode switching (pods-dev, pods-release, spm-release) |
| [THIRD_PARTY_UPGRADES.md](THIRD_PARTY_UPGRADES.md) | Dependency management |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and solutions |

---

## AI Agent Infrastructure

| Document | Description |
|----------|-------------|
| [AI_AGENTS.md](AI_AGENTS.md) | Comprehensive multi-agent architecture (v2.0) |
| [AGENTS.md](../AGENTS.md) | Operations manual for all AI agents (v2.0) |
| [.agents-shared/](../.agents-shared/) | Shared capability layer (protocols, skills) |

### Agent-Specific Configuration

| Agent | Config | Description |
|-------|--------|-------------|
| Claude Code | [.claude/](../.claude/) | Strategic advisor (Tier 2-3) |
| Codex CLI | [.codex/](../.codex/) | Tactical executor (Tier 0-1) |
| Cursor IDE | [.cursor/](../.cursor/) | Interactive partner (Tier 1-2) |

### Key Concepts

- **Task Tier System**: 4-tier classification (Trivial → Strategic)
- **Model Selection**: Haiku → Sonnet → Opus based on complexity
- **Shared Skills**: Analysis and generation skills for all agents
- **Escalation Protocol**: When to escalate to higher-tier agents

---

## Governance

| Document | Description |
|----------|-------------|
| [constitution.md](../constitution.md) | Project governance rules (supreme law) |
| [Sources/constitution.md](../Sources/constitution.md) | Swift code rules |
| [Scripts/constitution.md](../Scripts/constitution.md) | Shell script rules |
| [Tests/constitution.md](../Tests/constitution.md) | Testing rules |

---

## Quick Links

- [README.md](../README.md) - Project entry point
- [Scripts/README.md](../Scripts/README.md) - Scripts reference
- [CHANGELOG.md](../CHANGELOG.md) - Release history
