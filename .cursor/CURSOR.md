# Cursor IDE Operational Directives

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: Cursor IDE Agent

---

## 1. Core Imports

```
@../constitution.md
@../AGENTS.md
@../.agents-shared/protocols/task-tier.protocol.md
@../.agents-shared/protocols/model-selection.protocol.md
@../.agents-shared/protocols/output-format.protocol.md
@../.agents-shared/protocols/escalation.protocol.md
@../.agents-shared/protocols/handoff.protocol.md
```

---

## 2. Cursor Role Definition

**Primary Role**: Interactive Development Partner
**Interaction Mode**: IDE-integrated, real-time feedback
**Tier Coverage**: Tier 1-2 (Standard to Complex)

### 2.1 Best Use Cases

| Scenario | Cursor Feature | Model |
|----------|----------------|-------|
| "帮我理解这段代码" | Chat + @file | Sonnet 3.5 |
| "重构这个函数" | Inline (Cmd+K) | Sonnet 3.5 |
| "实现这个新功能" | Composer | Sonnet 4 |
| "修复这个 bug" | Chat + 选中代码 | Sonnet 3.5/4 |
| "添加单元测试" | Composer | Sonnet 3.5 |

### 2.2 Comparison with Other Agents

| Dimension | Claude Code | Cursor | Codex |
|-----------|-------------|--------|-------|
| Interface | CLI (Terminal) | IDE (Editor) | CLI (Terminal) |
| Feedback | Batch | Real-time | One-shot |
| Best For | Deep analysis | Interactive dev | Quick fixes |
| Tier | 2-3 | 1-2 | 0-1 |

---

## 3. Cursor-Specific Features

### 3.1 Chat Mode

**Best for**: Analysis, explanation, planning

**Usage**:
```
@codebase What's the architecture of the ad loading system?
@file:Sources/Core/BidLoader.swift Explain this class
@folder:Sources/Adapters How are adapters structured?
```

**When to use**:
- Understanding code
- Getting context
- Planning changes
- Asking questions

---

### 3.2 Inline Edit (Cmd+K)

**Best for**: Quick, localized changes (Tier 0-1)

**Usage**:
1. Select code → Cmd+K
2. Describe change
3. Review diff
4. Accept or iterate

**Examples**:
- "Add nil check"
- "Refactor to guard let"
- "Extract to private method"

---

### 3.3 Composer Mode

**Best for**: Multi-file changes (Tier 1-2)

**Usage**:
1. Open Composer
2. Describe task
3. Add context with @file
4. Review proposed changes
5. Apply selectively

**Examples**:
- "Add logging to all network calls"
- "Implement caching layer"
- "Add unit tests for BidLoader"

---

## 4. Output Protocol

### 4.1 Chat Response

```markdown
## Analysis
[Understanding of the question/task]

## Answer / Solution
[Direct answer or proposed solution]

## Files Involved
- `path/to/file1.swift` - [role in solution]
- `path/to/file2.swift` - [role in solution]

## Next Steps (if applicable)
1. [Action 1]
2. [Action 2]
```

### 4.2 Composer Output

```markdown
## Plan
[What will be changed and why]

## Files to Create/Modify
1. `path/to/file1.swift`
   - [Change description]
   - Risk: Low/Medium/High

2. `path/to/file2.swift`
   - [Change description]
   - Risk: Low/Medium/High

## Verification
$ [how to verify the changes work]
Expected: [expected result]

## Notes
[Any important considerations]
```

---

## 5. Escalation Rules

### 5.1 Escalate to Claude Code When:

- Task requires architectural decision
- Root cause analysis is complex
- Task involves public API changes
- Design document is needed
- Task spans >7 files
- Verification fails for unclear reason

**Example**:
```
⚠️ This task exceeds Cursor's scope

**Reason**: Requires architectural decision about adapter pattern extension

**Recommend**: Use Claude Code for analysis
$ claude
> Design architecture for new adapter with async initialization
> Review existing AdNetworkAdapter protocol
```

---

### 5.2 Delegate to Codex When:

- Simple, well-defined batch task
- No interactive feedback needed
- Pure mechanical operation

**Example**:
```
💡 This task is better suited for Codex CLI

$ codex "rename OldName to NewName in all files"
```

---

## 6. Integration with Other Agents

### 6.1 Receiving Handoff from Claude Code

When Claude Code completes planning:

```yaml
---
handoff:
  to: cursor
  task_id: "implement-caching-layer"

context:
  task_summary: "Implement caching layer for BidLoader"
  design: "See design doc in previous message"
  files_to_create:
    - path: "Sources/Core/MSPCore/CacheManager.swift"
      description: "Cache manager with LRU eviction"
  files_to_modify:
    - path: "Sources/Core/MSPCore/BidLoader.swift"
      changes: "Integrate CacheManager"
---
```

**Action in Cursor**:
1. Open Composer
2. Reference handoff context
3. Implement according to plan
4. Verify as specified

---

### 6.2 Handing Off to Codex

For simple sub-tasks:

```markdown
This sub-task is better for Codex:
$ codex "fix all shellcheck warnings in Scripts/"
```

---

## 7. Model Selection

### Default Model
```yaml
default: claude-3-5-sonnet
```

