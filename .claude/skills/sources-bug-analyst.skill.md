---
name: sources-bug-analyst
description: Diagnose Swift business logic bugs, runtime errors, and crashes
category: analysis
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Read, Glob, Grep]
applies-to: Sources/
quick_reference: "When: Runtime crash or logic bug in Swift. Steps: Parse stack trace → Trace code path → Identify root cause → Propose fix."
---

# Sources Bug Analyst Skill

> **Type**: Analysis Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Root cause analysis for Swift code failures

---

## Purpose

Diagnose issues in Swift source code:
- Runtime crashes and exceptions
- Logic bugs and incorrect behavior
- Memory issues (leaks, retain cycles)
- Threading problems and race conditions

---

## Scope

**Does**:
- Analyze crash logs and stack traces
- Trace code execution paths
- Identify memory and threading issues
- Propose Swift-based fixes

**Does NOT**:
- Analyze CI/CD failures (use `scripts-failure-analyst.skill.md`)
- Make architectural decisions (escalate to Claude Code + Opus)
- Optimize for performance (unless bug-related)

---

## When to Use

- App crashes or throws exceptions
- Logic error produces wrong results
- Memory leak suspected
- Test fails unexpectedly
- Unexpected nil value encountered

---

## Required Inputs

1. **Symptom**: What went wrong (crash, wrong result, etc.)
2. **Stack Trace** (if crash): Full crash log
3. **Steps to Reproduce**: How to trigger the issue
4. **Expected vs Actual**: What should happen vs what happens

---

## Execution Steps

### Step 1: Crash/Error Analysis

If stack trace available, parse it:

```
Thread 0 Crashed:
0  libswiftCore.dylib   swift_unexpectedError + 0x42
1  MSPCore              BidLoader.loadBid() + 0x38
2  MSPCore              AdManager.requestAd() + 0x18
3  MSPiOSSDK            ViewController.viewDidLoad() + 0x24
```

**Extract**:
- **Crashing Thread**: Usually Thread 0
- **Exception Type**: `EXC_BAD_ACCESS`, `NSException`, `fatalError`, etc.
- **Crash Location**: File and line number
- **Call Stack**: Who called the crashing function

**Common Exception Types**:
| Exception | Likely Cause |
|-----------|--------------|
| `EXC_BAD_ACCESS` | Accessing deallocated memory, force unwrap on nil |
| `NSInvalidArgumentException` | Passing invalid argument to method |
| `NSRangeException` | Array index out of bounds |
| `fatalError` | Explicitly thrown in code |

---

### Step 2: Code Path Tracing

From crash point, work backwards:

1. **Read the crashing function**:
   ```bash
   # Find the file
   find Sources/ -name "BidLoader.swift"

   # Read around the crash line
   cat Sources/Core/MSPCore/BidLoader.swift | sed -n '135,150p'
   ```

2. **Identify callers**:
   ```bash
   grep -r "loadBid(" Sources/
   ```

3. **Map data flow**:
   - Where does the problematic data come from?
   - What transformations happen along the way?
   - Where does it become nil/invalid?

---

### Step 3: Root Cause Classification

| Category | Indicators | Common Swift Patterns | Fix Strategy |
|----------|-----------|----------------------|--------------|
| **Force Unwrap** | `!` on nil optional | `let x = optional!` | Use `guard let` or `if let` |
| **Retain Cycle** | Memory grows, dealloc never called | `self` captured in closure | Add `[weak self]` or `[unowned self]` |
| **Threading** | `EXC_BAD_ACCESS`, intermittent crashes | Shared mutable state | Use `DispatchQueue`, `@MainActor` |
| **Out of Bounds** | `NSRangeException` | `array[index]` | Check bounds: `guard index < array.count` |
| **Logic Error** | Wrong result, no crash | Incorrect algorithm | Trace logic, add tests |
| **API Misuse** | `NSInvalidArgumentException` | Wrong parameter type/value | Validate inputs |

---

### Step 4: Constitutional Compliance Check

Check if bug violates constitution:

**Sources/constitution.md**:
- **Article IV.3**: Force unwraps should be avoided
- **Article IV.2**: Proper error handling required
- **Article IV.1**: Code must be tested
- **Article III.1**: No third-party SDK imports in Core

**Federal constitution.md**:
- **Article II.1**: Must pass validation gates

---

### Step 5: Fix Proposal

Propose a fix that:
- ✅ Addresses root cause (not just symptom)
- ✅ Complies with `Sources/constitution.md`
- ✅ Includes unit test to prevent regression
- ✅ Preserves existing API (unless breaking change needed)

---

## Output Format

