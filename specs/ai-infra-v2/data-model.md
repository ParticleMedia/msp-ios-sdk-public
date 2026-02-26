# Data Model: AI Infrastructure v2

**Branch**: `ai-infra-v2` | **Date**: 2026-02-22 | **Plan**: [plan.md](./plan.md)

## Entity Definitions

### 1. ContextEntry

A single knowledge document stored in `.context/`. Represents a playbook, experience record, or technical reference.

```yaml
# Frontmatter (YAML in Markdown files)
---
id: ctx-testing-001
title: "Unit Test Best Practices (Quick/Nimble)"
domain: testing          # release | ci | integration | compatibility | testing | sources | architecture
layer: tech              # business | experience | tech
tags:
  - unit-test
  - quick
  - nimble
  - mock
  - stub
  - tdd
  - bdd
triggers:                 # Keywords that cause an agent to load this entry
  - "unit test"
  - "Quick"
  - "Nimble"
  - "test double"
  - "mock"
  - "stub"
summary: "Quick/Nimble unit testing patterns with Meszaros test double taxonomy for Swift 5.0"
version: "1.0"
status: active            # active | archived | draft
created: "2026-02-22"
updated: "2026-02-22"
---
```

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | yes | Unique identifier: `ctx-{domain}-{NNN}[-slug]` |
| title | string | yes | Human-readable title |
| domain | enum | yes | One of: release, ci, integration, compatibility, testing, sources, architecture |
| layer | enum | yes | One of: business, experience, tech |
| tags | string[] | yes | Searchable keywords (lowercase, hyphenated) |
| triggers | string[] | yes | Natural language phrases that trigger loading |
| summary | string | yes | One-line description (max 120 chars) |
| version | string | yes | Semantic version of this entry |
| status | enum | yes | One of: active, archived, draft |
| created | date | yes | ISO 8601 date |
| updated | date | yes | ISO 8601 date |

**Validation Rules**:
- `id` must be unique across all entries
- `id` must match pattern: `ctx-{domain}-{NNN}` or `ctx-{domain}-{NNN}-{slug}`
- `tags` must contain at least 2 items
- `triggers` must contain at least 1 item
- `summary` must be ≤ 120 characters

---

### 2. ContextIndex

Machine-readable catalog at `.context/index.json`. Auto-generated from all ContextEntry frontmatter.

```json
{
  "version": "2.0",
  "generated_at": "2026-02-22T10:30:00Z",
  "generator": "Scripts/tools/generate-context-index.py",
  "entry_count": 17,
  "domains": {
    "release": { "count": 3, "layers": ["experience"] },
    "ci": { "count": 4, "layers": ["experience"] },
    "integration": { "count": 2, "layers": ["experience"] },
    "testing": { "count": 3, "layers": ["tech"] },
    "sources": { "count": 4, "layers": ["tech"] },
    "compatibility": { "count": 0, "layers": [] },
    "architecture": { "count": 0, "layers": [] }
  },
  "entries": [
    {
      "id": "ctx-testing-001",
      "path": ".context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md",
      "title": "Unit Test Best Practices (Quick/Nimble)",
      "domain": "testing",
      "layer": "tech",
      "tags": ["unit-test", "quick", "nimble", "mock", "stub", "tdd", "bdd"],
      "triggers": ["unit test", "Quick", "Nimble", "test double", "mock", "stub"],
      "summary": "Quick/Nimble unit testing patterns with Meszaros test double taxonomy for Swift 5.0",
      "status": "active",
      "updated": "2026-02-22"
    }
  ]
}
```

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| version | string | yes | Schema version (semver) |
| generated_at | ISO 8601 | yes | Timestamp of last generation |
| generator | string | yes | Path to generation script |
| entry_count | integer | yes | Total number of entries |
| domains | object | yes | Domain summary with counts and layers |
| entries | ContextEntry[] | yes | Array of entry metadata (no full content) |

**Invariant**: Must always reflect the true filesystem state (Article X.2). Any CRUD operation on `.context/` entries triggers regeneration.

---

### 3. TestCaseDefinition

A YAML-defined specification of what should be tested. Stored in `packages/test-cases/{domain}/{Module}.yaml`.

