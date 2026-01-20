# Cursor Commands

> **Version**: 1.0
> **Last Updated**: 2026-01-14

This directory contains command patterns and examples for Cursor IDE.

---

## Overview

Unlike Codex CLI which uses explicit commands, Cursor works through natural language in Chat/Composer/Inline modes. These "commands" are really **usage patterns** and **prompts templates**.

---

## Cursor Modes

### Chat Mode
**Purpose**: Analysis, explanation, questions

**Invocation**: Cmd+L (or sidebar)

**Best for**:
- Understanding code
- Getting architectural context
- Planning changes
- Asking questions

---

### Composer Mode
**Purpose**: Multi-file editing

**Invocation**: Cmd+I

**Best for**:
- Implementing features
- Refactoring across files
- Adding tests
- Coordinated changes

---

### Inline Mode
**Purpose**: Quick local edits

**Invocation**: Cmd+K (select code first)

**Best for**:
- Simple refactoring
- Adding null checks
- Extracting methods
- Quick fixes

---

## Common Prompt Patterns

### Pattern A: Code Understanding

**Chat**:
```
@file:Sources/Core/BidLoader.swift
Explain how this class works and its dependencies
```

**Chat**:
```
@codebase
What's the overall architecture of the ad loading system?
```

**Chat**:
```
@folder:Sources/Adapters
How are adapters structured? Show me the common pattern.
```

---

### Pattern B: Implement Feature

**Composer**:
```
Implement a caching layer for BidLoader

Requirements:
- LRU cache with max 100 entries
- Thread-safe
- Integrate into existing BidLoader
- Follow existing patterns in the codebase

@file:Sources/Core/BidLoader.swift
@folder:Sources/Core
```

---

### Pattern C: Refactor

**Inline (select duplicated code, Cmd+K)**:
```
Extract this logic to a private helper method called processBidResponse
```

**Composer (for larger refactoring)**:
```
Refactor the adapter initialization code:
- Extract common logic to BaseAdapter
- Keep adapter-specific logic in subclasses
- Maintain existing public APIs

@folder:Sources/Adapters
```

---

### Pattern D: Add Tests

**Composer**:
```
Add Quick/Nimble unit tests for BidLoader class

Cover:
- Successful bid loading
- Nil bid response handling
- Network error handling
- Cache hit/miss scenarios

Follow template: @file:Tests/templates/unit_test_spec.swift.template
Create at: Tests/MSPCoreTests/BidLoaderSpec.swift

@file:Sources/Core/BidLoader.swift
```

---

### Pattern E: Fix Bug

**Chat (first understand)**:
```
@file:Sources/Core/BidLoader.swift

This crashes with "unexpectedly found nil" on line 42.
Analyze the stack trace and suggest a fix:

[paste stack trace]
```

**Inline (then apply fix, select problematic code, Cmd+K)**:
```
Add guard let to safely unwrap bidResponse and return nil with error log if nil
```

---

### Pattern F: Explore Architecture

**Chat**:
```
@codebase

I need to add a new adapter. Explain:
1. The adapter protocol structure
2. How existing adapters are implemented
3. The pattern I should follow
4. Where files should be created
```

---

## Context Management Best Practices

### Use Specific @mentions

✅ **Good**:
```
@file:Sources/Core/BidLoader.swift
@folder:Sources/Adapters
@codebase [specific question]
```

❌ **Too Vague**:
```
Look at the code and fix it
```

---

### Build Context Incrementally

For complex tasks:

**Step 1 - Understand**:
```
@codebase How does authentication work in this project?
```

**Step 2 - Plan**:
```
Given that architecture, how should I add OAuth support?
```

**Step 3 - Implement (Composer)**:
```
Add OAuth support following the plan:
@file:[relevant auth files]
```

---

## Escalation Patterns

### When Task Exceeds Cursor Scope

**In Chat**:
```
⚠️ This requires architectural design beyond Cursor's scope.

Recommend escalating to Claude Code:

$ claude
> Design OAuth authentication architecture for MSP SDK
> Consider: existing auth flow, backwards compatibility, security
> Files to review: @folder:Sources/Core/Auth
```

---

## Verification Patterns

After making changes:

**In Chat**:
```
I've implemented the changes. Run verification:

$ swift test --filter BidLoaderSpec
$ ./Scripts/target-switching/round-trip-test.sh

Confirm: All tests pass
```

---

## Anti-Patterns

### ❌ Don't: Vague Requests

```
Make the code better
Fix everything
Optimize this
```

### ✅ Do: Specific Requests

```
Add nil check for bidResponse on line 42
Extract duplicate logic from lines 50-75 to a helper method
Add unit test for the caching behavior we just implemented
```

---

### ❌ Don't: Skip Context

```
[In Composer with no files referenced]
Implement the new feature
```

### ✅ Do: Provide Context

```
[In Composer]
Implement caching layer for BidLoader

@file:Sources/Core/BidLoader.swift
@file:Sources/Core/Cache.swift (if exists)
@folder:Sources/Core
```

---

## Quick Reference Card

### Keyboard Shortcuts
- **Cmd+L**: Open Chat
- **Cmd+I**: Open Composer
- **Cmd+K**: Inline edit (select code first)

### Context References
- `@codebase [question]`: Search entire codebase
- `@file:path/to/file`: Reference specific file
- `@folder:path/to/dir`: Reference directory

### Escalation
When task requires:
- Architectural decisions → Claude Code
- Public API changes → Claude Code
- >7 files → Claude Code
- Batch operations → Codex CLI

---

## Example Session

**Goal**: Add caching to BidLoader

```
[Cmd+L - Open Chat]
> @file:Sources/Core/BidLoader.swift
> Explain how bid loading works

[Review response]

> What's the best approach to add LRU caching here?

[Review approach]

[Cmd+I - Open Composer]
> Implement LRU caching for BidLoader following the approach we discussed
>
> Requirements:
> - Max 100 entries
> - Thread-safe using NSCache
> - Preserve existing public API
>
> @file:Sources/Core/BidLoader.swift

[Review changes in Composer]
[Apply changes]

[Cmd+I again for tests]
> Add unit tests for the caching behavior
>
> Test cases:
> - Cache stores result
> - Cache retrieves result
> - Cache evicts when full
>
> Template: @file:Tests/templates/unit_test_spec.swift.template

[Review and apply]

[Back to Chat]
> Run verification:
> $ swift test --filter BidLoaderSpec

[Confirm all pass]

Done! ✅
```

---

## Tips for Effective Use

1. **Start with Chat**: Understand before implementing
2. **Use @mentions**: Provide relevant context
3. **Iterate**: Don't expect perfection first try
4. **Verify**: Always run tests after changes
5. **Escalate**: When you hit limitations, use Claude Code

---

## Governance

- **Flexibility**: These are patterns, not rigid commands
- **Adaptation**: Adjust prompts to your specific task
- **Escalation**: Follow protocol when tasks exceed Cursor scope
