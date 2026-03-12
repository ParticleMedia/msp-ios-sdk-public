---
name: document-writer
description: Create comprehensive technical documentation with deep analysis and synthesis
category: strategic
quick_reference: "When: Architecture docs, ADRs, technical guides. Steps: Deep analysis of code/context → Synthesize findings → Structure with clear sections → Include diagrams/tables where helpful."
shared: true
applicable_agents: [claude-code, codex, cursor]
recommended_model: opus  # For complex reasoning - user may override
allowed-tools: [Read, Glob, Grep]
---

# Document Writer Skill

> **Type**: Strategic Skill
> **Exclusive**: Claude Code (Opus) only
> **Purpose**: Deep reasoning for comprehensive documentation synthesis

---

## Purpose

Create high-quality technical documentation that requires:
- Deep code analysis and understanding
- Synthesis across multiple modules
- Architectural insights
- Strategic recommendations
- Comprehensive coverage

**Task Tier**: Tier 3 (Strategic) - Requires deep reasoning and synthesis

---

## Scope

**Does**:
- Write architecture documentation
- Create onboarding guides
- Document complex systems
- Synthesize scattered knowledge
- Provide strategic insights
- Create decision records

**Does NOT**:
- Generate simple API docs (use doc comments in code)
- Create boilerplate README files
- Document individual functions (use inline comments)
- Generate changelog (automated)

---

## When to Use

Invoke this skill when:
- Creating/updating ARCHITECTURE.md
- Writing comprehensive onboarding documentation
- Documenting complex workflows
- Creating design decision records (ADRs)
- Synthesizing knowledge from multiple sources
- Explaining strategic rationale

**Quick Decision**:
- Simple docstring → Add inline comment
- API reference → Use DocC comments
- System documentation → Use document-writer.skill.md
- Process guide → Use document-writer.skill.md

---

## Document Types

### Type 1: Architecture Documentation

**Purpose**: Explain system structure, patterns, and design decisions

**Sections**:
1. **Overview**: High-level system description
2. **Module Structure**: How modules are organized
3. **Key Patterns**: Architectural patterns used
4. **Data Flow**: How data moves through system
5. **Extension Points**: How to extend the system
6. **Constraints**: Limitations and trade-offs

**Example**: `ARCHITECTURE.md`, `DESIGN.md`

---

### Type 2: Onboarding Guide

**Purpose**: Help new developers understand the codebase

**Sections**:
1. **Getting Started**: Setup and first steps
2. **Codebase Tour**: Key files and their purposes
3. **Common Tasks**: How to perform frequent operations
4. **Development Workflow**: Build, test, release process
5. **Troubleshooting**: Common issues and solutions
6. **Resources**: Where to find more information

**Example**: `ONBOARDING.md`, `CONTRIBUTING.md`

---

### Type 3: Workflow Documentation

**Purpose**: Explain multi-step processes

**Sections**:
1. **Overview**: What the workflow accomplishes
2. **Prerequisites**: What's needed before starting
3. **Step-by-Step**: Detailed instructions
4. **Validation**: How to verify success
5. **Troubleshooting**: Common failure points
6. **Examples**: Real-world scenarios

**Example**: `RELEASE.md`, `TESTING.md`

---

### Type 4: Design Decision Record (ADR)

**Purpose**: Document significant architectural decisions

**Sections**:
1. **Status**: Proposed, Accepted, Deprecated, Superseded
2. **Context**: What prompted this decision
3. **Decision**: What was decided
4. **Consequences**: Implications and trade-offs
5. **Alternatives Considered**: What wasn't chosen and why

**Example**: `docs/adr/0001-use-xcframeworks.md`

---

### Type 5: System Analysis

**Purpose**: Deep-dive analysis of complex subsystems

**Sections**:
1. **Purpose**: What the system does
2. **Components**: Key parts and their roles
3. **Interactions**: How components communicate
4. **State Management**: How state is handled
5. **Error Handling**: How failures are managed
6. **Performance**: Characteristics and optimizations
7. **Future Directions**: Planned improvements

**Example**: `docs/analysis/ad-loading-system.md`

---

## Execution Steps

### Step 1: Define Scope and Audience

