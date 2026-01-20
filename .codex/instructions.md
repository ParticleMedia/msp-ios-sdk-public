# Codex Quick Start Instructions

> **Auto-loaded**: This file provides quick reference to shared capabilities
> **Full Context**: See `.codex/CODEX.md` for complete operational directives

---

## Shared Skills Available to Codex

Codex has access to all skills in `.agents-shared/skills/`. Below are condensed quick-reference guides.

---

## Skill 1: Unit Test Generator

**When**: Creating unit tests for a Swift class
**Template**: `Tests/templates/unit_test_spec.swift.template`

### Quick Steps:
1. Find module: `grep -r "class ClassName" Sources/`
2. Get template: `cat Tests/templates/unit_test_spec.swift.template`
3. Replace placeholders:
   - `{{module_name}}` → actual module (e.g., MSPCore)
   - `{{class_name}}` → actual class (e.g., BidLoader)
4. Save to: `Tests/{Module}Tests/{ClassName}Spec.swift`
5. Verify: `swift test --filter {ClassName}Spec`

### Example:
```bash
# Input: "add unit test for BidLoader"
# 1. Detect module
grep -r "class BidLoader" Sources/  # → Sources/Core/MSPCore/BidLoader.swift
# Module: MSPCore

# 2. Output path
Tests/MSPCoreTests/BidLoaderSpec.swift

# 3. Populate template with BidLoader + MSPCore
```

**Common Modules**:
- `MSPCore` - Core SDK functionality
- `MSPiOSSDK` - Public iOS SDK API
- `MSPNovaAdapter` - Nova adapter

**Full Skill**: `.agents-shared/skills/unit-test-generator.skill.md`

---

## Skill 2: Quick Fix

**When**: Applying mechanical, pattern-based fixes
**Tier**: 0-1 (Trivial to Standard)

### Common Patterns:

#### Fix Force Unwrap (Pattern 1)
```diff
- let value = optional!
+ guard let value = optional else { return }
```

#### Add Nil Check (Pattern 2)
```diff
  func process(_ data: Data?) {
+     guard let data = data else { return }
      // use data
  }
```

#### Add Missing Import (Pattern 3)
```diff
+ import Foundation
  class MyClass {
      let date = Date()
  }
```

#### Fix Typo (Pattern 4)
```bash
# IMPORTANT: Search first!
grep -r "OldName" Sources/
# Then replace all occurrences
```

#### Remove Unused Code (Pattern 5)
```diff
- let unusedVar = computeValue()
  performLoad()
```

#### Add Access Control (Pattern 6)
```diff
- class BidLoader {
+ internal class BidLoader {
```

**Full Skill**: `.agents-shared/skills/quick-fix.skill.md`

---

## Skill 3: Refactor Pattern

**When**: Improving code structure with known patterns
**Tier**: 1 (Standard)

### Common Patterns:

#### Extract Method (Pattern 1)
**Trigger**: Method >50 lines
```swift
// Before: 45-line method
func processAd() { /* ... */ }

// After: Extract logical sections
func processAd() {
    guard isValidBid(bid) else { return }
    let request = buildAdRequest(from: bid)
    handleAdResponse(request)
}

private func isValidBid(_ bid: Bid) -> Bool { /* ... */ }
private func buildAdRequest(from bid: Bid) -> URLRequest { /* ... */ }
```

#### Replace Magic Numbers (Pattern 2)
```swift
// Before
if timeout > 30000 { }

// After
private static let maxTimeoutMs: Int = 30_000
if timeout > Self.maxTimeoutMs { }
```

#### Consolidate Conditionals (Pattern 3)
```swift
// Before: Multiple early returns
if bid == nil { return }
if bid!.price < 0 { return }
if bid!.adType == .unknown { return }

// After: Guard let chaining
guard let bid = bid,
      bid.price >= 0,
      bid.adType != .unknown else {
    return
}
```

#### Replace Nested Conditional with Guard (Pattern 7)
```swift
// Before: Nested ifs
if user != nil {
    if user.hasSubscription {
        if !user.isExpired {
            // logic
        }
    }
}

// After: Guard statements
guard let user = user else { return }
guard user.hasSubscription else { return }
guard !user.isExpired else { return }
// logic
```

**Full Skill**: `.agents-shared/skills/refactor-pattern.skill.md`

---

## Skill 4: Constitutional Auditor

**When**: Checking code compliance against constitution
**Location**: `constitution.md` (Federal) + domain-specific constitutions

### Quick Audit Steps:
1. Identify applicable constitution:
   - `Sources/**/*.swift` → `Sources/constitution.md`
   - `Scripts/**/*.sh` → `Scripts/constitution.md`
   - `Tests/**/*Spec.swift` → `Tests/constitution.md`
2. Check for violations:
   - Force unwraps (`!`)
   - Public API changes
   - Missing error handling
   - Import violations
3. Report findings with article citations

