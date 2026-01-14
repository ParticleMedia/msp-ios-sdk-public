# Output Format Protocol

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: All Agents

---

## 1. Overview

This protocol defines standard output formats for each task tier, ensuring:
- Consistency across agents
- Machine-parseable metadata
- Clear communication to humans
- Adequate detail for verification

---

## 2. Universal Header Format

All outputs (except Tier 0) MUST begin with a YAML frontmatter block:

```yaml
---
task_tier: [0|1|2|3]
model: [model-id]
agent: [agent-name]
timestamp: [ISO8601]
---
```

**Example**:
```yaml
---
task_tier: 2
model: claude-sonnet-4
agent: claude-code
timestamp: 2026-01-14T15:30:00Z
---
```

---

## 3. Tier-Specific Formats

### Tier 0: Trivial

**Format**: Single line (no frontmatter needed)

```
✓ [one-line summary]
File: path/to/file.swift:L42
```

**Example**:
```
✓ Fixed typo "recieve" → "receive" in README.md
File: README.md:L15
```

**Rationale**: Tier 0 tasks are mechanical and self-explanatory. Minimal output reduces noise.

---

### Tier 1: Standard

**Format**: Frontmatter + Summary + Changes + Verification

```markdown
---
task_tier: 1
model: claude-3-5-sonnet
agent: codex
---

## Summary
[One sentence description of what was done]

## Changes
| File | Line/Section | Change |
|------|--------------|--------|
| path/to/file1.swift | L10-L20 | [Brief description] |
| path/to/file2.swift | L45 | [Brief description] |

## Verification
$ [command to verify the change]
Expected: [expected result]
```

**Example**:
```markdown
---
task_tier: 1
model: claude-3-5-sonnet
agent: codex
---

## Summary
Added unit test for BidLoader class using Quick/Nimble template

## Changes
| File | Line/Section | Change |
|------|--------------|--------|
| Tests/MSPCoreTests/BidLoaderSpec.swift | (new file) | Created test file with 3 test cases |

## Verification
$ swift test --filter BidLoaderSpec
Expected: All tests pass (3/3)
```

---

### Tier 2: Complex

**Format**: Frontmatter + Analysis + Plan + Changes + Verification + Risks + Constitutional Compliance

```markdown
---
task_tier: 2
model: claude-sonnet-4
agent: claude-code
---

## Analysis
[Problem analysis, root cause, and approach reasoning]

## Plan
1. [Step 1]
2. [Step 2]
...

## Changes
| File | Change | Risk Level |
|------|--------|------------|
| path/to/file | [description] | Low/Medium/High |

## Verification
$ [verification command]
Expected: [expected result]

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk description] | High/Medium/Low | [How to mitigate] |

## Constitutional Compliance
- Article X.Y: [How this complies with the article]
```

**Example**:
```markdown
---
task_tier: 2
model: claude-sonnet-4
agent: claude-code
---

## Analysis
The release script fails at the MSPNovaAdapter podspec generation step because the zip file is missing from GitHub Release. Root cause: MSPNovaAdapter-1.0.0-rc.23.zip was never uploaded during the build phase.

## Plan
1. Verify Build/XCFrameworks/MSPNovaAdapter.xcframework exists
2. Package MSPNovaAdapter + NovaCore into zip
3. Upload zip to GitHub Release
4. Retry resume process

## Changes
| File | Change | Risk Level |
|------|--------|------------|
| Scripts/release/publish/pods/publish.sh | Fix create_zip_from_xcframework for MSPNovaAdapter | Medium |

## Verification
$ gh release view 1.0.0-rc.23 --json assets
Expected: MSPNovaAdapter-1.0.0-rc.23.zip appears in asset list

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Zip structure incorrect | High (podspec validation fails) | Follow existing MSPGoogleAdapter pattern |
| NovaCore.xcframework missing | High (build fails) | Pre-check existence before packaging |

## Constitutional Compliance
- Article I.4: Script-based fix (not manual upload)
- Article II.1: Verification command ensures correctness
```

---

### Tier 3: Strategic

**Format**: Full Design Document