```markdown
## Sources Bug Analysis Report

---
analysis_date: 2026-01-14
bug_type: runtime_crash | logic_error | memory_leak
severity: critical | high | medium | low
location: Sources/Core/MSPCore/BidLoader.swift:142
---

### Bug Summary
- **Type**: Runtime crash (force unwrap on nil)
- **Location**: `Sources/Core/MSPCore/BidLoader.swift:142`
- **Symptom**: App crashes when ad request returns no fill
- **Reproducibility**: 100% when no ad available

### Stack Trace Analysis
```
Thread 0 Crashed:
0  MSPCore              BidLoader.loadBid() + 0x42 (BidLoader.swift:142)
1  MSPCore              AdManager.requestAd() + 0x18
2  MSPiOSSDK            ViewController.loadAd() + 0x24
```

**Key Frame**: Frame 0 - BidLoader.swift line 142

### Root Cause

The crash occurs when `response.bid` is `nil` but the code force-unwraps it:

```swift
// Line 142 - BidLoader.swift
let bid = response.bid!  // 💥 CRASH: bid is nil when no fill
```

**Data Flow**:
1. Network request returns `200 OK`
2. JSON parsing succeeds
3. `BidResponse` object created with `bid: nil` (valid "no fill" response)
4. Code assumes `bid` always exists → force unwrap → crash

**Root Cause Category**: Force Unwrap (violates Article IV.3)

### Code Analysis

**Problematic Code**:
```swift
func handleResponse(_ response: BidResponse) {
    let bid = response.bid!  // Line 142
    delegate?.didReceiveBid(bid)
}
```

**Why It Fails**:
- `BidResponse.bid` is `Optional<Bid>` (can be nil)
- "No fill" responses have `bid = nil` (valid scenario)
- Force unwrap assumes `bid` always exists (false assumption)

### Proposed Fix

**File**: `Sources/Core/MSPCore/BidLoader.swift`

```diff
  func handleResponse(_ response: BidResponse) {
-     let bid = response.bid!
-     delegate?.didReceiveBid(bid)
+     guard let bid = response.bid else {
+         // No fill case - valid scenario
+         delegate?.didReceiveNoFill()
+         return
+     }
+     delegate?.didReceiveBid(bid)
  }
```

**Changes**:
1. Replace force unwrap with `guard let`
2. Handle nil case explicitly (no fill)
3. Add delegate method for no-fill scenario

**Additional Changes Needed**:
```swift
// In AdManagerDelegate protocol
protocol AdManagerDelegate: AnyObject {
    func didReceiveBid(_ bid: Bid)
+   func didReceiveNoFill()  // New method
}
```

### Constitutional Violations
- ❌ **[Sources/Article IV.3]**: Force unwrap detected (`.bid!`)
- ❌ **[Sources/Article IV.2]**: Improper error handling (missing nil case)

### Regression Test

**File**: `Tests/MSPCoreTests/BidLoaderSpec.swift`

```swift
describe("BidLoader") {
    context("when response has no fill") {
        it("should call didReceiveNoFill delegate method") {
            // Given
            let response = BidResponse(bid: nil)  // No fill case
            let delegate = MockDelegate()
            sut.delegate = delegate

            // When
            sut.handleResponse(response)

            // Then
            expect(delegate.noFillCalled).to(beTrue())
            expect(delegate.bidReceivedCalled).to(beFalse())
        }
    }

    context("when response has bid") {
        it("should call didReceiveBid delegate method") {
            // Given
            let bid = Bid(id: "123", price: 1.0)
            let response = BidResponse(bid: bid)
            let delegate = MockDelegate()
            sut.delegate = delegate

            // When
            sut.handleResponse(response)

            // Then
            expect(delegate.bidReceivedCalled).to(beTrue())
            expect(delegate.bidReceived).to(equal(bid))
        }
    }
}
```

### Verification
```bash
# Run tests
$ swift test --filter BidLoaderSpec

# Expected: All tests pass, including new no-fill test
```

### Prevention
- Add linter rule to detect force unwraps
- Code review checklist: "Are all optionals safely unwrapped?"
- Consider using SwiftLint with `force_unwrapping` rule
```

---

## Common Bug Patterns

### Pattern 1: Force Unwrap

**Symptom**: Crash with `unexpectedlyFoundNil`

**Detection**:
```bash
grep -r "!" Sources/ | grep -v "//" | grep -v "!="
```

**Fix**: Replace with `guard let` or `if let`

---

### Pattern 2: Retain Cycle

**Symptom**: Memory usage grows, `deinit` never called

**Detection**:
```swift
// Look for closures without [weak self]
grep -r "{ self\." Sources/
```

**Fix**:
```diff
- completion { self.handleResult($0) }
+ completion { [weak self] in self?.handleResult($0) }
```

---

### Pattern 3: Threading Issue

**Symptom**: Intermittent `EXC_BAD_ACCESS`, race conditions

**Detection**: Crash happens randomly, hard to reproduce

**Fix**: Ensure UI updates on main thread:
```swift
DispatchQueue.main.async {
    // UI updates here
}
```

---

## Tips for Effective Debugging

1. **Read the Crash Line**: Often the crash location is obvious
2. **Trace Backwards**: Work from crash to origin
3. **Reproduce Locally**: Try to make it crash on demand
4. **Add Logging**: If unclear, add debug prints
5. **Write Test First**: Reproduce bug in test, then fix

---

## Related Skills

- `constitutional-auditor.skill.md`: Verify fix complies with constitution
- `unit-test-generator.skill.md`: Generate regression test
- `scripts-failure-analyst.skill.md`: For build/CI failures
