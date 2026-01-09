# AI Agent Interaction Protocol

> **Version**: 1.1  
> **Last Updated**: 2026-01-09  
> **Applies To**: All AI Agents (Codex, Cursor, GitHub Copilot, etc.)

This document is the primary operational manual for all AI Agents contributing to this project. It defines the rules of engagement, standard operating procedures, and safety protocols. Adherence to this document is mandatory.

---

## 0. Pre-Task Checklist

Before starting any task, every agent must verify the following conditions:

- [ ] **Clean Working Directory**: Run `git status` to confirm no uncommitted changes
- [ ] **Correct Branch**: Confirm you are on the intended working branch
- [ ] **Development Mode**: Run `./Scripts/switch-target.sh pods-dev` to ensure the SDK is in development mode
- [ ] **Context Loaded**: (Claude only) Load the relevant `.claude/CLAUDE.md` for the target directory

---

## 1. Core Principles & Constitution

**Foundation**: All actions performed by an AI Agent must strictly adhere to the principles laid out in `constitution.md`.

**Prime Directive**: When in doubt, ask for clarification rather than making an assumption. It is better to interrupt than to be incorrect.

**Tool-First Approach**: Always prefer using the project's existing automation scripts over performing manual file operations for build, release, or validation tasks.

---

## 2. Authorized Toolbox

The following scripts are the primary, authorized tools for project automation. Agents should call these scripts directly.

| Script | Function | Common Usage |
|--------|----------|--------------|
| `./Scripts/switch-target.sh <mode>` | Switches the SDK's operational mode | Run with `pods-dev` before starting any coding task |
| `./Scripts/target-switching/round-trip-test.sh` | Performs a full round-trip validation across all modes | Run after significant changes to validate project integrity |
| `./Scripts/msp-release.sh --tier Preflight <ver>` | Executes a comprehensive pre-release validation | Run before finalizing a feature or fix to ensure it passes release checks |
| `pod install` | Installs CocoaPods dependencies | Run after modifying the `Podfile` |
| `XcodeGen` | Generates the Xcode project | Run after modifying any `*.yml.template` file |

---

## 3. Standard Operating Procedures (SOPs)

### SOP-1: Adding a New Ad Network Adapter (e.g., "MyNewAdAdapter")

1. **Modify Podfile**: Add the new dependency (e.g., `pod 'MyNewAdSDK', '~> 1.2.3'`).
2. **Install Dependencies**: Execute `pod install`.
3. **Consult Naming Conventions**: Refer to `ARCHITECTURE.md` ("Naming Conventions") to determine the correct directory and class name for the new adapter.
4. **Create Source Files**: Create the directory and source files under `Sources/Adapters/`.
5. **Implement Protocol**: Implement the `AdNetworkAdapter` protocol in your new class.
6. **Update Project**: Add the new module definition to `Sources/Adapters/project.yml.template`.
7. **Generate Project**: Execute `XcodeGen`.
8. **Add Test Case**: Add a new UI control or test case in `Examples/MSPDemoApp/` to load and display an ad from the new adapter.
9. **Validate**: Execute `./Scripts/target-switching/round-trip-test.sh` to ensure the change is compatible with all modes.

### SOP-2: Recovering from a Failed Agent Task

Use this procedure when an agent task has failed or left the workspace in an inconsistent state.

1. **Stash or Revert Changes**: 
   - To preserve changes: `git stash push -m "WIP: <description>"`
   - To discard changes: `git checkout .`
2. **Clean Untracked Files** (if needed): `git clean -fd` (use with caution)
3. **Switch to Development Mode**: `./Scripts/switch-target.sh pods-dev`
4. **Run Validation**: `./Scripts/target-switching/round-trip-test.sh`
5. **Assess Results**:
   - If test passes: The workspace is clean. Document what went wrong for future reference.
   - If test fails: Escalate to Claude or a human developer with full error logs.

---

## 4. Read-Only Zone

> **[For Non-Claude Agents Only]**  
> The following files are read-only for tactical agents. Only Claude or human developers may modify them when explicitly requested.

The following files define the project's core strategy and architecture. They are provided for context only:

- `constitution.md`
- `.claude/CLAUDE.md` (and any sub-directory versions)
- `ARCHITECTURE.md`
- `README.md`

---

## 5. Escalation Protocol to Claude / Human

**[Critical]** If any of the following conditions are met, the Agent must immediately halt its current task and report the condition to the user, recommending escalation to Claude or a human developer.

| Rule | Condition | Rationale |
|------|-----------|-----------|
| **E-1** (Public API Change) | Any modification is made to a `public` or `open` API, including function signatures, properties, or protocol definitions (`AdNetworkAdapter`) | Protects external API contracts |
| **E-2** (Constitutional File Change) | Any attempt is made to modify a file defined as a Single Source of Truth in the Constitution (e.g., `Podfile`, `*.yml.template`, `msp-release.sh`) **outside of an approved SOP** | Protects build determinism |
| **E-3** (Complexity Threshold) | A single task's code modifications (diff) exceed 150 lines, span more than 5 files, or affect any file in `Sources/Core/MSPCore/` or `Sources/Core/MSPiOSCore/` | Prevents scope creep in critical modules |
| **E-4** (Consecutive Failures) | An attempt to fix a specific build or test error fails twice in a row with the same error message | Prevents infinite retry loops |
| **E-5** (Dependency Graph Change) | A new third-party dependency is added to the `Podfile`, or an existing one has its major version number changed (e.g., `1.x` to `2.x`) | Guards against supply chain issues |

---

## Appendix: Quick Reference

```bash
# Switch to development mode
./Scripts/switch-target.sh pods-dev

# Validate all modes
./Scripts/target-switching/round-trip-test.sh

# Pre-release check
./Scripts/msp-release.sh --tier Preflight 1.0.0

# Full release
./Scripts/msp-release.sh --profile=production run 1.0.0
```
