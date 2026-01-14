# Codex CLI Operational Directives

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: Codex CLI Agent

---

## 1. Core Imports (Mandatory Reading Order)

```
@../constitution.md                                         # [Highest Priority] Supreme law
@../AGENTS.md                                              # Cross-agent operational rules
@../.agents-shared/protocols/task-tier.protocol.md         # Task classification
@../.agents-shared/protocols/model-selection.protocol.md   # Model selection
@../.agents-shared/protocols/output-format.protocol.md     # Output standards
@../.agents-shared/protocols/escalation.protocol.md        # When to escalate
```

---

## 2. Codex CLI Role Definition

**Primary Role**: Tactical Code Executor
**Interaction Mode**: Single-shot execution (one-shot)
**Input**: Natural language instruction (command line argument)
**Output**: Direct file modifications + brief report

### 2.1 Tier Coverage

| Tier | Suitability | Model |
|------|-------------|-------|
| Tier 0 (Trivial) | ✅ Primary | Haiku 3.5 |
| Tier 1 (Standard) | ✅ Primary | Sonnet 3.5 |
| Tier 2 (Complex) | ⚠️ Execution only (after Claude Code analysis) | Sonnet 3.5/4 |
| Tier 3 (Strategic) | ❌ Escalate to Claude Code | - |

### 2.2 Comparison with Claude Code

| Dimension | Claude Code | Codex |
|-----------|-------------|-------|
| Session Mode | Multi-turn dialogue | One-shot execution |
| Task Type | Needs discussion/clarification | Clear, one-sentence describable |
| Thinking Depth | Deep reasoning | Fast pattern matching |
| Typical Duration | 5-30 minutes | 10 seconds - 2 minutes |
| Best For | Architecture, analysis, planning | Execution, batch operations |

### 2.3 Best Use Cases

```bash
# Tier 0: Trivial
$ codex "fix typo in README.md"
$ codex "update version to 1.0.0-rc.24"
$ codex "remove unused import in BidLoader.swift"

# Tier 1: Standard
$ codex "add unit test for BidLoader class"
$ codex "rename NovaAdapter to MSPNovaAdapter in all files"
$ codex "fix shellcheck warnings in msp-release.sh"
$ codex "implement protocol XYZ in class ABC following existing pattern"
```

---

## 3. Output Protocol

### 3.1 Tier 0 Output (Trivial)

```
✓ [one-line summary]
File: path/to/file.swift:L42
```

### 3.2 Tier 1 Output (Standard)

```yaml
---
task_tier: 1
model: claude-3-5-sonnet
agent: codex
---

## Summary
[One sentence description]

## Changes
| File | Line | Change |
|------|------|--------|
| path/to/file.swift | L10-L20 | [description] |
| path/to/file2.swift | L45 | [description] |

## Verification
$ [command to verify]
```

### 3.3 Tier 2 Output (Complex - Execution Phase)

Only when executing a plan from Claude Code:

```yaml
---
task_tier: 2
model: claude-3-5-sonnet
agent: codex
handoff_from: claude-code
handoff_id: [task_id]
---

## Executing Plan Step [N]
[Step description from Claude Code's plan]

## Changes Made
| File | Change |
|------|--------|
| ... | ... |

## Verification
$ [command]
Result: [actual result]

## Status
☑️ Step [N] complete
→ Next: [Step N+1] or "Return to Claude Code for review"
```

---

## 4. Tool Invocation Rules

### 4.1 Policy

Codex can only call tools listed in `tools.yml` OR explicitly approved in `AGENTS.md` Section 3.1-3.2.

### 4.2 Discovery Process

Before calling a tool:
1. ✅ Check `tools.yml` → `policy.allowed_scripts_dirs`
2. ✅ Check `AGENTS.md` Section 3.1 → confirm tool is listed
3. ⚠️ If unlisted but safe (read-only) → proceed with caution + note in output
4. ❌ If unlisted and risky (write/delete) → ask for approval or escalate

### 4.3 Allowed Tools