```yaml
# packages/test-cases/debug/DebugAdLoad.yaml
module: DebugAdLoad
prefix: DAL
description: "Test cases for DebugAdLoadViewModel"
created: "2026-01-15"
updated: "2026-02-22"

cases:
  # --- Behavior tests (BDD-style) ---
  - id: DAL001
    type: behavior
    description: "Shows loading state when fetching ads"
    priority: high
    tags: [loading-state, ui-feedback]
    given: "The view model is initialized with a mock repository"
    when: "requestAds() is called"
    then: "isLoading should be true"
    doubles:
      repository:
        type: mock          # dummy | stub | spy | mock | fake
        class: MockLoadAdRepository
        reason: "Need to verify requestAds was called AND return preset data"

  # --- Unit tests (class/method-level) ---
  - id: DAL002
    type: unit
    description: "Maps repository response to section view models"
    priority: high
    tags: [data-mapping, view-model]
    class: DebugAdLoadViewModel
    method: "mapSections(_:)"
    doubles:
      repository:
        type: stub
        class: MockLoadAdRepository
        reason: "Only need preset return data, no call verification"

  # --- Regression tests ---
  - id: DAL016
    type: behavior
    description: "Handles empty placement list without crash"
    priority: critical
    tags: [regression, edge-case, crash-prevention]
    regression_for: "fix/empty-placements-crash"
    given: "Repository returns empty placements array"
    when: "viewDidLoad triggers data fetch"
    then: "ViewModel should set sections to empty array without crash"
    doubles:
      repository:
        type: stub
        class: MockPlacementsRepository
        reason: "Preset empty array return"
```

**Fields (module-level)**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| module | string | yes | Module name (must be substring of Swift test filename) |
| prefix | string | yes | 2-4 uppercase letter prefix, registered in `_prefixes.yaml` |
| description | string | yes | What this module tests |
| created | date | yes | When first created |
| updated | date | yes | Last modification date |
| cases | TestCase[] | yes | Array of test case definitions |

**Fields (case-level)**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | yes | Unique ID: `{PREFIX}{NNN}` (3-digit zero-padded) |
| type | enum | yes | `unit` or `behavior` |
| description | string | yes | What this test verifies |
| priority | enum | no | `critical`, `high`, `medium`, `low` (default: `medium`) |
| tags | string[] | no | Categorization tags |
| regression_for | string | no | Branch name or ticket ID of the bugfix this test guards |
| given | string | behavior only | Precondition (BDD) |
| when | string | behavior only | Action (BDD) |
| then | string | behavior only | Expected outcome (BDD) |
| class | string | unit only | Class under test |
| method | string | unit only | Method under test |
| doubles | object | no | Map of dependency → test double specification |

**Test Double specification (within `doubles`)**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | enum | yes | `dummy`, `stub`, `spy`, `mock`, `fake` |
| class | string | yes | Swift class name of the test double |
| reason | string | no | Why this double type was chosen (AI guidance) |

**Validation Rules**:
- `id` must be unique across ALL YAML files (not just this file)
- `id` prefix must match the file's `prefix` field
- `prefix` must be registered in `_prefixes.yaml`
- Behavior tests must have `given`, `when`, `then`
- Unit tests must have `class`, `method`
- `doubles.type` must be one of the 5 Meszaros types

---

### 4. TestDouble (Swift File)

Test-time substitute for a production dependency. Named according to Meszaros taxonomy.

**Naming Convention**:

| Meszaros Type | File Naming | When to Use |
|---------------|-------------|-------------|
| Dummy | `Dummy{Dependency}.swift` | Fills parameter lists; never called; throws if invoked |
| Stub | `Stub{Dependency}.swift` | Returns preset data; no call verification |
| Spy | `Spy{Dependency}.swift` | Records calls for post-execution assertion |
| Mock | `Mock{Dependency}.swift` | Pre-programmed expectations + behavior verification; **also used for Stub+Spy hybrids** |
| Fake | `Fake{Dependency}.swift` | Working implementation with shortcuts (e.g., in-memory store, value-type conformances) |

**Project Convention**: `Mock{Xxx}` is retained for Stub+Spy hybrids (common in Quick/Nimble tests) where both preset returns AND call recording are needed. This must be documented in each Mock file's header comment.

**State Transitions** (refactoring map from current → target):

