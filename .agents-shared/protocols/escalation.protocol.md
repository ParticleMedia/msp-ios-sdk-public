# Escalation Protocol

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: All Agents

---

## 1. Overview

This protocol defines when and how an agent should escalate a task to a higher-capability agent or human.

**Key Principle**: Escalate early when you hit your limits. Don't waste time on tasks beyond your scope.

---

## 2. Escalation Triggers

### Automatic Escalation (MUST escalate)

| Trigger | From | To | Reason |
|---------|------|-----|--------|
| **Public/Open API change** | Any | Claude Code (Opus) | Per AGENTS.md Rule E-1 |
| **Constitution modification** | Any | Human | Read-only for all agents |
| **SSOT modification without SOP** | Any | Human | Per AGENTS.md Rule E-2 |
| **Large diff (>150 lines, >5 files, or Core/)** | Any | Claude Code | Per AGENTS.md Rule E-3 |
| **Repeated failure (2× same error)** | Any | Claude Code or Human | Per AGENTS.md Rule E-4 |
| **Dependency major version change** | Any | Human | Per AGENTS.md Rule E-5 |

### Recommended Escalation (SHOULD escalate)

| Trigger | From | To | Reason |
|---------|------|-----|--------|
| **Root cause unclear** | Codex/Cursor | Claude Code (Sonnet 4) | Needs deeper analysis |
| **Multiple valid approaches** | Codex/Cursor | Claude Code (Opus) | Needs human/architect decision |
| **Task exceeds initial tier** | Any | Higher-tier agent | Complexity misjudged |
| **Architectural decision needed** | Codex/Cursor | Claude Code (Opus) | Beyond tactical scope |
| **Verification fails (unclear why)** | Codex/Cursor | Claude Code | Needs debugging |
| **Scope creep detected** | Any | Human | Requirements changed |

### Optional Escalation (MAY escalate)

| Trigger | From | To | Reason |
|---------|------|-----|--------|
| **Task too time-consuming** | Codex/Cursor | Claude Code | Consider different approach |
| **Better suited for IDE** | Codex | Cursor | Interactive development needed |
| **Better suited for CLI batch** | Cursor | Codex | Batch operation |

---

## 3. Escalation Format

### 3.1 Basic Escalation

```yaml
---
escalation:
  type: upward
  from: codex
  to: claude-code
  timestamp: 2026-01-14T15:30:00Z
  trigger: root_cause_unclear

context:
  original_task: "[original user instruction]"
  work_completed:
    - "[action 1]"
    - "[action 2]"
  work_remaining:
    - "[what couldn't be done]"

blocker:
  type: complexity | architecture | public_api | unclear_requirement
  description: "[detailed description of what blocked progress]"

files_touched:
  - "path/to/file.swift"

questions:
  - "[question 1 for higher-tier agent]"
  - "[question 2]"
---
```

### 3.2 With Artifacts

```yaml
---
escalation:
  type: upward
  from: cursor
  to: claude-code
  timestamp: 2026-01-14T15:30:00Z
  trigger: verification_failed

context:
  original_task: "Implement caching layer for BidLoader"
  work_completed:
    - "Created CacheManager class"
    - "Integrated into BidLoader"
  work_remaining:
    - "Tests fail for unknown reason"

blocker:
  type: complexity
  description: "Tests pass individually but fail when run together. Suspect race condition but can't identify where."

artifacts:
  - type: partial_implementation
    path: "Sources/Core/MSPCore/CacheManager.swift"
  - type: test_output
    content: |
      Test Case 'BidLoaderSpec.test_caching_stores_result' passed (0.023 seconds)
      Test Case 'BidLoaderSpec.test_caching_retrieves_result' failed (0.045 seconds)
        Expected <success>, got <failure>
  - type: error_log
    path: "/tmp/test-output.log"

files_touched:
  - "Sources/Core/MSPCore/CacheManager.swift"
  - "Sources/Core/MSPCore/BidLoader.swift"
  - "Tests/MSPCoreTests/BidLoaderSpec.swift"

questions:
  - "Is there a known threading issue with BidLoader?"
  - "Should caching be synchronous or async?"

suggested_approach: "Add mutex lock to CacheManager, but not sure if that's the right pattern for this codebase"
---
```

---

## 4. Escalation Paths

### Path A: Codex → Claude Code

```
Codex (Tier 0-1)
    │
    │ Triggers:
    │ • Root cause unclear
    │ • Architecture decision needed
    │ • Task exceeds Tier 1
    │
    ▼
Claude Code (Tier 2-3)
```

