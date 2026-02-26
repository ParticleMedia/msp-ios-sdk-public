# Quickstart Guide: AI Infrastructure v2

**Branch**: `ai-infra-v2` | **Date**: 2026-02-22 | **Plan**: [plan.md](./plan.md)

## Implementation Order

This feature has 5 workstreams that should be implemented in dependency order:

```
[WS1] Progressive Loading Foundation
  ↓
[WS2] Packages & YAML Migration ←── [WS3] Test Doubles Refactoring
  ↓
[WS4] Playbooks (7)
  ↓
[WS5] Multi-Agent Sync & Validation
```

## WS1: Progressive Loading Foundation

**Goal**: Establish the 3-tier loading architecture and machine-readable index.

### Step 1: Create `generate-context-index.py`

```bash
# Scripts/tools/generate-context-index.py
# Parses all .context/**/*.md frontmatter → .context/index.json
# Uses: Python (pyyaml for frontmatter extraction, json for assembly, jsonschema for validation)
```

**Input**: All `.context/{domain}/{layer}/ctx-*.md` files with YAML frontmatter
**Output**: `.context/index.json` per [context-index-schema.json](./contracts/context-index-schema.json)

### Step 2: Add frontmatter to ALL existing context entries

All 10 existing entries in `.context/` need YAML frontmatter added. Example for existing entries:

```markdown
---
id: ctx-release-001
title: "Pod 发布后使用方启动 crash - FB SDK 静态链接冲突"
domain: release
layer: experience
tags: [facebook, static-linking, xcframework, crash]
triggers: ["pod publish crash", "Facebook SDK", "static linking"]
summary: "FB SDK 静态链接冲突导致使用方启动 crash"
version: "1.0"
status: active
created: "2026-01-29"
updated: "2026-01-29"
---
```

### Step 3: Rewrite agent entry points

**CLAUDE.md** (target: <60 lines):
```markdown
# Claude Code Directives
> Version: 5.0

## Role: Strategic Technical Advisor

## Imports
@../constitution.md
@../AGENTS.md

## Directory-Triggered Context
- Sources/ → load Sources/AGENTS-SOURCES.md
- Scripts/ → load Scripts/AGENTS-SCRIPTS.md
- Tests/ → load Tests/constitution.md

## On-Demand Context
Use `.context/index.json` to discover playbooks by keyword.

## Skills
See `.claude/skills/` (progressive loading built-in).
```

**AGENTS-SOURCES.md** (target: ~20 lines):
```markdown
# Sources Loading Guide
When working in Sources/, load these playbooks from .context/index.json:
- ctx-sources-001: Swift Best Practices
- ctx-sources-002: UIKit Best Practices
- ctx-sources-003: MVVM-Repo Best Practices
- ctx-testing-001: Unit Test (Quick/Nimble) [when writing tests]
- ctx-testing-002: BDD Best Practices [when writing tests]
```

### Step 4: Verify index generation

```bash
python Scripts/tools/generate-context-index.py
# Verify: .context/index.json exists and matches schema
python -c "
import json
idx = json.load(open('.context/index.json'))
assert idx['entry_count'] == len(idx['entries'])
print(f'Index OK: {idx[\"entry_count\"]} entries')
"
```

---

## WS2: Packages & YAML Migration

**Goal**: Create `packages/` directory and migrate test cases from JSON to YAML.

### Step 1: Create package structure

```bash
mkdir -p packages/test-cases/debug
mkdir -p packages/mock-data/debug
```

### Step 2: Write migration script

```python
# Scripts/tools/migrate-test-cases.py
# Reads: Tests/TestCases/*.json
# Writes: packages/test-cases/{domain}/{Module}.yaml
# Preserves: all IDs, types, metadata
# Adds: YAML comments, doubles field template, regression_for field
```

### Step 3: Migrate existing JSON test cases

```bash
python Scripts/tools/migrate-test-cases.py
# Verify:
python Scripts/tools/test-cases.py validate  # updated to support YAML
```

### Step 4: Consolidate mock data

```bash
# Move Tests/Fixtures/* → packages/mock-data/debug/
# (Tests/Stubs/ does not exist — only Tests/Fixtures/ needs migration)
# Update FixtureLoader.swift paths
```

### Step 5: Update test-cases.py for YAML

Update `Scripts/tools/test-cases.py` to:
- Read YAML files from `packages/test-cases/`
- Validate against `contracts/test-case-schema.yaml`
- Support `doubles` field validation
- Support `regression_for` field
- Generate regression coverage report

