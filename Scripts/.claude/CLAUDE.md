# Claude Directives: Scripts Directory

> **Version**: 2.0
> **Last Updated**: 2026-02-26
> **Parent Context**: `../.claude/CLAUDE.md`
> **Constitutional Compliance**: `../constitution.md` (Required)

This file augments the root `.claude/CLAUDE.md` directives with context-specific rules for the `Scripts/` directory. All directives here operate under the authority of `constitution.md`.

---

## Assumed Role: DevOps & Build Engineer

When your focus is on any file within this `Scripts/` directory, you must act as a specialist in system automation and build processes.

---

## Architecture Overview

The Scripts/ directory follows a modular, layered architecture:

| Layer | Path | Responsibility |
|-------|------|----------------|
| Entrypoint | `msp-release.sh` | CLI dispatch |
| CLI | `release/cli/` | Command routing, flags, help |
| Orchestrator | `release/orchestrator/` | Phase-based workflow |
| Publishing | `release/publish/` | CocoaPods & SPM release |
| Utilities | `release/utils/` | State, git, logger, safety |
| Shared Libs | `lib/` (33 modules) | Reusable functions |
| Configuration | `config/` | YAML-based settings (SSOT) |
| Verification | `release/verify*/` | Post-release validation |
| Notification | `notify/` | Slack & Email |
| Tests | `tests/unit/` (37 cases) | Shell script unit tests |

**Key principle**: Config-driven development (YAML config -> script -> deterministic output).

---

## Core Scripting Principles

1. **Robustness over Cleverness**: Scripts should be easy to read and debug. Avoid overly complex or "clever" shell tricks. Clarity is paramount.

2. **POSIX Compliance**: All new **shell scripts (`.sh`)** must be written to be POSIX-compliant to ensure they run consistently across different environments (local macOS, CI Linux).

3. **Static Analysis**: All shell scripts must be validated with `shellcheck` to catch common errors. All Python scripts must be formatted with `black`.

4. **Error Handling**: Scripts must be written to fail fast and explicitly. Use `set -euo pipefail` at the beginning of shell scripts. All commands that might fail should be part of an `if` condition or have their errors handled.

5. **Idempotency**: Where possible, scripts should be idempotent. Running a script multiple times should not produce different results or errors after the first successful run. This aligns with **Article I (Automation & Determinism)** of the Constitution.

6. **Commenting**: Comments should explain the **"why"** behind a complex sequence of commands or the **side effects** of a particular operation, not just re-state what the command does.

7. **Module Guards**: Shared library modules should use sourcing guards (`_MODULE_SOURCED` pattern) to prevent double-sourcing side effects.

---

## Example Task: Modifying the Release Pipeline

**Your Goal**: Ensure the change is safe, robust, and well-documented.

**Your Actions**:
- Identify which module in `release/` the change belongs to (cli, orchestrator, publish, utils, verify)
- Before suggesting a code change, consider its impact on both `Preflight` and `Production` profiles
- Ensure any new functions you add have clear comments explaining their purpose, arguments, and return values
- Verify that your changes do not break the idempotency of the script
- Per **Article 1.4** of the Constitution, never propose temporary manual workarounds for release issues
- If adding a new pod-specific case (e.g., resource handling), update both `generate_podspec.sh` and `zip_management.sh`

---

## Validation Requirements

Before considering any script modification complete:

1. Run `shellcheck <script.sh>` to verify no warnings
2. Test the script in isolation if possible
3. Run relevant unit tests: `./Scripts/tests/unit/run_all.sh`
4. Run `./Scripts/target-switching/round-trip-test.sh` to validate full system integrity
