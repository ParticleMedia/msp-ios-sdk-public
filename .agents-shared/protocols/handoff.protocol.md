# Agent Handoff Protocol

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: All Agents

---

## 1. Overview

This protocol defines how agents hand off tasks to each other, ensuring:
- Context is fully preserved
- Expectations are crystal clear
- Verification criteria are defined
- Return conditions are specified

---

## 2. Handoff Types

### 2.1 Downward Handoff (Planning → Execution)

**Direction**: Claude Code → Codex/Cursor

**When**: After analysis/planning is complete, delegate execution to tactical agent.

**Format**:
```yaml
---
handoff:
  type: downward
  from: claude-code
  to: codex | cursor
  timestamp: 2026-01-14T15:30:00Z

context:
  task_id: "task-2026-01-14-001"
  task_summary: "[what needs to be done]"
  tier: 2

  # Decisions already made (DO NOT revisit)
  decisions:
    - decision: "[architectural decision 1]"
      rationale: "[why this approach]"
    - decision: "[design decision 2]"
      rationale: "[reasoning]"

  # Specific changes to make
  files:
    - path: "Sources/Core/MSPCore/BidLoader.swift"
      action: "modify"
      changes: |
        Line 42: Replace `if response == nil` with `guard let response = response else`
        Line 45-50: Add error logging
    - path: "Tests/MSPCoreTests/BidLoaderSpec.swift"
      action: "create"
      template: "Tests/templates/unit_test_spec.swift.template"
      content: "[specific test cases]"

  # Constraints to respect
  constraints:
    - "Maintain Swift 5.9 compatibility"
    - "Follow existing error handling pattern"
    - "No public API changes"

verification:
  commands:
    - "swift test --filter BidLoaderSpec"
    - "./Scripts/target-switching/round-trip-test.sh"
  success_criteria:
    - "All tests pass"
    - "No new compiler warnings"
    - "Round-trip test succeeds"

return_to_claude_if:
  - "Tests fail for unclear reason"
  - "Discover architectural issue"
  - "Scope expands beyond plan"
  - "Need to modify public API"
---
```

**Example**:
```yaml
---
handoff:
  type: downward
  from: claude-code
  to: codex
  timestamp: 2026-01-14T15:30:00Z

context:
  task_id: "fix-nova-adapter-rename"
  task_summary: "Rename remaining NovaAdapter references to MSPNovaAdapter"
  tier: 1

  decisions:
    - decision: "Use MSPNovaAdapter consistently across all files"
      rationale: "Aligns with module naming convention established in commit 15ebe1812"

  files:
    - path: "Scripts/release/publish/pods/publish.sh"
      action: "modify"
      changes: |
        Line 229: is_binary_distribution case statement
        Line 2318: create_zip_from_xcframework comment
        Line 2987: publish_pod_with_resume comment
        Line 4639: release_adapters default list
        Line 4658: release_adapters pre-check
        Line 5316: main function default list

verification:
  commands:
    - "grep -r 'NovaAdapter' Scripts/ | grep -v MSPNovaAdapter"
  success_criteria:
    - "No remaining NovaAdapter references (expect 0 matches)"

return_to_claude_if:
  - "Find additional references beyond listed files"
---
```

---

### 2.2 Upward Escalation (Execution → Planning)

**Direction**: Codex/Cursor → Claude Code

**When**: Hit a blocker that requires deeper analysis or architectural decision.

**Format**:
```yaml
---
escalation:
  type: upward
  from: codex | cursor
  to: claude-code
  timestamp: 2026-01-14T15:30:00Z
  trigger: [architecture|complexity|public_api|unclear]

context:
  original_task: "[original instruction]"
  handoff_received: [task_id if handed off]

  work_completed:
    - "[completed action 1]"
    - "[completed action 2]"

  work_remaining:
    - "[blocked action 1]"
    - "[blocked action 2]"

blocker:
  type: architecture | complexity | public_api | unclear_requirement
  description: "[detailed description]"
  attempted_solutions:
    - approach: "[what was tried]"
      result: "[outcome]"
      reason_failed: "[why it didn't work]"

files_touched:
  - "path/to/file.swift"

artifacts:
  - type: partial_implementation | test_output | error_log
    path: "[path or inline content]"

questions:
  - "[question 1]"
  - "[question 2]"

suggested_approach: "[if any ideas]"
---
```