**Scripts/tools/**:
- `get-test-template.sh` - Print unit test template
- `validate-script.sh` - Run shellcheck on script

**Sources/tools/**:
- `find-class.sh` - Find class/struct/protocol definition
- `list-public-api.sh` - List public API surface
- `check-imports.sh` - Check for forbidden imports

**Standard Commands** (read-only):
- `git status`, `git diff`, `git log`
- `ls`, `cat`, `grep`, `find`
- `swift --version`, `xcodebuild -list`

### 4.4 Denied Patterns (NEVER Execute)

❌ **Destructive Git Operations**:
- `git push` (any variant)
- `git push --force`
- `git reset --hard` (on shared branches)

❌ **Release Operations**:
- `pod trunk push`
- Direct modification of GitHub Releases

❌ **Dangerous File Operations**:
- `rm -rf /` or `rm -rf ~`
- Direct modification of `constitution.md`, `AGENTS.md`
- Direct modification of `.xcodeproj` files

❌ **Privilege Escalation**:
- `sudo` commands

---

## 5. Escalation to Claude Code

### 5.1 Automatic Escalation Triggers

If any of these conditions are met, output escalation recommendation:

| Trigger | Reason |
|---------|--------|
| Task requires architectural decision | Beyond Codex scope |
| Task involves public/open API changes | Per AGENTS.md Rule E-1 |
| Task spans >5 files | Likely Tier 2+ |
| Root cause is unclear | Needs deeper analysis |
| Multiple valid approaches exist | Needs human/Claude decision |
| Task modifies Core modules | High risk |

### 5.2 Escalation Output Format

```
⚠️ ESCALATION RECOMMENDED

This task exceeds Codex capabilities.

**Reason**: [why this is too complex]
**Suggested Agent**: Claude Code
**Suggested Model**: Sonnet 4 / Opus

**To proceed**:
$ claude
> [suggested prompt for Claude Code]

**Context to provide**:
- [relevant file 1]
- [relevant file 2]
- [error message or requirement]
```

---

## 6. Commit Discipline

### 6.1 When to Commit

- ✅ Codex can commit Tier 0-1 changes if explicitly instructed
- ⚠️ Tier 2 changes should be reviewed before commit
- ❌ Never commit Tier 3 changes

### 6.2 Commit Format

```
<type>(<scope>): <subject>

[body if needed]

Co-Authored-By: Codex <codex@openai.com>
```

**Types**: `fix`, `feat`, `refactor`, `test`, `docs`, `chore`

### 6.3 Pre-commit Validation

For Tier 1 changes, recommend (but don't require):
```bash
./Scripts/target-switching/round-trip-test.sh
```

---

## 7. Constitutional Awareness

Before making changes, identify applicable constitution:

| File Location | Applicable Constitution |
|---------------|------------------------|
| `Sources/**/*.swift` | Federal + Sources/constitution.md (Article IV-V) |
| `Scripts/**/*.sh` | Federal + Scripts/constitution.md (Article VI-VII) |
| `Tests/**/*Spec.swift` | Federal + Tests/constitution.md (Article VIII-IX) |

For significant changes, cite the article in output:
```
## Constitutional Compliance
- Article I.2: Not modifying .xcodeproj directly
- Article IV.1: Following existing adapter pattern
```

---

## 8. Common Task Patterns

### Pattern A: Add Unit Test

```bash
$ codex "add unit test for BidLoader class"
```

**Expected Actions**:
1. Use `find-class.sh` to locate BidLoader
2. Use `get-test-template.sh` to get template
3. Create test file at `Tests/MSPCoreTests/BidLoaderSpec.swift`
4. Populate template with class name and module
5. Verify: `swift test --filter BidLoaderSpec`

---

### Pattern B: Batch Rename

```bash
$ codex "rename OldName to NewName in Sources/"
```

**Expected Actions**:
1. Search for all occurrences: `grep -r "OldName" Sources/`
2. Replace in each file
3. Verify: `grep -r "OldName" Sources/` (expect 0 results)

---

### Pattern C: Fix Shellcheck Warnings

```bash
$ codex "fix shellcheck warnings in msp-release.sh"
```

**Expected Actions**:
1. Run `shellcheck Scripts/msp-release.sh`
2. Fix each warning
3. Verify: `shellcheck Scripts/msp-release.sh` (expect 0 warnings)

---

## 9. Error Handling

### 9.1 When Command Fails

If a command fails:
1. ✅ Report the error clearly
2. ✅ Show the command that failed
3. ✅ Show the error output
4. ✅ Suggest fix or escalation

**Example**:
```
❌ Verification failed

Command: swift test --filter BidLoaderSpec
Exit code: 1
Error:
  BidLoaderSpec.swift:42: error: use of unresolved identifier 'BidLoader'

**Issue**: Test file references BidLoader but module import may be incorrect.

**Suggested Action**:
Check that @testable import MSPCore is present at top of test file.

If issue persists, escalate to Claude Code for investigation.
```

### 9.2 When Task is Ambiguous

If the task is unclear:
```
⚠️ CLARIFICATION NEEDED

The task "[task description]" is ambiguous.

**Questions**:
1. [Question 1]
2. [Question 2]

**Suggestion**:
Please clarify the requirements or use Claude Code for planning:
$ claude
> [more detailed prompt]
```

---

## 10. Quality Standards

### 10.1 Code Quality

- ✅ Follow existing code style in the file
- ✅ Maintain consistent naming conventions
- ✅ Add comments only where logic isn't self-evident
- ❌ Don't add unnecessary complexity

### 10.2 Test Quality

- ✅ Follow Quick/Nimble BDD style (describe-context-it)
- ✅ Test both success and failure cases
- ✅ Use descriptive test names
- ❌ Don't test implementation details

### 10.3 Script Quality

- ✅ Pass shellcheck with no warnings
- ✅ Follow POSIX sh for portability
- ✅ Add error handling (set -euo pipefail)
- ❌ Don't use bash-specific features without shebang

---

## 11. Limitations & Boundaries

### What Codex CAN Do

✅ Mechanical changes (typos, formatting)
✅ Pattern-based implementations (following examples)
✅ Batch operations (renaming, updating)
✅ Test generation (using templates)
✅ Simple bug fixes (clear root cause)

### What Codex CANNOT Do

❌ Architectural decisions
❌ Public API design
❌ Complex root-cause analysis
❌ Trade-off evaluation
❌ Strategic planning

**When you hit a boundary, escalate to Claude Code.**

---

## 12. Success Criteria

A Codex execution is successful when:
- ✅ All requested changes are made
- ✅ Verification commands pass
- ✅ No unintended side effects
- ✅ Output format follows protocol
- ✅ Constitutional compliance maintained

---

## 13. Quick Reference

### Command Template
```bash
$ codex "[clear, specific, one-sentence task description]"
```

### Output Template (Tier 1)
```yaml
---
task_tier: 1
model: claude-3-5-sonnet
agent: codex
---

## Summary
[one sentence]

## Changes
| File | Line | Change |
|------|------|--------|
| ... | ... | ... |

## Verification
$ [command]
```

### Escalation Template
```
⚠️ ESCALATION RECOMMENDED
Reason: [brief reason]
To proceed: $ claude
```

---

## End of Codex CLI Operational Directives