---

## WS3: Test Doubles Refactoring

**Goal**: Rename and restructure test doubles per Meszaros taxonomy.

### Refactoring Steps (one file at a time, tests must pass after each):

1. `MockDebugSection` → `FakeDebugSection` (rename + restructure as proper Fake)
2. `MockDebugOption` → `FakeDebugOption` (rename + restructure as proper Fake)
3. Add documentation headers to Mock hybrids (MockDebugSectionsRepository, etc.)
4. Extract inline `MockAdNetworkAdapter` from spec files → `DummyAdNetworkAdapter.swift`
5. Update all spec file imports and references
6. Run tests: `./Scripts/target-switching/round-trip-test.sh`

### Validation

```bash
# After each rename:
# 1. Build
xcodebuild build-for-testing -workspace MSP.xcworkspace -scheme MSPCoreTests

# 2. Test
xcodebuild test -workspace MSP.xcworkspace -scheme MSPCoreTests

# 3. Full round-trip
./Scripts/target-switching/round-trip-test.sh
```

---

## WS4: Playbooks (7)

**Goal**: Write 7 AI-first playbooks in `.context/{domain}/tech/`.

### Writing Order (dependency-based):

1. **ctx-sources-001** Swift Best Practices — foundation for all Swift playbooks
2. **ctx-sources-002** UIKit Best Practices — depends on Swift playbook
3. **ctx-testing-001** Unit Test (Quick/Nimble) — depends on Swift, replaces archived ctx-testing-001-test-doubles
4. **ctx-testing-002** BDD Best Practices — depends on Unit Test playbook
5. **ctx-sources-003** MVVM-Repo — depends on Swift + UIKit + Unit Test
6. **ctx-testing-003** Bugfix Regression — depends on Unit Test + BDD
7. **ctx-sources-004** Script Best Practices — independent, can be parallel

### Template for each playbook:

```markdown
---
id: ctx-{domain}-{NNN}
title: "{Title}"
domain: {domain}
layer: tech
tags: [...]
triggers: [...]
summary: "{one-line}"
version: "1.0"
status: active
created: "2026-02-22"
updated: "2026-02-22"
---

# {Title} Playbook

## Scope & Applicability
## Decision Trees
## Patterns & Examples
## Anti-Patterns
## AI Common Mistakes (≥3 items, each with ❌/✅ code examples)
## References
```

### After each playbook:

```bash
# Regenerate index
python Scripts/tools/generate-context-index.py
# Verify
python -c "import json; idx=json.load(open('.context/index.json')); print(f'{idx[\"entry_count\"]} entries')"
```

---

## WS5: Multi-Agent Sync & Validation

**Goal**: Ensure all three agents reference the same content.

### Step 1: Create `validate-agent-sync.sh`

```bash
# Scripts/tools/validate-agent-sync.sh
# Checks:
# 1. All playbook IDs referenced in AGENTS-*.md exist in index.json
# 2. CLAUDE.md, CODEX.md, CURSOR.md are under 60 lines
# 3. No content duplication between AGENTS files and playbooks
# 4. All three agents reference the same shared content
```

### Step 2: Update Codex and Cursor configs

- `.codex/CODEX.md` → reference `.context/index.json`
- `.codex/instructions.md` → condensed loading guide
- `.cursor/CURSOR.md` → reference `.context/index.json`
- `.cursor/settings/rules.json` → glob-based triggers for playbooks

### Step 3: Archive old files

```bash
mkdir -p .context/archive
mv .context/testing/tech/ctx-testing-001-test-doubles.md .context/archive/
# Archive Tests/TestCases/ (keep as reference until migration verified)
```

---

## Validation Checklist

After all workstreams complete:

- [ ] `.context/index.json` reflects true state of all entries
- [ ] All 7 playbooks exist with frontmatter and required sections
- [ ] CLAUDE.md < 60 lines, CODEX.md < 60 lines, CURSOR.md < 60 lines
- [ ] AGENTS-SOURCES.md ~20 lines (loading guide only)
- [ ] AGENTS-SCRIPTS.md ~20 lines (loading guide only)
- [ ] All test cases migrated to YAML with zero data loss
- [ ] `packages/test-cases/` validation passes
- [ ] `packages/mock-data/` contains all fixture files
- [ ] Test doubles renamed per Meszaros taxonomy
- [ ] All existing tests pass after refactoring
- [ ] `validate-agent-sync.sh` passes
- [ ] `generate-context-index.py` produces consistent output