See `escalation.protocol.md` for full specification.

---

### 2.3 Lateral Handoff (Peer → Peer)

**Direction**: Cursor ↔ Codex

**When**: Delegate a sub-task better suited to the other agent.

**Format**:
```yaml
---
handoff:
  type: lateral
  from: cursor | codex
  to: codex | cursor
  timestamp: 2026-01-14T15:30:00Z
  reason: "[why the other agent is better suited]"

context:
  parent_task: "[main task context]"
  sub_task: "[specific sub-task to delegate]"

execution:
  command: "[exact command for CLI agent]"
  or_action: "[description for IDE agent]"

return_when: complete | blocked
---
```

**Example**:
```yaml
---
handoff:
  type: lateral
  from: cursor
  to: codex
  reason: "Batch rename better suited for CLI"

context:
  parent_task: "Refactor authentication module"
  sub_task: "Rename all oldAuthMethod to newAuthMethod across codebase"

execution:
  command: "codex \"rename oldAuthMethod to newAuthMethod in Sources/\""

return_when: complete
---
```

---

## 3. Handoff Best Practices

### 3.1 For Sender (Handing Off)

✅ **Do**:
- Make all architectural decisions before handoff
- Provide specific file paths and line numbers
- Define clear verification criteria
- List conditions for return/escalation

❌ **Don't**:
- Hand off with ambiguous requirements
- Skip verification criteria
- Assume receiver knows unstated context

---

### 3.2 For Receiver (Receiving)

✅ **Do**:
- Read and understand all context
- Follow the plan exactly as specified
- Run verification commands
- Return/escalate if blockers arise

❌ **Don't**:
- Make architectural decisions (return to sender)
- Skip verification steps
- Deviate from plan without escalation

---

## 4. Verification Protocol

### 4.1 Mandatory Verification Steps

Every handoff must include verification:

```yaml
verification:
  # Commands to run
  commands:
    - "[command 1]"
    - "[command 2]"

  # What success looks like
  success_criteria:
    - "[criterion 1]"
    - "[criterion 2]"

  # What to do if verification fails
  failure_handling:
    - escalate_to: claude-code
      reason: "Verification fails for unclear reason"
```

### 4.2 Common Verification Commands

| Task Type | Verification Command |
|-----------|---------------------|
| Unit test | `swift test --filter [TestSpec]` |
| Script | `shellcheck [script.sh]` |
| Build | `xcodebuild build -scheme MSPiOSSDK` |
| Integration | `./Scripts/target-switching/round-trip-test.sh` |

---

## 5. Complete Handoff Example

### Scenario: Fix Complex Bug

