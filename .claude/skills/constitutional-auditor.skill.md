---
name: constitutional-auditor
description: Check code compliance against constitution.md files
category: analysis
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Read, Glob]
quick_reference: "When: Checking code compliance. Steps: Identify applicable constitution → Check violations → Report with article citations."
---

# Constitutional Auditor Skill

> **Type**: Analysis Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Focused compliance checking against project constitutions

---

## Scope

**Does**:
- Check constitutional compliance
- Cite violations with article references
- Suggest fixes based on constitutional requirements

**Does NOT**:
- Assess overall architecture or design patterns
- Evaluate code quality beyond constitutional requirements
- Provide strategic recommendations (use architect.skill.md instead)

---

## When to Use

- Before committing changes
- During code review
- When unsure if change complies with constitution
- As part of automated validation

---

## Execution Steps

### Step 1: Load Applicable Constitutions

Based on file location, load relevant constitutions:

| File Location | Constitutions to Load |
|---------------|----------------------|
| Any | `constitution.md` (root/federal) |
| `Sources/**/*.swift` | + `Sources/constitution.md` |
| `Scripts/**/*.sh` | + `Scripts/constitution.md` |
| `Tests/**/*Spec.swift` | + `Tests/constitution.md` |

### Step 2: Identify Applicable Articles

Map file type to relevant articles:

**Swift Files**:
- Federal: Article I (Automation), Article II (Validation), Article III (Modularity)
- Sources: Article IV (Code Quality), Article V (Testing)

**Shell Scripts**:
- Federal: Article I (Automation), Article II (Validation)
- Scripts: Article VI (Scripting), Article VII (Build)

**Test Files**:
- Federal: Article I, Article II
- Tests: Article VIII (Test Quality), Article IX (Coverage)

### Step 3: Audit Code

For each applicable article:
1. Read the article requirements
2. Check if code complies
3. If violation found, note:
   - Article reference
   - Line number
   - Violation description
   - Suggested fix

### Step 4: Report Violations

Output findings in structured format (see below).

---

## Output Format

```markdown
## Constitutional Audit Results

**Files Audited**: N
**Violations Found**: M

---

### ✅ Compliant Articles
- Article I.1 (Automation First): ✅
- Article II.1 (Validation Loop): ✅

---

### ❌ Violations

#### 1. [Article I.2] Direct .xcodeproj Modification
- **Severity**: Critical
- **Location**: `MSPCore.xcodeproj/project.pbxproj`
- **Issue**: Direct modification of Xcode project file detected
- **Fix**: Modify `project.yml.template` and run XcodeGen instead
- **Constitutional Reference**: Article I.2 (Deterministic Builds)

#### 2. [Sources/Article IV.3] Force Unwrap Detected
- **Severity**: High
- **Location**: `Sources/Core/MSPCore/BidLoader.swift:42`
- **Code**: `let bid = response!`
- **Issue**: Force unwrap can cause runtime crashes
- **Fix**: Use `guard let bid = response else { return }` or `if let bid = response`
- **Constitutional Reference**: Sources/constitution.md Article IV.3

---

### Summary
- 🔴 Critical: 1
- 🟡 High: 1
- 🟢 Low: 0
```

---

## Example Usage

### For Claude Code
```markdown
@../.agents-shared/skills/constitutional-auditor.skill.md

Audit the following changes for constitutional compliance:
@file:Sources/Core/BidLoader.swift
```

### For Codex
Before committing, run constitutional check mentally:
1. Does this modify .xcodeproj? (Article I.2)
2. Does this use force unwrap? (Article IV.3)
3. Does this add tests? (Article V.1)

### For Cursor
In Chat mode:
```
@file:.agents-shared/skills/constitutional-auditor.skill.md
Check if my recent changes comply with the constitution
```

---

## Quick Checklist (Common Violations)

### Federal Constitution

- [ ] **Article I.2**: Not modifying .xcodeproj directly
- [ ] **Article I.3**: Not changing Podfile versions (SSOT)
- [ ] **Article I.4**: Providing script-based fix, not manual workaround
- [ ] **Article II.1**: Changes will pass validation gates
- [ ] **Article III.1**: Not importing third-party SDKs in Core modules

### Sources Constitution

- [ ] **Article IV**: Following Swift best practices
  - No force unwrap without justification
  - Using guard for early returns
  - Proper error handling

- [ ] **Article V**: Tests exist for new code
  - Unit tests for public methods
  - Edge cases covered

### Scripts Constitution

- [ ] **Article VI**: Script quality
  - Passes shellcheck
  - Follows POSIX sh
  - Has error handling (set -euo pipefail)

---

## Tips for Effective Auditing

1. **Start with Federal**: Always check federal constitution first
2. **Know Your Domain**: Learn the constitution for your primary work area
3. **Automate**: Consider adding to pre-commit hooks
4. **Cite Precisely**: Always include article number in violation reports

---

## Related Skills

- `architect.skill.md` (Claude only): For architectural decisions
- `deep-reviewer.skill.md` (Claude only): For comprehensive code review