**Questions to Answer**:
- Who is this documentation for?
  - New developers?
  - Experienced team members?
  - External contributors?
  - Stakeholders?
- What should they learn?
- What level of detail is appropriate?

---

### Step 2: Gather Context

**Read Foundational Documents**:
```bash
cat constitution.md
cat ARCHITECTURE.md
cat AGENTS.md
cat README.md
```

**Survey Codebase**:
```bash
# List modules
ls -R Sources/

# Find key files
find Sources/ -name "*.swift" | head -20

# Search for patterns
grep -r "class.*Manager" Sources/
grep -r "protocol.*Delegate" Sources/
```

**Read Related Documentation**:
```bash
ls docs/
cat docs/relevant-doc.md
```

---

### Step 3: Analyze and Synthesize

**For Architecture Docs**:
1. Map module boundaries
2. Identify key patterns
3. Trace data flows
4. Document extension points

**For Workflow Docs**:
1. Execute the workflow manually
2. Note each step and decision point
3. Identify failure modes
4. Collect troubleshooting tips

**For ADRs**:
1. Understand the problem context
2. Review alternatives considered
3. Analyze trade-offs
4. Document rationale

---

### Step 4: Structure Content

**Use Clear Hierarchy**:
- H1: Document title
- H2: Major sections
- H3: Subsections
- H4: Details

**Employ Visual Aids**:
- Tables for comparisons
- Code blocks for examples
- Diagrams (mermaid) for flows
- Callouts for important notes

---

### Step 5: Write with Clarity

**Best Practices**:
- **Be Concise**: Respect reader's time
- **Be Precise**: Use exact terms
- **Be Consistent**: Use same terminology throughout
- **Be Complete**: Cover all necessary information
- **Be Actionable**: Provide concrete examples

**Avoid**:
- Vague language ("sometimes", "usually")
- Assumed knowledge (link to prerequisites)
- Outdated information (mark with dates)
- Redundancy (link instead of repeating)

---

### Step 6: Add Examples

**Types of Examples**:
1. **Code Snippets**: Show actual usage
2. **Command-Line Examples**: Show exact commands
3. **Scenarios**: Walk through real-world cases
4. **Anti-Patterns**: Show what NOT to do

---

### Step 7: Review and Refine

**Self-Review Checklist**:
- [ ] Accurate (all facts correct)
- [ ] Complete (covers all necessary topics)
- [ ] Clear (easy to understand)
- [ ] Well-structured (logical flow)
- [ ] Actionable (reader can apply knowledge)
- [ ] Maintainable (easy to update)

---

## Output Format

### For Architecture Documentation

```markdown
# [System Name] Architecture

> **Version**: 1.0
> **Last Updated**: [Date]
> **Author**: [Agent/Human]

---

## Overview

[High-level description of the system, its purpose, and key characteristics]

---

## System Structure

### Module Organization

| Module | Purpose | Dependencies |
|--------|---------|-------------|
| MSPCore | Core bidding logic | Foundation |
| MSPiOSSDK | Public API | MSPCore, UIKit |

### Directory Layout

```
Sources/
├── Core/
│   └── MSPCore/          # Core business logic
├── SDK/
│   └── MSPiOSSDK/        # Public SDK interface
└── Adapters/
    └── MSPNovaAdapter/   # Ad network adapters
```

---

## Key Architectural Patterns

### Pattern 1: [Pattern Name]

**Purpose**: [Why this pattern is used]

**Implementation**:
```swift
// Code example showing the pattern
```

**Benefits**:
- [Benefit 1]
- [Benefit 2]

**Trade-offs**:
- [Trade-off 1]

---

## Data Flow

```mermaid
graph LR
    A[App] --> B[MSPiOSSDK]
    B --> C[MSPCore]
    C --> D[Adapter]
    D --> E[Ad Network]
```

**Description**: [Explain the flow step by step]

---

## Extension Points

### Adding a New Adapter

1. Create new module in `Sources/Adapters/MSP{Name}Adapter/`
2. Implement `AdapterProtocol`
3. Register in adapter factory
4. Add tests in `Tests/MSP{Name}AdapterTests/`

**Example**: See `MSPNovaAdapter` implementation

---

## Constraints and Trade-offs

### Constraint 1: No Third-Party SDKs in Core

**Rationale**: [Constitutional Article III.1]
**Implication**: All third-party integrations go in adapters
**Trade-off**: More code, but better isolation

---

## Future Directions

- [ ] Planned improvement 1
- [ ] Planned improvement 2

---

## References

- [constitution.md](../constitution.md) - Project constitution
- [ADR-0001](./adr/0001-example.md) - Related decision record
```