```markdown
## Analysis Phase (Claude Code)

---
task_tier: 2
model: claude-sonnet-4
agent: claude-code
---

## Root Cause Analysis
BidLoader crashes when bidResponse is nil due to missing guard clause.

## Solution
Add guard clause and error handling.

---

## Handoff to Codex

---
handoff:
  type: downward
  from: claude-code
  to: codex
  timestamp: 2026-01-14T15:45:00Z

context:
  task_id: "fix-bidloader-crash-2026-01-14"
  task_summary: "Add nil check for bidResponse in BidLoader"
  tier: 2

  decisions:
    - decision: "Use guard let pattern instead of if let"
      rationale: "Early return pattern is clearer and prevents nesting"
    - decision: "Log error before returning"
      rationale: "Helps debugging in production"

  files:
    - path: "Sources/Core/MSPCore/BidLoader.swift"
      action: "modify"
      changes: |
        Line 42-45: Replace:
          if bidResponse == nil {
            return nil
          }
        With:
          guard let response = bidResponse else {
            logger.error("BidLoader: Received nil bidResponse")
            return nil
          }

    - path: "Tests/MSPCoreTests/BidLoaderSpec.swift"
      action: "modify"
      changes: |
        Add new test case in describe("loadBid"):
          context("when bidResponse is nil") {
            it("should return nil and log error") {
              let result = bidLoader.loadBid(with: nilResponse)
              expect(result).to(beNil())
              // Verify error was logged
            }
          }

  constraints:
    - "Maintain existing error handling pattern"
    - "Use existing logger instance (don't create new one)"

verification:
  commands:
    - "swift test --filter BidLoaderSpec"
  success_criteria:
    - "All existing tests still pass"
    - "New test passes"
    - "No new warnings"

return_to_claude_if:
  - "Tests fail for reason other than test implementation"
  - "Discover other nil cases that need handling"
---
```

---

### Execution Phase (Codex)

```markdown
---
task_tier: 2
model: claude-3-5-sonnet
agent: codex
handoff_received: fix-bidloader-crash-2026-01-14
---

## Execution Summary
Applied changes as specified in handoff.

## Changes Made
| File | Change |
|------|--------|
| Sources/Core/MSPCore/BidLoader.swift:L42-L46 | Added guard let with error logging |
| Tests/MSPCoreTests/BidLoaderSpec.swift:L78-L85 | Added nil bidResponse test case |

## Verification
$ swift test --filter BidLoaderSpec
✓ All tests passed (12/12)
✓ No new warnings

## Status
☑️ Task complete
→ Returning to Claude Code for review
```

---

## 6. Handoff State Machine

```
┌─────────────────────────────────────────────────────┐
│                  Task Lifecycle                     │
└─────────────────────────────────────────────────────┘

  START
    │
    ▼
┌─────────┐
│ Analysis│  (Claude Code)
│ Phase   │
└────┬────┘
     │
     │ Handoff (if execution needed)
     ▼
┌─────────┐
│Execution│  (Codex/Cursor)
│ Phase   │
└────┬────┘
     │
     ├─► Success ─► Return to Claude Code (optional review)
     │
     ├─► Blocker ─► Escalate to Claude Code
     │
     └─► Scope Change ─► Return to Claude Code for re-planning
```

---

## 7. Handoff Checklist

### Before Handing Off (Sender)

- [ ] All architectural decisions made
- [ ] Files and changes specified
- [ ] Verification criteria defined
- [ ] Return conditions listed
- [ ] Constraints documented

### After Receiving (Receiver)

- [ ] Understood all context
- [ ] Reviewed all files mentioned
- [ ] Noted all constraints
- [ ] Identified verification commands

### Before Returning (Receiver)

- [ ] All changes implemented as specified
- [ ] Verification commands run successfully
- [ ] No deviations from plan (or escalated if needed)

---

## 8. Anti-Patterns

### ❌ Incomplete Handoff

```yaml
# BAD - Missing critical details
handoff:
  to: codex
  task: "Fix the bug"
```

### ✅ Complete Handoff

```yaml
# GOOD - All details provided
handoff:
  to: codex
  context:
    task_summary: "Add nil check in BidLoader.swift:L42"
    decisions: [...]
    files: [...]
    verification: [...]
```

---

### ❌ Vague Verification

```yaml
# BAD
verification:
  commands:
    - "test it"
  success_criteria:
    - "it works"
```

### ✅ Specific Verification

```yaml
# GOOD
verification:
  commands:
    - "swift test --filter BidLoaderSpec"
  success_criteria:
    - "All 12 tests pass"
    - "No new compiler warnings"
```

---

## 9. Governance

- **Mandatory**: Use handoff format for all agent-to-agent task transfers
- **Context**: Must preserve all context across handoffs
- **Verification**: Never skip verification steps
