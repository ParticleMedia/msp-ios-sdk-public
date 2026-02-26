# Scripts Loading Guide

> **Version**: 3.0 | **Scope**: Scripts/ directory
> **Last Updated**: 2026-02-26
> **Applies To**: All AI Agents working in Scripts/

When working in Scripts/, load relevant playbooks from `.context/index.json`:

| Playbook ID | Topic | When |
|-------------|-------|------|
| ctx-sources-004 | Script Best Practices | Always when writing scripts |

**Philosophy**: Config-driven development (YAML config -> script -> deterministic output)

**State Constitution**: `Scripts/constitution.md` (Articles VI-VII)

**Required header**: `set -euo pipefail` (Article VI.1)

## Key Paths

| Path | Purpose |
|------|---------|
| `Scripts/config/release.yaml` | Release configuration (SSOT) |
| `Scripts/release/` | Modular release system (cli, orchestrator, publish, utils, verify) |
| `Scripts/lib/` | 33 shared library modules |
| `Scripts/tests/unit/` | 37 unit test files |
| `Scripts/tools/` | Developer & AI agent tools |

## Validation

```bash
shellcheck <script.sh>                        # Static analysis
./Scripts/tests/unit/run_all.sh               # Unit tests
./Scripts/target-switching/round-trip-test.sh  # Integration
```
