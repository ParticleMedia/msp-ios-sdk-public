---
name: quick-fix
description: Apply simple, mechanical code fixes following established patterns
category: generation
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Read, Edit, Grep]
quick_reference: "When: Mechanical fixes (force unwrap → guard let, nil check, import fix, typo). Pattern-based, no architectural changes."
---

# Quick Fix Skill

> **Type**: Generation Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Apply simple, mechanical fixes that don't require design decisions

---

## Purpose

Execute common, pattern-based code fixes that are:
- Mechanical and repetitive
- Follow established conventions
- Don't require architectural decisions
- Can be applied consistently

**Task Tier**: Tier 0-1 (Trivial to Standard)

---

## Scope

**Does**:
- Add nil checks (guard let, if let)
- Fix force unwraps
- Add missing imports
- Fix typos and naming
- Remove unused code
- Add access control modifiers
- Fix simple syntax errors

**Does NOT**:
- Make design decisions (escalate to architect)
- Refactor complex logic (use refactor-pattern.skill.md)
- Fix bugs requiring root cause analysis (use sources-bug-analyst.skill.md)
- Change public APIs (requires human approval)

---

## When to Use

- Linter/compiler reports simple violations
- Code review identifies mechanical improvements
- Constitutional audit finds trivial violations
- Applying a fix pattern across multiple locations

**Quick Decision**:
- If fix is obvious and mechanical → Use this skill
- If fix requires understanding "why" → Use sources-bug-analyst.skill.md
- If fix affects architecture → Escalate to Claude Code

---

## Fix Patterns

### Pattern 1: Fix Force Unwrap

**Detection**:
```bash
grep -r "!" Sources/ | grep -v "!=" | grep -v "// !"
```

**Fix**:
```diff
- let value = optional!
+ guard let value = optional else {
+     log_error("Unexpected nil value")
+     return
+ }
```

**When to Apply**:
- Violates Article IV.3 (Sources/constitution.md)
- Potential crash risk
- Not in test code (force unwrap acceptable in tests)

---

### Pattern 2: Add Nil Check

**Detection**: Crash logs show `unexpectedlyFoundNil`

**Fix**:
```diff
  func process(_ data: Data?) {
+     guard let data = data else {
+         return
+     }
      // use data safely
  }
```

**When to Apply**:
- Optional parameter without nil handling
- Potential nil access detected
- Defensive programming needed

---

### Pattern 3: Add Missing Import

**Detection**: Compiler error `Use of unresolved identifier`

**Fix**:
```diff
+ import Foundation
+
  class MyClass {
      let date = Date()  // Requires Foundation
  }
```

**When to Apply**:
- Compiler reports missing type
- Type exists in standard framework
- Not a custom type (those need module specification)

---

### Pattern 4: Fix Typo

**Detection**: Code review, linter, or manual inspection

**Fix**:
```diff
- func processBidRespone(_ response: BidResponse) {
+ func processBidResponse(_ response: BidResponse) {
```

**When to Apply**:
- Spelling error in identifier
- Not a public API (breaking change)
- Consistent with project naming

**Important**: Search for all usages before renaming:
```bash
grep -r "processBidRespone" Sources/
```

---

### Pattern 5: Remove Unused Code

**Detection**: Compiler warning `Variable 'x' is never used`

**Fix**:
```diff
  func loadBid() {
-     let unusedVar = computeValue()
      performLoad()
  }
```

**When to Apply**:
- Compiler confirms unused
- Not commented-out code (may be intentional)
- Not in debug/diagnostic code

---

### Pattern 6: Add Access Control

**Detection**: Missing access modifier on type/method

**Fix**:
```diff
- class BidLoader {
+ internal class BidLoader {
```

**When to Apply**:
- Module boundary enforcement needed
- Following principle of least privilege
- Constitutional requirement for encapsulation

**Common Modifiers**:
- `private`: Only within type
- `fileprivate`: Only within file
- `internal`: Within module (default)
- `public`: Accessible outside module
- `open`: Subclassable outside module

---

### Pattern 7: Fix Trailing Whitespace

**Detection**: Linter reports trailing whitespace

**Fix**:
```diff
- let value = 10
+ let value = 10
```

**When to Apply**:
- Linter violation
- Pre-commit hook failure
- Code style enforcement

---

## Execution Steps

### Step 1: Identify Fix Pattern

Match the issue to one of the patterns above.

### Step 2: Verify Applicability

Check that:
- [ ] Fix is mechanical (no design decision)
- [ ] Pattern is appropriate for context
- [ ] No side effects or breaking changes
- [ ] Constitutional compliance maintained

### Step 3: Search for All Instances

If fixing multiple occurrences:
```bash
grep -r "<pattern>" Sources/
```

### Step 4: Apply Fix

Use Edit tool with exact string matching:
```
old_string: let value = optional!
new_string: guard let value = optional else { return }
```

### Step 5: Verify

- [ ] Code compiles
- [ ] Tests pass
- [ ] Linter satisfied

---

## Output Format

```markdown
## Quick Fix Applied

**Pattern**: [Pattern name from above]
**Location**: `Sources/.../File.swift:123`
**Issue**: [Brief description]

### Changes
```diff
- old code
+ new code
```

### Verification
- ✅ Compiles
- ✅ Tests pass
- ✅ Constitutional compliance: Article X.Y
```

---

## Example Usage

### For Claude Code

```markdown
@../.agents-shared/skills/quick-fix.skill.md

Fix force unwrap on line 42 of BidLoader.swift
```

### For Codex CLI

```bash
$ codex "fix force unwrap in BidLoader.swift line 42"
# Applies Pattern 1 automatically
```

### For Cursor

**Inline Mode (Cmd+K, select code)**:
```
Add guard let to safely unwrap bidResponse
```

---

## Batch Operations

When applying same fix to multiple locations:

**Step 1**: Find all instances
```bash
grep -rn "!" Sources/ | grep -v "!=" > /tmp/force_unwraps.txt
```

**Step 2**: Apply pattern to each
For each location, apply the appropriate fix pattern.

**Step 3**: Verify all
```bash
swift test
```

**Important**: Don't batch if locations have different contexts. Each fix must be appropriate for its specific use case.

---

## Anti-Patterns

### ❌ Don't: Apply Without Context

```
Bad: Blindly replacing all force unwraps
Good: Analyze each force unwrap's context first
```

### ❌ Don't: Change Public APIs

```
Bad: Rename public method to fix typo
Good: Deprecate old, add new correctly-spelled method
```

### ❌ Don't: Remove "Unused" Debug Code

```
Bad: Delete code marked "TODO: for debugging"
Good: Ask before deleting intentional debug code
```

---

## Constitutional Compliance

This skill enforces:
- **Article IV.3**: Avoiding force unwraps
- **Article IV.2**: Proper error handling
- **Federal Article II.1**: Code passes validation gates

---

## Tips for Effective Quick Fixes

1. **Verify First**: Ensure fix is actually needed
2. **Search Broadly**: Find all instances of the issue
3. **Test Immediately**: Run tests after each fix
4. **Stay Mechanical**: If judgment needed, escalate
5. **Batch Carefully**: Only batch truly identical fixes

---

## Related Skills

- `sources-bug-analyst.skill.md`: For fixes requiring root cause analysis
- `refactor-pattern.skill.md`: For structural refactorings
- `constitutional-auditor.skill.md`: To identify violations needing fixes