| Current Name | Current Behavior | Target Name | Target Type | Action |
|-------------|-----------------|-------------|-------------|--------|
| MockDebugSection | Value-type conformance | FakeDebugSection | Fake | Rename + restructure |
| MockDebugOption | Value-type conformance | FakeDebugOption | Fake | Rename + restructure |
| MockDebugSectionsRepository | Stub returns + call recording | MockDebugSectionsRepository | Mock (hybrid) | Keep name, add documentation |
| MockLoadAdRepository | Stub returns + call recording | MockLoadAdRepository | Mock (hybrid) | Keep name, add documentation |
| MockPlacementsRepository | Stub returns + call recording | MockPlacementsRepository | Mock (hybrid) | Keep name, add documentation |
| (inline) MockAdNetworkAdapter | Unused parameter filler | DummyAdNetworkAdapter | Dummy | Extract to file |

---

### 5. MockDataFixture

JSON response snapshots stored in `packages/mock-data/{module}/{scenario}.json`.

```
packages/mock-data/
├── debug/
│   ├── bid_response_success.json
│   ├── bid_response_error.json
│   └── ad_config.json
├── core/
│   └── (future)
└── README.md
```

**Naming Convention**: `{module}/{scenario}.json`
- `module`: lowercase module name matching source directory
- `scenario`: descriptive name using underscores: `{action}_{outcome}[_{variant}]`
  - Examples: `bid_response_success`, `bid_response_error`, `bid_response_timeout`, `ad_config_empty`

---

### 6. Playbook

AI-readable operating manual stored in `.context/{domain}/tech/ctx-{domain}-{NNN}-{slug}.md`.

**7 Playbook Instances**:

| # | ID | Title | Domain | File |
|---|-----|-------|--------|------|
| 1 | ctx-sources-001 | Swift Best Practices | sources | `.context/sources/tech/ctx-sources-001-swift-best-practices.md` |
| 2 | ctx-sources-002 | UIKit Best Practices | sources | `.context/sources/tech/ctx-sources-002-uikit-best-practices.md` |
| 3 | ctx-testing-001 | Unit Test (Quick/Nimble) | testing | `.context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md` |
| 4 | ctx-testing-002 | BDD Best Practices | testing | `.context/testing/tech/ctx-testing-002-bdd-best-practices.md` |
| 5 | ctx-testing-003 | Bugfix Regression Workflow | testing | `.context/testing/tech/ctx-testing-003-bugfix-regression.md` |
| 6 | ctx-sources-003 | MVVM-Repo Best Practices | sources | `.context/sources/tech/ctx-sources-003-mvvm-repo.md` |
| 7 | ctx-sources-004 | Script Best Practices | sources | `.context/sources/tech/ctx-sources-004-script-best-practices.md` |

**Required Sections per Playbook**:

```markdown
---
# [frontmatter - ContextEntry format]
---

# {Title} Playbook

## Scope & Applicability
When to use this playbook, target Swift/iOS versions, prerequisites.

## Decision Trees
Flowchart-style guidance for common ambiguous choices.

## Patterns & Examples
Correct approaches with file-pointer references to real codebase.

## Anti-Patterns
Wrong approaches with explanations of why they fail.

## AI Common Mistakes
≥3 specific anti-patterns AI agents frequently produce, each with:
- ❌ Wrong code example
- ✅ Right code example
- Why AI gets this wrong

## References
Links to constitutional articles, related playbooks, external resources.
```

---

### 7. Package

A centralized resource directory within `packages/`.

**Two instances**:

| Package | Path | Contents | Schema |
|---------|------|----------|--------|
| test-cases | `packages/test-cases/` | YAML test case definitions | `_schema.yaml` |
| mock-data | `packages/mock-data/` | JSON fixture files | `README.md` (conventions) |

**Shared Structure**:
- `README.md` — Usage guide
- `_schema.yaml` or `_schema.md` — Schema/convention definition
- Domain subdirectories — Content organized by module

---

## Entity Relationships

```
ContextIndex ──1:N──> ContextEntry (index references all entries)
     │
     └── includes ──> Playbook (playbooks ARE context entries with layer=tech)

TestCaseDefinition ──1:1──> Swift Test Implementation (via ID marker)
     │
     └── references ──> TestDouble (via doubles.class field)

MockDataFixture ──N:1──> FixtureLoader (loaded by Tests/Shared/FixtureLoader.swift)

Package ──1:N──> TestCaseDefinition (test-cases package)
Package ──1:N──> MockDataFixture (mock-data package)
```
