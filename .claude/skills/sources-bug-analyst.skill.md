---
name: sources-bug-analyst
description: A skill for diagnosing Swift business logic bugs, runtime errors, and crashes in the SDK source code. Analyzes stack traces, code flow, and memory issues.
allowed-tools: Read, Glob, Grep
applies-to: Sources/
---
# Sources Bug Analyst Skill

## Purpose
Diagnose runtime errors, crashes, and logic bugs in Swift source code. This skill helps identify root causes in the SDK's business logic.

## Scope
- **Does**: Analyze crashes, stack traces, logic errors, memory issues
- **Does NOT**: Analyze CI/CD or shell script failures (use `scripts-failure-analyst` for that)

## Inputs Required
1. Crash log or stack trace
2. Error message or symptom description
3. Steps to reproduce (if available)

## Execution Steps

### Step 1: Crash/Error Analysis
Parse the stack trace to identify:
- Crashing thread and frame
- Exception type (`EXC_BAD_ACCESS`, `NSException`, etc.)
- Faulting code location (file:line)

### Step 2: Code Path Tracing
From the crash point, trace backwards:
```
1. Find the crashing function
2. Identify all callers (use Grep)
3. Map the data flow to the crash point
```

### Step 3: Root Cause Categories
| Category | Indicators | Common Fixes |
|----------|-----------|--------------|
| **Force Unwrap** | `!` on nil | Use `guard let` or `if let` |
| **Retain Cycle** | Memory growth, dealloc not called | Add `[weak self]` in closures |
| **Threading** | `EXC_BAD_ACCESS`, race conditions | Use `DispatchQueue` properly |
| **Out of Bounds** | Array index errors | Bounds checking |
| **Logic Error** | Wrong behavior, no crash | Trace algorithm |

### Step 4: Constitutional Compliance Check
Verify if the bug violates any constitutional articles:
- **Article IV.3**: Force unwraps
- **Article IV.2**: Improper error handling
- **Article III**: Modularity violations

### Step 5: Fix Proposal
Propose a fix that:
- Addresses the root cause, not just the symptom
- Complies with `Sources/constitution.md`
- Includes suggested unit test to prevent regression

## Output Format
```
## Sources Bug Analysis Report

### Bug Summary
- **Type**: Runtime crash / Logic error / Memory leak
- **Location**: `Sources/Core/MSPCore/BidLoader.swift:142`
- **Symptom**: [What the user observed]

### Stack Trace Analysis
```
Thread 0 Crashed:
0  MSPCore  BidLoader.loadBid() + 0x42
1  MSPCore  AdManager.requestAd() + 0x18
```

### Root Cause
[Detailed explanation of why the bug occurs]

### Code Analysis
```swift
// Line 142 - Force unwrap on optional that can be nil
let bid = response.bid!  // CRASH: bid is nil when no fill
```

### Proposed Fix
**File**: `Sources/Core/MSPCore/BidLoader.swift`

```diff
- let bid = response.bid!
+ guard let bid = response.bid else {
+     completion(.failure(.noFill))
+     return
+ }
```

### Constitutional Violations
- **[Article IV.3]** Force unwrap detected

### Regression Test
```swift
it("should handle nil bid gracefully") {
    let response = BidResponse(bid: nil)
    sut.handleResponse(response)
    expect(errorReceived).to(equal(.noFill))
}
```
```

## Constitutional Compliance
- **Article IV.3**: No force unwraps
- **Article IV.2**: Proper error handling
- **Sources/constitution.md**: API design, testability
