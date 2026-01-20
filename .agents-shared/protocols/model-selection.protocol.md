# Model Selection Protocol

> **Version**: 1.0
> **Last Updated**: 2026-01-14
> **Applies To**: All Agents

---

## 1. Overview

This protocol defines which AI model to use based on task tier, ensuring optimal balance of quality, speed, and cost.

---

## 2. Model Capability Tiers

### Tier S: Opus 4.5

```yaml
model_id: "claude-opus-4-5-20251101"
cost: "$$$$$"
pricing: "$15 / 1M input tokens, $75 / 1M output tokens"

strengths:
  - Deep reasoning and multi-step analysis
  - Complex architectural design
  - Long-form document writing
  - Creative problem solving
  - Trade-off evaluation

use_for:
  - Tier 3 tasks (Strategic)
  - Architectural design and review
  - Complex root-cause analysis
  - High-quality documentation
  - Task planning and decomposition

token_budget: "Unlimited (task quality is priority)"
```

---

### Tier A: Sonnet 4

```yaml
model_id: "claude-sonnet-4-20250514"
cost: "$$$"
pricing: "$3 / 1M input tokens, $15 / 1M output tokens"

strengths:
  - High-quality code generation
  - Balanced speed and quality
  - Medium-complexity analysis
  - Code review

use_for:
  - Tier 2 tasks (Complex) - Analysis phase
  - Code review and audit
  - Bug deep-dive analysis
  - Refactoring planning

token_budget: "Moderate (watch costs, but prioritize quality)"
```

---

### Tier B: Sonnet 3.5

```yaml
model_id: "claude-3-5-sonnet-20241022"
cost: "$$"
pricing: "$3 / 1M input tokens, $15 / 1M output tokens"

strengths:
  - Fast response time
  - Good code generation
  - Pattern-based tasks

use_for:
  - Tier 1 tasks (Standard)
  - Tier 2 tasks (Complex) - Execution phase
  - Unit test generation
  - Simple bug fixes
  - Code explanation

token_budget: "Normal"
```

---

### Tier C: Haiku 3.5

```yaml
model_id: "claude-3-5-haiku-20241022"
cost: "$"
pricing: "$0.25 / 1M input tokens, $1.25 / 1M output tokens"

strengths:
  - Extremely fast response
  - Lowest cost
  - Simple, well-defined tasks

use_for:
  - Tier 0 tasks (Trivial)
  - Code formatting
  - Simple renaming
  - Typo fixes
  - Quick queries

token_budget: "Generous (cost is minimal)"
```

---

## 3. Task Tier → Model Mapping

```
┌─────────┬─────────────────┬─────────────────┬─────────────────┬───────────────┐
│  Tier   │  Analysis Phase │ Execution Phase │  Review Phase   │ Cost Estimate │
├─────────┼─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ Tier 0  │ -               │ Haiku 3.5       │ -               │ $0.01/task    │
│ Trivial │                 │ (Codex)         │                 │               │
├─────────┼─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ Tier 1  │ Haiku 3.5       │ Sonnet 3.5      │ Haiku 3.5       │ $0.05-$0.20   │
│ Standard│ (optional)      │ (Codex/Cursor)  │ (optional)      │ /task         │
├─────────┼─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ Tier 2  │ Sonnet 4        │ Sonnet 3.5/4    │ Sonnet 4        │ $0.50-$2.00   │
│ Complex │ (Claude Code)   │ (Codex/Cursor)  │ (Claude Code)   │ /task         │
├─────────┼─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ Tier 3  │ Opus 4.5        │ Opus 4.5        │ Opus 4.5        │ $5.00-$20.00  │
│Strategic│ (Claude Code)   │ + Human         │ + Multi-person  │ /task         │
└─────────┴─────────────────┴─────────────────┴─────────────────┴───────────────┘
```

---

## 4. Agent-Specific Defaults

### Claude Code (CLI)

