---
name: refactor-pattern
description: Apply common refactoring patterns to improve code structure
category: generation
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Read, Edit, Grep]
---

# Refactor Pattern Skill

> **Type**: Generation Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Apply established refactoring patterns to improve code maintainability

---

## Purpose

Execute well-defined refactoring patterns from Martin Fowler's catalog and Swift-specific best practices:
- Extract method/function
- Inline temporary variable
- Rename for clarity
- Replace magic numbers with constants
- Extract common logic
- Consolidate conditional expressions

**Task Tier**: Tier 1 (Standard) - Patterns are known, application is mechanical

---

## Scope

**Does**:
- Apply catalog refactoring patterns
- Improve code readability
- Reduce duplication
- Enhance maintainability
- Preserve existing behavior

**Does NOT**:
- Change algorithmic logic
- Modify public APIs (requires approval)
- Make architectural decisions (escalate to architect)
- Fix bugs (use sources-bug-analyst.skill.md)

---

## When to Use

- Code review identifies duplication
- Method/function too long (>50 lines)
- Complex conditional logic
- Magic numbers/strings detected
- Poor naming clarity

**Quick Decision**:
- If refactoring is from known catalog → Use this skill
- If redesign needed → Escalate to architect
- If fixing bug → Use sources-bug-analyst.skill.md

---

## Refactoring Patterns

### Pattern 1: Extract Method

**Trigger**: Method >50 lines, or logical block can be named

**Before**:
```swift
func processAd() {
    // 15 lines of bid validation
    if bid.price < minPrice { return }
    if bid.adType != .banner { return }
    if bid.isExpired() { return }
    // ... more validation

    // 20 lines of ad loading
    let request = URLRequest(url: bid.url)
    // ... request configuration

    // 10 lines of response handling
}
```

**After**:
```swift
func processAd() {
    guard isValidBid(bid) else { return }
    let request = buildAdRequest(from: bid)
    handleAdResponse(request)
}

private func isValidBid(_ bid: Bid) -> Bool {
    guard bid.price >= minPrice else { return false }
    guard bid.adType == .banner else { return false }
    guard !bid.isExpired() else { return false }
    return true
}

private func buildAdRequest(from bid: Bid) -> URLRequest {
    // ... request building logic
}

private func handleAdResponse(_ request: URLRequest) {
    // ... response handling logic
}
```

**When to Apply**:
- Method exceeds 50 lines
- Nested logic is hard to follow
- Logical sections can be named meaningfully

---

### Pattern 2: Replace Magic Numbers

**Trigger**: Hardcoded numbers without explanation

**Before**:
```swift
if bidResponse.timeout > 30000 {
    log_warning("Timeout too long")
}

let cacheSize = 100
```

**After**:
```swift
private static let maxBidTimeoutMs: Int = 30_000
private static let defaultCacheSize: Int = 100

if bidResponse.timeout > Self.maxBidTimeoutMs {
    log_warning("Timeout too long")
}

let cacheSize = Self.defaultCacheSize
```

**When to Apply**:
- Number appears multiple times
- Number's purpose isn't obvious
- Number might change in future

**Naming Convention**:
- `max*`, `min*` for bounds
- `default*` for default values
- `*Timeout`, `*Delay` for time values
- Units in name (Ms, Seconds, Meters)

---

### Pattern 3: Consolidate Conditional

**Trigger**: Multiple similar conditionals

**Before**:
```swift
if bid == nil {
    return
}
if bid!.price < 0 {
    return
}
if bid!.adType == .unknown {
    return
}
```

**After**:
```swift
guard let bid = bid,
      bid.price >= 0,
      bid.adType != .unknown else {
    return
}
```

**When to Apply**:
- Multiple early returns with same action
- Related conditions checking same object
- Can use guard let chaining

---

### Pattern 4: Extract Variable

**Trigger**: Complex expression used multiple times or hard to read

**Before**:
```swift
if user.subscription.plan.tier.level > 3 && user.subscription.plan.tier.level < 7 {
    // ...
}
```

**After**:
```swift
let tierLevel = user.subscription.plan.tier.level
let isPremiumTier = tierLevel > 3 && tierLevel < 7

if isPremiumTier {
    // ...
}
```

**When to Apply**:
- Expression appears multiple times
- Expression is complex/nested
- Naming the expression adds clarity

---

### Pattern 5: Inline Temporary Variable

**Trigger**: Variable used only once, obscures rather than clarifies

**Before**:
```swift
let hasItems = !cart.items.isEmpty
return hasItems
```

**After**:
```swift
return !cart.items.isEmpty
```

**When to Apply**:
- Variable used exactly once
- Variable name doesn't add clarity
- Expression is self-explanatory

**Don't Apply If**:
- Variable name significantly clarifies intent
- Expression will be reused
- Debugging benefits from intermediate value

---

### Pattern 6: Rename Variable/Method

**Trigger**: Poor naming, abbreviations, misleading names

**Before**:
```swift
func proc(r: Response) {
    let tmp = r.data
    let sz = tmp.count
}
```

**After**:
```swift
func processResponse(_ response: Response) {
    let responseData = response.data
    let dataSize = responseData.count
}
```

**When to Apply**:
- Name is abbreviated unnecessarily
- Name doesn't reflect purpose
- Name is misleading

