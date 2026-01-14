# Codex Commands

> **Version**: 1.0
> **Last Updated**: 2026-01-14

This directory contains command templates and examples for Codex CLI.

---

## Overview

**Commands** are pre-defined task templates that provide consistent patterns for common operations.

---

## Command Format

Each command template follows this structure:

```markdown
---
name: command-name
description: Brief description
tier: 0 | 1 | 2
model: haiku | sonnet-3.5 | sonnet-4
---

## Usage

```bash
$ codex "[command pattern]"
```

## Expected Behavior
[What Codex should do]

## Example
[Concrete example with actual files]

## Verification
[How to verify success]
```

---

## Common Commands

### Tier 0: Trivial Operations

#### fix-typo
```bash
$ codex "fix typo in [file]"
```
Fix spelling mistakes in documentation or code.

#### update-version
```bash
$ codex "update version to [X.Y.Z]"
```
Update version number in relevant files (Podfile, Podspecs, etc.).

#### remove-unused-import
```bash
$ codex "remove unused import in [file]"
```
Remove unused import statements.

---

### Tier 1: Standard Operations

#### add-test
```bash
$ codex "add unit test for [ClassName]"
```
Generate Quick/Nimble unit test boilerplate for a class.

**Expected Behavior**:
1. Find class location
2. Get test template
3. Create test file in Tests/[Module]Tests/
4. Populate with class name

**Example**:
```bash
$ codex "add unit test for BidLoader"
```

---

#### rename
```bash
$ codex "rename [OldName] to [NewName] in [location]"
```
Batch rename across multiple files.

**Expected Behavior**:
1. Search for all occurrences
2. Replace in each file
3. Verify no remaining occurrences

**Example**:
```bash
$ codex "rename NovaAdapter to MSPNovaAdapter in Scripts/"
```

---

#### fix-shellcheck
```bash
$ codex "fix shellcheck warnings in [script]"
```
Fix shell script warnings reported by shellcheck.

**Expected Behavior**:
1. Run shellcheck
2. Fix each warning
3. Verify 0 warnings remain

**Example**:
```bash
$ codex "fix shellcheck warnings in msp-release.sh"
```

---

### Tier 2: Complex Operations (Execution Only)

These require prior analysis from Claude Code.

#### implement-plan
```bash
$ codex "implement plan [task_id]"
```
Execute a detailed implementation plan provided by Claude Code.

**Expected Behavior**:
1. Read handoff context
2. Execute each step
3. Verify at checkpoints
4. Return to Claude Code for review

---

## Creating New Command Templates

1. **Identify pattern**: Find a frequently repeated task
2. **Create template**: Document the command pattern
3. **Add verification**: Define success criteria
4. **Test**: Verify with multiple examples

---

## Command vs. Skill vs. Tool

| Type | Purpose | Invocation |
|------|---------|------------|
| **Command** | User-facing entry point | `$ codex "[command]"` |
| **Skill** | Multi-step procedure (internal) | Referenced by command |
| **Tool** | Atomic executable script | Called by skill |

**Example**:
```
add-test (command)
  → unit-test-generator.skill.md (skill)
    → get-test-template.sh (tool)
```

---

## Best Practices

### ✅ Good Command Patterns

```bash
# Specific and actionable
$ codex "fix typo 'recieve' → 'receive' in README.md"
$ codex "add unit test for BidLoader class"
$ codex "rename OldClass to NewClass in Sources/Core/"
```

### ❌ Vague Command Patterns

```bash
# Too vague
$ codex "fix the code"
$ codex "make it better"
$ codex "update everything"
```

---

## Future Commands

As patterns emerge, consider adding:
- `format-code` - Apply code formatting
- `update-docs` - Sync API documentation
- `check-compliance` - Run constitutional audit

---

## Governance

- **Maintenance**: Update as new patterns emerge
- **Quality**: Each command should have clear success criteria
- **Consistency**: Follow the command template format