```yaml
default_model: "claude-sonnet-4"  # Conservative default
tier_overrides:
  tier_0: "haiku-3.5"    # Only if handling trivial tasks (rare)
  tier_1: "sonnet-3.5"
  tier_2: "sonnet-4"
  tier_3: "opus-4.5"     # MUST use Opus for strategic tasks
```

### Codex (CLI)

```yaml
default_model: "claude-3-5-sonnet"
tier_overrides:
  tier_0: "haiku-3.5"
  tier_1: "sonnet-3.5"
  tier_2: "sonnet-3.5"   # Execution only, analysis done by Claude Code
  tier_3: null           # Should not handle Tier 3
```

### Cursor (IDE)

```yaml
default_model: "claude-3-5-sonnet"
tier_overrides:
  tier_0: "sonnet-3.5"   # Rarely handles Tier 0 (use Codex instead)
  tier_1: "sonnet-3.5"
  tier_2: "sonnet-4"     # For complex tasks
  tier_3: null           # Should not handle Tier 3
```

---

## 5. Selection Decision Tree

```
                         ┌────────────────────┐
                         │  Classify Task Tier│
                         └──────────┬─────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
    ┌────▼────┐              ┌──────▼──────┐          ┌───────▼───────┐
    │ Tier 3  │              │   Tier 2    │          │   Tier 0-1    │
    │Strategic│              │   Complex   │          │ Trivial/Std   │
    └────┬────┘              └──────┬──────┘          └───────┬───────┘
         │                          │                         │
         ▼                          ▼                         │
   ┌──────────┐         ┌──────────────────┐                 │
   │  Opus    │         │  Analysis? → Yes  │                 │
   │  4.5     │         │  Execution? → No  │                 │
   └──────────┘         └──────────┬───────┘                 │
                                   │                         │
                        ┌──────────┴──────────┐              │
                        │                     │              │
                   Analysis              Execution           │
                        │                     │              │
                        ▼                     ▼              ▼
                 ┌──────────┐         ┌──────────┐   ┌──────────┐
                 │ Sonnet 4 │         │Sonnet 3.5│   │Haiku/    │
                 └──────────┘         │or        │   │Sonnet 3.5│
                                      │Sonnet 4  │   └──────────┘
                                      └──────────┘
```

---

## 6. Output Declaration

All agents MUST declare the model used in their output:

```yaml
---
task_tier: 2
model: claude-sonnet-4
agent: claude-code
timestamp: 2026-01-14T15:30:00Z
---
```

This enables:
- Cost tracking
- Quality auditing
- Model selection optimization

---

## 7. Override Rules

### When to Override Default Model Selection

#### Upgrade to Higher Model
```yaml
conditions:
  - Task is more complex than initially assessed
  - Lower model failed or produced poor results
  - Human explicitly requests higher quality

approval: optional (agent can decide)
```

#### Downgrade to Lower Model
```yaml
conditions:
  - Task is simpler than initially assessed
  - Budget constraints
  - Time-sensitive (need faster response)

approval: required (must justify)
```

### Example Override

```markdown
---
task_tier: 2
model: claude-opus-4-5  # Upgraded from default sonnet-4
model_override_reason: "Root cause analysis requires deeper reasoning than anticipated"
---
```

---

## 8. Cost Management

### Daily Cost Monitoring

Track cumulative costs by tier:

```
Tier 0: $0.50   (50 tasks × $0.01)
Tier 1: $5.00   (25 tasks × $0.20)
Tier 2: $15.00  (10 tasks × $1.50)
Tier 3: $40.00  (2 tasks × $20.00)
──────────────
Total:  $60.50
```

### Cost Optimization Strategies

1. **Batch Tier 0 tasks** → Use Codex CLI for multiple trivial tasks
2. **Reuse analysis** → If Tier 2 analysis is done, don't re-analyze
3. **Prefer Tier 1 over Tier 2** → Simplify problem if possible
4. **Cache common responses** → Template responses for frequent tasks

---

## 9. Governance

- **Authority**: Must align with `task-tier.protocol.md`
- **Cost Awareness**: Agents should prefer lower-cost models when quality permits
- **Quality First**: Never sacrifice quality to save cost on critical tasks (Tier 2-3)