**Full Skill**: `.agents-shared/skills/constitutional-auditor.skill.md`

---

## Skill 5: Scripts Failure Analyst

**When**: CI/CD or release script fails
**Context**: `.msp-release-state.json`, CI logs

### Quick Steps:
1. Check release state: `cat .msp-release-state.json`
2. Parse failure point from state
3. Analyze CI logs
4. Per Article I.4: Propose script-based fix, not manual workaround

**Full Skill**: `.agents-shared/skills/scripts-failure-analyst.skill.md`

---

## Skill 6: Sources Bug Analyst

**When**: Runtime crash or logic bug in Swift code
**Context**: Stack traces, crash logs

### Quick Steps:
1. Parse stack trace for crash location
2. Trace code path to understand data flow
3. Identify root cause
4. Propose fix that handles edge cases

**Full Skill**: `.agents-shared/skills/sources-bug-analyst.skill.md`

---

## Shared Tools

### Scripts/tools/
| Tool | Usage | Purpose |
|------|-------|---------|
| `get-test-template.sh` | `./Scripts/tools/get-test-template.sh` | Print unit test template |
| `validate-script.sh` | `./Scripts/tools/validate-script.sh <path>` | Run shellcheck |

### Sources/tools/
| Tool | Usage | Purpose |
|------|-------|---------|
| `find-class.sh` | `./Sources/tools/find-class.sh <TypeName>` | Find type definition |
| `list-public-api.sh` | `./Sources/tools/list-public-api.sh <Module>` | List public API |
| `check-imports.sh` | `./Sources/tools/check-imports.sh [Module]` | Check imports |

---

## Common Task Patterns

### Pattern A: Add Unit Test
```bash
$ codex "add unit test for BidLoader class"

# Actions:
# 1. Use find-class.sh to locate BidLoader
# 2. Detect module (MSPCore)
# 3. Get template via get-test-template.sh
# 4. Create Tests/MSPCoreTests/BidLoaderSpec.swift
# 5. Verify: swift test --filter BidLoaderSpec
```

### Pattern B: Batch Rename
```bash
$ codex "rename OldName to NewName in Sources/"

# Actions:
# 1. Search: grep -r "OldName" Sources/
# 2. Replace in each file
# 3. Verify: grep -r "OldName" Sources/ (expect 0 results)
```

### Pattern C: Fix Shellcheck Warnings
```bash
$ codex "fix shellcheck warnings in msp-release.sh"

# Actions:
# 1. Run: shellcheck Scripts/msp-release.sh
# 2. Fix each warning
# 3. Verify: shellcheck Scripts/msp-release.sh (expect 0)
```

---

## Constitutional Quick Reference

| File Location | Constitution | Key Articles |
|---------------|--------------|--------------|
| `Sources/**/*.swift` | `Sources/constitution.md` | IV (Error Handling), V (Public API) |
| `Scripts/**/*.sh` | `Scripts/constitution.md` | VI (Script Safety), VII (Validation) |
| `Tests/**/*Spec.swift` | `Tests/constitution.md` | VIII (TDD), IX (Readability) |

### Common Violations to Check:
- Force unwraps (`!`) → Article IV.3
- Missing error handling → Article IV.2
- Public API changes → Article V (requires approval)
- Missing tests → Article VIII.1
- Direct .xcodeproj edits → Article I.2

---

## Escalation Rules (Quick Reference)

| Condition | Action |
|-----------|--------|
| Public/open API changes | Escalate to Claude Code |
| >5 files affected | Escalate to Claude Code |
| Root cause unclear | Escalate to Claude Code |
| Architectural decision | Escalate to Claude Code |
| Task tier 2-3 | Escalate to Claude Code |

**To escalate**:
```bash
$ claude
> [detailed prompt with context]
```

---

## Output Template (Tier 1)

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

## Verification
$ [command to verify]
Result: [actual result]
```

---

## Quick Tips

1. **Always search before batch operations**:
   ```bash
   grep -r "pattern" Sources/
   ```

2. **Use appropriate tools**:
   - Find class → `./Sources/tools/find-class.sh`
   - Get template → `./Scripts/tools/get-test-template.sh`

3. **Verify immediately**:
   ```bash
   swift test --filter RelevantSpec
   ```

4. **Cite constitution**:
   ```
   ## Constitutional Compliance
   - Article IV.3: No force unwraps
   - Article I.2: Not modifying .xcodeproj
   ```

5. **When in doubt, escalate**:
   ```
   ⚠️ ESCALATION RECOMMENDED
   Reason: [brief reason]
   To proceed: $ claude
   ```

---

## Full Documentation

- **Complete Codex directives**: `.codex/CODEX.md`
- **Cross-agent rules**: `AGENTS.md`
- **Federal constitution**: `constitution.md`
- **Shared skills**: `.agents-shared/skills/`
- **Shared protocols**: `.agents-shared/protocols/`

---

**Last Updated**: 2026-01-14
**Version**: 1.0
