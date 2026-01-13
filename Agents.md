# AI Agent Interaction Protocol
> **Version**: 1.0
> **Last Updated**: 2026-01-12
> **Applies To**: All AI Agents (Codex, Cursor, GitHub Copilot, etc.)

This document is the primary operational manual for all AI Agents contributing to this project. It defines rules, SOPs, and safety protocols. Adherence is mandatory.

---
## 0. Pre-Task Checklist
Before starting any task, verify:
- [ ] Clean Working Directory (`git status`).
- [ ] On the correct branch.
- [ ] In development mode (`./Scripts/switch-target.sh pods-dev`).

---
## 1. Core Principles
**Foundation**: All actions must adhere to the principles in all applicable `constitution.md` files.
**Prime Directive**: When in doubt, ask for clarification.
**Tool-First Approach**: Always prefer using existing automation scripts.

---
## 2. Git & Pull Request (PR) Workflow
**Core Tenet**: A disciplined Git workflow is essential.
**2.1 Branching**: Use `feature/`, `fix/`, or `chore/` prefixes.
**2.2 Commits**: Must follow Conventional Commits v1.0.0.
**2.3 PRs**: Title must be clear (e.g., `[MSP-123] feat: ...`). Must be rebased on `main` and pass all checks before review.

---
## 3. Authorized Toolbox
| Script | Function |
|---|---|
| `./Scripts/switch-target.sh <mode>` | Switches the SDK's operational mode. |
| `./Scripts/target-switching/round-trip-test.sh` | Performs a full round-trip validation. |
| `./Scripts/msp-release.sh --tier Preflight <ver>` | Executes a pre-release validation. |
| `pod install` | Installs CocoaPods dependencies. |
| `XcodeGen` | Generates the Xcode project. |

---
## 3.1 Shared Tools
Executable scripts available to all agents:

### Scripts/tools/ (Automation & CI)
| Tool | Usage | Purpose |
|------|-------|---------|
| `get-test-template.sh` | `./Scripts/tools/get-test-template.sh` | Print unit test template |
| `validate-script.sh` | `./Scripts/tools/validate-script.sh <path>` | Run shellcheck on script |

### Sources/tools/ (Swift Development)
| Tool | Usage | Purpose |
|------|-------|---------|
| `find-class.sh` | `./Sources/tools/find-class.sh <TypeName>` | Find type definition |
| `list-public-api.sh` | `./Sources/tools/list-public-api.sh <ModulePath>` | List public API surface |
| `check-imports.sh` | `./Sources/tools/check-imports.sh [ModulePath]` | Check for forbidden imports |

---
## 3.2 Shared Templates
Templates are available for consistent output across agents:

| Template | Location | Purpose |
|----------|----------|---------|
| Unit Test | `Tests/templates/unit_test_spec.swift.template` | Quick/Nimble test boilerplate |
| Release Notes | `Scripts/templates/release-notes-template.md` | Changelog entry format |

**Placeholders**: Use `{{placeholder_name}}` syntax. Common placeholders:
- `{{module_name}}` - Swift module name
- `{{class_name}}` - Class under test

---
## 4. Standard Operating Procedures (SOPs)
### SOP-4.1: General Workflow
1. Create a new branch.
2. Make code changes.
3. Write or update tests according to the constitution.
4. Write a Conventional Commit message.

### SOP-4.2: Domain-Specific Workflow: `Sources/`
*   **Context**: When working on Swift/Objective-C files inside `Sources/`.
*   **Procedure**: Follow SOP-4.1, and additionally ensure all new public APIs are documented with Swift DocC.

### SOP-4.3: Writing Unit Tests
*   **Context**: When asked to write unit tests.
*   **Procedure**:
    1.  Adhere to all TDD principles in `Sources/constitution.md` and readability principles in `Tests/constitution.md`.
    2.  Use **Quick & Nimble**.
    3.  Use the template at `Tests/templates/unit_test_spec.swift.template` for boilerplate.
    4.  Place files correctly: Specs in `Tests/<Module>Tests/Specs/`, Mocks in `Tests/<Module>Tests/Mocks/`.
    5.  Follow the BDD style (`describe-context-it`).

---
## 5. Read-Only Zone (for non-Claude Agents only)
The following files are read-only for tactical agents:
- `constitution.md` (all versions)
- `.claude/` (the entire directory)
- `ARCHITECTURE.md`
- `README.md`

---
## 6. Escalation Protocol to Claude / Human
[Critical] If any of the following conditions are met, the Agent **must halt** and recommend escalation.

| Rule | Condition |
|---|---|
| E-1 | Any modification is made to a `public` or `open` API. |
| E-2 | Any attempt is made to modify a `constitution.md` file or an SSOT file (e.g., `Podfile`) outside of an approved SOP. |
| E-3 | A single task's diff exceeds 150 lines, spans >5 files, or affects `Sources/Core/`. |
| E-4 | An attempt to fix an error fails twice in a row with the same error. |
| E-5 | A new dependency is added, or an existing one has its major version changed. |