---

### For Design Decision Records (ADR)

```markdown
# ADR-[Number]: [Title]

**Status**: [Proposed | Accepted | Deprecated | Superseded by ADR-XXX]
**Date**: [YYYY-MM-DD]
**Deciders**: [List of people involved]

---

## Context

[Describe the situation and problem that prompted this decision]

### Background

[Provide necessary technical context]

### Requirements

- [Requirement 1]
- [Requirement 2]

---

## Decision

[State the decision clearly and unambiguously]

We will [decision statement].

---

## Rationale

[Explain why this decision was made]

### Factors Considered

1. **Factor 1**: [Analysis]
2. **Factor 2**: [Analysis]

### Key Insights

- [Insight 1]
- [Insight 2]

---

## Consequences

### Positive

- ✅ [Benefit 1]
- ✅ [Benefit 2]

### Negative

- ❌ [Trade-off 1]
- ❌ [Trade-off 2]

### Neutral

- ℹ️ [Consequence 1]

---

## Alternatives Considered

### Alternative 1: [Name]

**Description**: [What this alternative involved]

**Pros**:
- [Pro 1]

**Cons**:
- [Con 1]

**Rejected because**: [Reason]

### Alternative 2: [Name]

[Similar structure]

---

## Implementation

[How this decision will be implemented]

### Phase 1: [Name]
- [ ] Task 1
- [ ] Task 2

### Phase 2: [Name]
- [ ] Task 3

---

## Validation

[How we'll verify this decision was correct]

**Success Criteria**:
- [Criterion 1]
- [Criterion 2]

**Metrics**:
- [Metric 1]: [Target]

---

## References

- [Link to related discussion]
- [Link to related code]
- [Link to related ADR]
```

---

## Example Usage

### Create Architecture Documentation

```bash
$ claude
> Write comprehensive architecture documentation for the adapter system

[Document-writer skill activated]
[Analyzes all adapter modules]
[Synthesizes patterns and design decisions]
[Produces ARCHITECTURE-ADAPTERS.md]
```

### Create Design Decision Record

```bash
$ claude
> Document the decision to use XCFrameworks over static libraries

[Document-writer skill activated]
[Gathers context from git history, discussions]
[Analyzes alternatives]
[Produces ADR-0001-use-xcframeworks.md]
```

---

## Best Practices

### For All Documentation

1. **Date Everything**: Include "Last Updated" dates
2. **Version It**: Track documentation versions
3. **Link Liberally**: Connect related documents
4. **Show Examples**: Concrete beats abstract
5. **Keep It Fresh**: Update when code changes

### For Architecture Docs

1. **Start High-Level**: Overview before details
2. **Use Diagrams**: Visual aids aid understanding
3. **Explain Why**: Don't just describe what
4. **Document Constraints**: Explain limitations
5. **Point to Code**: Link to actual implementations

### For ADRs

1. **Be Objective**: Present facts, not opinions
2. **Show Alternatives**: Prove you considered options
3. **Quantify Trade-offs**: Use data where possible
4. **Make It Searchable**: Use consistent naming
5. **Update Status**: Mark superseded/deprecated ADRs

---

## Tips for Deep Analysis

1. **Read Widely**: Survey entire codebase before writing
2. **Trace Execution**: Follow code paths to understand flow
3. **Identify Patterns**: Look for recurring structures
4. **Question Assumptions**: Ask "why" repeatedly
5. **Validate Understanding**: Test your mental model

---

## Constitutional Compliance

Documentation should:
- **Reflect Constitution**: Cite constitutional articles where relevant
- **Maintain SSOT**: Don't duplicate information, link to source of truth
- **Follow Conventions**: Use established terminology and structure

---

## Related Skills

- `architect.skill.md`: For designing what to document
- `planner.skill.md`: For planning documentation effort
- `constitutional-auditor.skill.md`: Verify docs cite constitution correctly
