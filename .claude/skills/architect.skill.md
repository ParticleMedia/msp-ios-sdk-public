---
name: architect
description: A skill for designing major architectural decisions and feature implementations. Produces mini-design documents with API contracts, module responsibilities, and constitutional compliance.
category: strategic
shared: true
applicable_agents: [claude-code, codex, cursor]
recommended_model: opus  # For complex reasoning - user may override
allowed-tools: [Read, Glob]
---
# Architect Skill

> **Type**: Strategic Skill
> **Exclusive**: Claude Code (Opus) only
> **Purpose**: Deep architectural reasoning and design

## Purpose
Guide major architectural decisions and feature design by producing structured design documents that comply with the project's constitution.

## Scope
- **Does**: Design APIs, define module responsibilities, propose code skeletons
- **Does NOT**: Implement code (design only)

## When to Use
Invoke this skill when asked to:
- "Design" a new feature
- "Architect" a system component
- "Plan" a major refactoring

## Execution Steps

### Step 1: Context Gathering
1. Read `ARCHITECTURE.md` to understand current system structure
2. Read relevant `*.yml.template` files for module configuration
3. Identify affected modules and their boundaries

### Step 2: Constitutional Review
Load applicable constitution files:
- `constitution.md` (root)
- `Sources/constitution.md` (for Swift code)
- `Scripts/constitution.md` (for automation)

Identify which articles apply to the proposed design.

### Step 3: Design Proposal
Produce a mini-design document containing:

1. **Problem Statement**: What problem does this solve?
2. **API Contract**: Public interfaces and protocols
3. **Module Responsibilities**: Which modules own which functionality
4. **Code Skeleton**: Protocol definitions and class stubs
5. **Constitutional Compliance**: How design adheres to each applicable article

### Step 4: Implementation Plan
Provide ordered implementation steps with validation checkpoints.

## Output Format
```
## Design Document: [Feature Name]

### Problem Statement
[Brief description of the problem being solved]

### Affected Modules
| Module | Responsibility | Changes Required |
|--------|---------------|------------------|
| MSPCore | [responsibility] | [changes] |

### API Contract

```swift
/// DocC documentation
public protocol FeatureProtocol {
    func method() -> Result
}
```

### Module Responsibilities
- **Module A**: Owns X, Y, Z
- **Module B**: Consumes A, provides W

### Constitutional Compliance
| Article | Requirement | How Design Complies |
|---------|------------|---------------------|
| III.1 | No third-party imports in Core | Uses protocol abstraction |
| IV.3 | No force unwraps | All optionals safely unwrapped |

### Code Skeleton
```swift
// Minimal implementation skeleton
```

### Implementation Plan
1. [ ] Step 1 with validation
2. [ ] Step 2 with validation
3. [ ] Final integration test
```

## Example
When asked to "Design a caching layer for ad responses":
1. Review ARCHITECTURE.md for current data flow
2. Check Article III for modularity requirements
3. Propose `AdCacheProtocol` in Core, `AdCacheImpl` in implementation layer
4. Ensure no third-party cache library imported in Core