**Example**:
```markdown
⚠️ ESCALATION RECOMMENDED

**From**: Codex
**To**: Claude Code (Sonnet 4)

**Original Task**: "Fix the test failure in BidLoaderSpec"

**Issue**: Test failure root cause is unclear. Stack trace points to BidLoader.swift:L42 but the code looks correct.

**To Continue in Claude Code**:
```bash
$ claude
> Analyze test failure in BidLoaderSpec
> Context: @file:Tests/MSPCoreTests/BidLoaderSpec.swift
> Stack trace: [paste stack trace]
```

**Files to Review**:
- Sources/Core/MSPCore/BidLoader.swift
- Tests/MSPCoreTests/BidLoaderSpec.swift
```

---

### Path B: Cursor → Claude Code

```
Cursor (Tier 1-2)
    │
    │ Triggers:
    │ • Complexity exceeds IDE interaction
    │ • Need deep analysis or planning
    │ • Scope grew beyond initial estimate
    │
    ▼
Claude Code (Tier 2-3)
```

**Example**:
```markdown
⚠️ ESCALATION RECOMMENDED

**From**: Cursor
**To**: Claude Code (Opus)

**Original Task**: "Implement new adapter following existing pattern"

**Issue**: During implementation, realized the new adapter requires a different architecture pattern than existing adapters due to unique SDK constraints.

**Architectural Decision Needed**:
1. Should we extend the existing AdNetworkAdapter protocol?
2. Or create a new protocol for this class of adapters?

**Context**:
- Existing pattern: MSPGoogleAdapter, MSPFacebookAdapter
- New requirements: Async initialization, lifecycle callbacks

**To Continue in Claude Code**:
```bash
$ claude
> Design architecture for [NewAdapter] given unique constraints
> Review existing AdNetworkAdapter protocol
> Propose: extend vs. new protocol
```
```

---

### Path C: Any Agent → Human

```
Any Agent
    │
    │ Triggers:
    │ • Public API change
    │ • Constitution modification
    │ • Repeated failures
    │ • Major version upgrade
    │
    ▼
Human Review & Decision
```

**Example**:
```markdown
⚠️ HUMAN APPROVAL REQUIRED

**Agent**: Claude Code (Opus)
**Trigger**: Public API Change (AGENTS.md Rule E-1)

**Proposed Change**:
Add new public method to `BidLoader`:
```swift
public func loadBidWithCallback(_ callback: @escaping (Result<Bid, Error>) -> Void)
```

**Rationale**:
Current synchronous API blocks the main thread for network-heavy operations. New async API improves performance.

**Impact**:
- Breaking change: No (additive only)
- Consumers: Will need to adopt new API for async behavior
- Migration: Provide migration guide

**Request**:
Please review and approve public API addition.
```

---

## 5. Response to Escalation

### For Receiving Agent

When you receive an escalation:

1. ✅ **Acknowledge**: Confirm you received and understand the escalation
2. ✅ **Review context**: Read all provided files, artifacts, and questions
3. ✅ **Analyze deeply**: Don't just repeat what the previous agent tried
4. ✅ **Provide clear guidance**: Either solve it or escalate further with new insights

**Good Response**:
```markdown
## Escalation Response

**Received From**: Codex
**Analyzed By**: Claude Code (Sonnet 4)

## Root Cause Analysis
[Detailed analysis of the problem]

## Solution
[Concrete solution with implementation steps]

## Handoff Back to Codex (if applicable)
[Specific instructions for completion]
```

---

## 6. Anti-Patterns

### ❌ Don't: Escalate Too Quickly

```markdown
# BAD
❌ "This seems complicated, escalating to Claude Code"
```

Try to solve it first. Escalate only when truly stuck.

---

### ❌ Don't: Escalate Without Context

```markdown
# BAD
❌ "Task failed, escalating"
```

Provide detailed context, artifacts, and specific questions.

---

### ❌ Don't: Escalate Trivial Issues

```markdown
# BAD
❌ "I got a shellcheck warning, escalating to Claude Code"
```

Fix shellcheck warnings yourself (Tier 0-1).

---

### ✅ Do: Escalate Strategically

```markdown
# GOOD
✅ "Attempted 3 approaches to fix race condition (mutex, serial queue, actor pattern).
   All tests still fail intermittently. Need architectural review of threading model.
   Escalating to Claude Code (Sonnet 4) with detailed context."
```

---

## 7. Escalation Metrics

Track escalations to identify patterns:

```yaml
escalation_metrics:
  week_of: 2026-01-14

  by_trigger:
    root_cause_unclear: 5
    architecture_needed: 3
    public_api_change: 2
    repeated_failure: 1

  by_path:
    codex_to_claude: 7
    cursor_to_claude: 3
    agent_to_human: 1

  resolution:
    resolved_by_claude: 9
    required_human: 2
```

Use metrics to:
- Identify agent capability gaps
- Refine task tier classification
- Improve documentation

---

## 8. Governance

- **Mandatory**: Follow escalation triggers in Section 2.1
- **Judgment**: Use best judgment for Section 2.2
- **Authority**: AGENTS.md Section 6 has precedence