```markdown
---
task_tier: 3
model: claude-opus-4-5
agent: claude-code
---

## Design Document: [Title]

### 1. Context & Problem Statement
[Background, motivation, and problem definition]

### 2. Goals & Non-Goals

**Goals:**
- [Goal 1]
- [Goal 2]

**Non-Goals:**
- [What this intentionally does NOT address]

### 3. Proposed Solution
[High-level solution description]

### 4. Alternatives Considered

| Alternative | Pros | Cons | Rejected Reason |
|-------------|------|------|-----------------|
| [Option A] | [Pros] | [Cons] | [Why not chosen] |

### 5. Detailed Design

#### 5.1 API Design
[Public APIs, contracts, interfaces]

#### 5.2 Data Flow
[How data flows through the system]

#### 5.3 Module Interaction
[How components interact]

### 6. Implementation Plan

| Phase | Tasks | Agent | Model | Dependencies |
|-------|-------|-------|-------|--------------|
| 1 | [Task list] | [Agent] | [Model] | [Dependencies] |

### 7. Verification Plan
- [ ] [Verification item 1]
- [ ] [Verification item 2]

### 8. Risks & Open Questions

**Risks:**
- [Risk 1]: [Mitigation strategy]

**Open Questions:**
- [Question 1]

### 9. Constitutional Compliance
[Detailed analysis of compliance with all relevant articles]

### 10. Appendices (if needed)
- [Diagrams, code samples, references]
```

---

## 4. Special Formats

### Handoff Format

When handing off to another agent:

```yaml
---
handoff:
  type: downward | upward | lateral
  from: [agent-name]
  to: [agent-name]
  timestamp: [ISO8601]

context:
  task_summary: "..."
  decisions: [...]
  files: [...]
  constraints: [...]

verification:
  commands: [...]
  success_criteria: [...]
---
```

See `handoff.protocol.md` for full specification.

---

### Escalation Format

When escalating to a higher-tier agent:

```yaml
---
escalation:
  from: [agent-name]
  to: [agent-name]
  reason: [architecture|public_api|complexity|unclear]
  timestamp: [ISO8601]

context:
  original_task: "..."
  blocker: "..."
  work_completed: [...]

questions: [...]
---
```

See `escalation.protocol.md` for full specification.

---

## 5. Markdown Best Practices

### Code Blocks
Always specify language for syntax highlighting:
```swift
// Good
```

### Tables
Use tables for structured data:
```markdown
| Column 1 | Column 2 |
|----------|----------|
| Data | Data |
```

### Lists
- Use `-` for unordered lists
- Use `1.` for ordered lists
- Use `- [ ]` for task lists

### Emphasis
- **Bold** for important terms
- *Italic* for emphasis
- `code` for file paths, commands, code elements

---

## 6. Verification Section Requirements

The Verification section MUST include:

1. **Command(s)**: Exact command to run
   ```bash
   $ swift test --filter TargetSpec
   $ ./Scripts/target-switching/round-trip-test.sh
   ```

2. **Expected Result**: What success looks like
   ```
   Expected: All tests pass (15/15), no new warnings
   ```

3. **(Optional) Failure Handling**: What to do if verification fails
   ```
   If fails: Check logs at /tmp/round-trip-test.log
   ```

---

## 7. Constitutional Compliance Section

For Tier 2-3 tasks, MUST cite relevant constitutional articles:

**Format**:
```markdown
## Constitutional Compliance
- Article I.2: Not modifying .xcodeproj directly (using *.yml.template)
- Article IV.1: Added comprehensive unit tests
- Sources/Article IV.2: Public API documented with Swift DocC
```

---

## 8. Forbidden Patterns

### ❌ Don't: Vague descriptions
```markdown
## Changes
- Fixed some stuff
- Updated files
```

### ✅ Do: Specific descriptions
```markdown
## Changes
| File | Change |
|------|--------|
| BidLoader.swift:L42 | Fixed null pointer check for bidResponse |
| BidLoaderSpec.swift | Added test for nil bidResponse case |
```

---

### ❌ Don't: Missing verification
```markdown
## Changes
[...changes...]

[End of output]
```

### ✅ Do: Always include verification
```markdown
## Changes
[...changes...]

## Verification
$ swift test --filter BidLoaderSpec
Expected: 3/3 tests pass
```

---

## 9. Output Size Guidelines

| Tier | Max Length | Rationale |
|------|------------|-----------|
| Tier 0 | 1-2 lines | Trivial, self-explanatory |
| Tier 1 | 15-30 lines | Standard, straightforward |
| Tier 2 | 50-100 lines | Complex, needs detail |
| Tier 3 | 200-500 lines | Strategic, comprehensive |

If exceeding guidelines, consider breaking into multiple tasks or creating separate documents.

---

## 10. Governance

- **Enforcement**: Automated checks can validate frontmatter format
- **Updates**: Protocol changes require cross-agent testing
- **Compliance**: All agents must follow these formats