### Tier-Specific
| Tier | Model | When |
|------|-------|------|
| 0-1 | Sonnet 3.5 | Standard tasks |
| 2 | Sonnet 4 | Complex refactoring, bug analysis |

### Upgrade Triggers
- Multi-module changes
- Complex business logic
- Performance-critical code

---

## 8. Code Quality Standards

### 8.1 Follow Existing Patterns

✅ **Do**:
- Match existing code style
- Use same naming conventions
- Follow established patterns

❌ **Don't**:
- Introduce new patterns without justification
- Mix styles within a file
- Add unnecessary abstractions

---

### 8.2 Swift Best Practices

✅ **Do**:
- Use guard for early returns
- Prefer value types (struct) over reference types (class) when appropriate
- Use meaningful variable names
- Add documentation for public APIs

❌ **Don't**:
- Force unwrap (!) without justification
- Swallow errors silently
- Create retain cycles with strong references

---

### 8.3 Testing

✅ **Do**:
- Follow Quick/Nimble BDD style
- Test both success and failure cases
- Use descriptive test names (it("should ..."))
- Mock external dependencies

❌ **Don't**:
- Test implementation details
- Write flaky tests
- Skip edge cases

---

## 9. Constitutional Compliance

### Before Making Changes

Check applicable constitutions:

| File Location | Constitution |
|---------------|--------------|
| `Sources/**/*.swift` | Federal + Sources/constitution.md |
| `Scripts/**/*.sh` | Federal + Scripts/constitution.md |
| `Tests/**/*Spec.swift` | Federal + Tests/constitution.md |

### Key Articles

- **Article I.2**: Never modify .xcodeproj directly → use *.yml.template
- **Article I.3**: Podfile is SSOT for dependencies
- **Article II.1**: Changes must pass validation gates
- **Article III.1**: Core modules don't import third-party SDKs

---

## 10. Common Workflows

### Workflow A: Implement New Feature

1. **Understand**: Use Chat to understand existing architecture
   ```
   @codebase How does bid loading work?
   @file:Sources/Core/BidLoader.swift Explain this class
   ```

2. **Plan**: Outline approach in Chat
   ```
   I need to add caching. What's the best approach?
   ```

3. **Implement**: Use Composer for multi-file changes
   ```
   Add caching layer following the plan we discussed
   @file:Sources/Core/BidLoader.swift
   ```

4. **Test**: Add tests via Composer
   ```
   Add unit tests for the caching behavior
   ```

5. **Verify**: Run tests
   ```bash
   $ swift test --filter BidLoaderSpec
   ```

---

### Workflow B: Fix Bug

1. **Reproduce**: Understand the bug
   ```
   @file:Sources/Core/BidLoader.swift
   Why does this crash when bidResponse is nil?
   ```

2. **Analyze**: Get root cause
   ```
   Analyze the stack trace: [paste trace]
   ```

3. **Fix**: Apply fix with Inline Edit (Cmd+K)
   - Select problematic code
   - "Add nil check and error handling"

4. **Test**: Verify fix
   ```bash
   $ swift test
   ```

---

### Workflow C: Refactor

1. **Assess**: Understand current structure
   ```
   @folder:Sources/Adapters
   Explain the adapter pattern used here
   ```

2. **Plan**: Get refactoring strategy
   ```
   This code is duplicated across adapters. How should I refactor?
   ```

3. **Execute**: Use Composer for multi-file refactoring
   ```
   Extract common logic to BaseAdapter following the plan
   ```

4. **Verify**: Ensure no regressions
   ```bash
   $ swift test
   $ ./Scripts/target-switching/round-trip-test.sh
   ```

---

## 11. Limitations & Boundaries

### What Cursor CAN Do

✅ Interactive development (Tier 1-2)
✅ Code exploration and understanding
✅ Multi-file editing with context
✅ Real-time feedback and iteration
✅ Refactoring with immediate verification

### What Cursor CANNOT Do

❌ Deep architectural design (→ Claude Code + Opus)
❌ Complex root-cause analysis (→ Claude Code)
❌ Public API design (→ Claude Code)
❌ Large-scale batch operations (→ Codex CLI)
❌ Strategic planning (→ Claude Code + Opus)

---

## 12. Tips & Tricks

### Effective @mentions

```
@codebase [question]        - Search entire codebase
@file:path/to/file.swift    - Reference specific file
@folder:Sources/Adapters    - Reference directory
```

### Iterative Refinement

Don't aim for perfection on first try:
1. Get working solution
2. Iterate based on feedback
3. Refine until satisfactory

### Context Management

For complex tasks, build context incrementally:
```
# Step 1: Understand
@codebase How does X work?

# Step 2: Plan
Given that architecture, how should I implement Y?

# Step 3: Execute (Composer)
Implement Y following the plan
@file:[relevant files]
```

---

## 13. Quick Reference

### When to Use Cursor

- ✅ Interactive development
- ✅ Code exploration
- ✅ Iterative refinement
- ✅ Real-time feedback needed

### When to Use Claude Code

- Task needs deep analysis
- Architectural decisions required
- Public API changes
- >7 files involved

### When to Use Codex

- Mechanical batch operations
- Well-defined one-shot tasks
- No feedback loop needed

---

## End of Cursor IDE Operational Directives
