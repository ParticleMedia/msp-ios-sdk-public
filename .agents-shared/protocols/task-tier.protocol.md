# Task Tier Classification Protocol

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: All Agents

---

## 1. Overview

This protocol defines how to classify tasks into tiers, which determines:
- Which agent should handle the task
- Which model to use
- Required output format
- Human review requirements

---

## 2. Classification Dimensions

| Dimension | Weight | Description |
|-----------|--------|-------------|
| **Impact Scope** | High | Locality → Module → Cross-module → Global |
| **Risk Level** | High | Reversible → Fixable → Irreversible |
| **API Surface** | High | None → Internal → Public/Open |
| **Core Module** | Medium | Not involved → Read-only → Write |
| **Complexity** | Medium | Mechanical → Pattern-based → Analytical → Creative |
| **Precedent** | Low | Clear precedent → Adaptable → Novel |

---

## 3. Tier Definitions

### Tier 0: Trivial

**Criteria**:
- Impact: Single function/file
- Risk: Immediately reversible
- API: Not involved
- Core: Not involved
- Complexity: Mechanical (no logic change)
- Precedent: Clear examples exist

**Examples**:
- Fix typo in README.md
- Update version number in Podfile
- Add/remove comments
- Code formatting (swift-format, shellcheck fixes)

**Configuration**:
```yaml
tier: 0
agent: codex
recommended_model: haiku-3.5  # User may override
human_review: optional
cost_estimate: "$0.01 / task"
```

**Output Format**:
```
✓ [one-line summary]
File: path/to/file.swift:L42
```

---

### Tier 1: Standard

**Criteria**:
- Impact: Within one module (1-3 files)
- Risk: Low (test coverage, easily reversible)
- API: None or internal only
- Core: Not involved
- Complexity: Clear pattern to follow
- Precedent: Similar implementations exist

**Examples**:
- Add unit test using template
- Implement defined interface/protocol
- Fix bug with clear stack trace
- Batch rename (e.g., NovaAdapter → MSPNovaAdapter)
- Apply PR feedback (specific, well-defined changes)

**Configuration**:
```yaml
tier: 1
agent: codex | cursor
recommended_model: sonnet-3.5  # User may override
human_review: recommended
cost_estimate: "$0.05 - $0.20 / task"
```

**Output Format**:
```markdown
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
| path/to/file2.swift | L45 | [description] |

## Verification
$ [command to verify, e.g., swift test --filter TargetSpec]
```

---

### Tier 2: Complex

**Criteria**:
- Impact: Cross-module (3-7 files)
- Risk: Medium (requires thorough testing)
- API: May adjust internal APIs
- Core: May involve (read/analyze, possibly modify)
- Complexity: Requires analysis and judgment
- Precedent: Similar cases but needs adaptation

**Examples**:
- Fix complex bug (root cause unclear)
- Performance optimization
- Multi-module refactoring
- New adapter (following existing pattern)
- CI/CD script failure diagnosis
- Release script enhancement

**Configuration**:
```yaml
tier: 2
agent:
  analysis: claude-code
  execution: codex | cursor
recommended_model:  # User may override
  analysis: sonnet-4
  execution: sonnet-3.5 | sonnet-4
human_review: required
cost_estimate: "$0.50 - $2.00 / task"
```

**Output Format**:
```markdown
---
task_tier: 2
model: claude-sonnet-4
agent: claude-code
---

## Analysis
[Problem analysis and root cause investigation]

## Plan
1. [Step 1]
2. [Step 2]
...

## Changes
| File | Change | Risk |
|------|--------|------|
| path/to/file.swift | [description] | Low/Medium/High |

## Verification
$ [verification command]
Expected: [expected result]

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| ... | ... | ... |

## Constitutional Compliance
- Article X.Y: [how this change complies]
```

---

### Tier 3: Strategic

**Criteria**:
- Impact: Global (>7 files or core modules)
- Risk: High (potentially irreversible)
- API: Involves public/open API changes
- Core: Modifies Core modules (Sources/Core/, msp-release.sh, etc.)
- Complexity: Requires architectural design + trade-offs
- Precedent: No precedent or needs innovation

**Examples**:
- New core module design
- Public API changes (breaking or non-breaking)
- Major dependency upgrade (e.g., Swift 6, Xcode 16)
- Release process redesign
- constitution.md modification
- ARCHITECTURE.md major update

**Configuration**:
```yaml
tier: 3
agent: claude-code
recommended_model: opus-4.5  # For strategic reasoning - user may override
human_review: required + multi-person
cost_estimate: "$5.00 - $20.00 / task"
```

**Output Format**:
```markdown
---
task_tier: 3
model: claude-opus-4-5
agent: claude-code
---

## Design Document

### 1. Context & Problem Statement
[Background and problem definition]

### 2. Goals & Non-Goals
**Goals:**
- [Goal 1]
- [Goal 2]

**Non-Goals:**
- [What this does NOT address]

### 3. Proposed Solution
[High-level solution description]

### 4. Alternatives Considered
| Alternative | Pros | Cons | Rejected Reason |
|-------------|------|------|-----------------|
| ... | ... | ... | ... |

### 5. Detailed Design
[Detailed design with API contracts, data flow, module interaction]

### 6. Implementation Plan
| Phase | Tasks | Agent | Model | Est. Effort |
|-------|-------|-------|-------|-------------|
| 1 | ... | ... | ... | ... |

### 7. Verification Plan
- [ ] [Verification item 1]
- [ ] [Verification item 2]

### 8. Risks & Open Questions
**Risks:**
- [Risk 1]: [Mitigation]

**Open Questions:**
- [Question 1]

### 9. Constitutional Compliance
[Detailed analysis of compliance with relevant articles]
```

---

## 4. Quick Classification Flowchart

```
START
  │
  ├─► Involves public API or constitution? ─► YES ─► Tier 3
  │                                          │
  │                                          NO
  │                                          │
  ├─► Involves Sources/Core/ or core scripts (msp-release.sh)? ─► YES ─► Tier 2 (minimum)
  │                                                                │
  │                                                                NO
  │                                                                │
  ├─► Requires root cause analysis or architectural decision? ─► YES ─► Tier 2
  │                                                              │
  │                                                              NO
  │                                                              │
  ├─► Changes >3 files or involves cross-module logic? ─► YES ─► Tier 1 or 2 (assess complexity)
  │                                                        │
  │                                                        NO
  │                                                        │
  ├─► Has logic changes (not just text/formatting)? ─► YES ─► Tier 1
  │                                                    │
  │                                                    NO
  │                                                    │
  └─► Tier 0 (Trivial)
```

---

## 5. Edge Cases & Disambiguation

### Case: "Add logging to existing function"
- **If**: Simple, one-line addition → Tier 0-1
- **If**: Requires designing logging strategy → Tier 2

### Case: "Rename variable X to Y"
- **If**: Local variable, single file → Tier 0
- **If**: Public API, affects consumers → Tier 3

### Case: "Fix failing test"
- **If**: Test has wrong expected value → Tier 0
- **If**: Code logic is wrong, unclear why → Tier 2

### Case: "Upgrade dependency"
- **If**: Patch version (1.2.3 → 1.2.4) → Tier 0-1
- **If**: Minor version with breaking changes → Tier 2
- **If**: Major version → Tier 3

---

## 6. Governance

- **Authority**: This protocol must align with `constitution.md`
- **Updates**: Require human approval
- **Enforcement**: All agents must classify tasks before execution