**Swift Naming Guidelines**:
- `lowerCamelCase` for variables/methods
- `UpperCamelCase` for types
- Avoid abbreviations (unless well-known: URL, HTTP, ID)
- Prefer clarity over brevity

**Important**: Search all usages before renaming:
```bash
grep -r "proc" Sources/
```

---

### Pattern 7: Replace Nested Conditional with Guard

**Trigger**: Deeply nested if statements

**Before**:
```swift
func loadAd() {
    if user != nil {
        if user.hasSubscription {
            if !user.isExpired {
                // actual logic here
            }
        }
    }
}
```

**After**:
```swift
func loadAd() {
    guard let user = user else { return }
    guard user.hasSubscription else { return }
    guard !user.isExpired else { return }

    // actual logic here
}
```

**When to Apply**:
- Nesting level > 2
- Each condition is a precondition
- "Happy path" logic is at the end

---

### Pattern 8: Extract Common Logic

**Trigger**: Duplicated code in multiple methods

**Before**:
```swift
// In method A
if adResponse.isValid {
    log_info("Valid response")
    processAd(adResponse.ad)
}

// In method B
if bidResponse.isValid {
    log_info("Valid response")
    processBid(bidResponse.bid)
}
```

**After**:
```swift
private func handleValidResponse<T>(
    _ response: T,
    isValid: Bool,
    process: (T) -> Void
) {
    guard isValid else { return }
    log_info("Valid response")
    process(response)
}

// Usage
handleValidResponse(adResponse, isValid: adResponse.isValid) { processAd($0.ad) }
handleValidResponse(bidResponse, isValid: bidResponse.isValid) { processBid($0.bid) }
```

**When to Apply**:
- Similar code appears 3+ times
- Logic is identical, only data differs
- Extraction doesn't over-complicate

---

## Execution Steps

### Step 1: Identify Pattern

Match the code smell to a refactoring pattern above.

### Step 2: Read Context

```bash
# Read the file
cat Sources/.../File.swift

# Search for usages (if renaming)
grep -r "oldName" Sources/
```

### Step 3: Verify Safety

Check that refactoring:
- [ ] Preserves behavior (no logic change)
- [ ] Doesn't break public API
- [ ] Doesn't affect tests (unless test also refactored)
- [ ] Improves readability

### Step 4: Apply Refactoring

Use Edit tool with exact string replacement.

### Step 5: Verify

```bash
# Compile
swift build

# Run tests
swift test --filter {RelevantTestSpec}
```

---

## Output Format

```markdown
## Refactoring Applied

**Pattern**: [Pattern name]
**Location**: `Sources/.../File.swift`
**Motivation**: [Why this refactoring improves code]

### Changes
```diff
- old code
+ new code
```

### Verification
- ✅ Behavior preserved
- ✅ Tests pass
- ✅ Readability improved
```

---

## Example Usage

### For Claude Code

```markdown
@../.agents-shared/skills/refactor-pattern.skill.md

Extract method from lines 45-67 in BidLoader.swift
Pattern: Extract Method
New method name: validateBidResponse
```

### For Codex CLI

```bash
$ codex "extract magic number 30000 to constant MAX_TIMEOUT_MS in AdManager.swift"
# Applies Pattern 2 automatically
```

### For Cursor

**Inline Mode (Cmd+K, select code)**:
```
Extract this to a private method called processBidResponse
```

**Composer Mode**:
```
Refactor @file:Sources/Core/AdManager.swift
- Extract method for bid validation logic (lines 45-67)
- Replace magic numbers with constants
- Consolidate guard statements
```

---

## Multi-File Refactoring

Some patterns affect multiple files (e.g., rename public method).

**Procedure**:
1. **Search**: Find all usages
   ```bash
   grep -r "oldMethodName" Sources/ Tests/
   ```

2. **Assess Impact**:
   - Internal method → Refactor freely
   - Public method → Requires approval

3. **Apply Systematically**:
   - Start with declaration
   - Update all call sites
   - Update tests

4. **Verify**:
   ```bash
   swift build && swift test
   ```

---

## Anti-Patterns

### ❌ Don't: Over-Extract

```
Bad: Extract every 3-line block to a method
Good: Extract when it improves readability
```

### ❌ Don't: Premature Abstraction

```
Bad: Create generic solution for 2 instances
Good: Wait for 3rd instance, then abstract
```

### ❌ Don't: Rename Without Search

```
Bad: Rename without checking all usages
Good: grep -r "oldName" first
```

---

## Constitutional Compliance

This skill supports:
- **Article IV.1**: Code must be maintainable
- **Article IV.4**: Follow Swift conventions
- **Federal Article II.1**: Code passes validation

---

## Tips for Effective Refactoring

1. **One Pattern at a Time**: Don't mix multiple refactorings
2. **Test After Each**: Ensure behavior preserved
3. **Small Steps**: Easier to verify correctness
4. **Commit Often**: Easy to rollback if needed
5. **Improve Tests Too**: Refactor test code with same care

---

## Related Skills

- `quick-fix.skill.md`: For mechanical fixes
- `sources-bug-analyst.skill.md`: If refactoring reveals a bug
- `constitutional-auditor.skill.md`: Verify refactored code complies
- `unit-test-generator.skill.md`: Add tests for extracted methods
