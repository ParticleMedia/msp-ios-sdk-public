# Research: AI Infrastructure v2

**Branch**: `ai-infra-v2` | **Date**: 2026-02-22 | **Plan**: [plan.md](./plan.md)

## R1: YAML Test Case Schema Design

### Decision
Use YAML with JSON Schema validation (Draft 2020-12) via Python `jsonschema` + `PyYAML` libraries. Support dual-type (`unit` + `behavior`) with conditional validation using `allOf`/`if`/`then`.

### Rationale
- YAML supports inline comments (critical for documenting regression history and business rules)
- JSON Schema Draft 2020-12 supports `if`/`then` conditional validation (needed for type-dependent required fields)
- Python `jsonschema` library is mature, well-maintained, and already available in our scripting environment
- `yamale` is simpler but lacks conditional validation support needed for dual-type schema

### Alternatives Considered
- **Yamale**: Simpler Python YAML validator, but lacks conditional validation (`if`/`then`) needed for behavior vs unit type-dependent fields
- **Cerberus**: Python validation library, but not JSON Schema compatible
- **JSON (keep current)**: No inline comments, harder to document regression context
- **TOML**: Better for config, worse for nested data structures like test cases

### Schema
See [contracts/test-case-schema.yaml](./contracts/test-case-schema.yaml)

### Sources
- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12/json-schema-validation)
- [Python jsonschema docs](https://python-jsonschema.readthedocs.io/en/stable/validate/)
- [YAML validation with JSON Schema](https://devops-db.com/python-yaml-validation-with-json-schema/)

---

## R2: JSON→YAML Migration Strategy

### Decision
Python migration script using `json` → `yaml` libraries. One-shot migration preserving all IDs and metadata. Archive original JSON files (don't delete) until verification complete.

### Rationale
- Python has native JSON/YAML support
- One-shot migration is simpler than incremental approach
- Archiving originals provides safety net
- Migration script doubles as documentation of format differences

### Migration Process
1. Read each `Tests/TestCases/*.json` file
2. Parse JSON structure
3. Transform to YAML format:
   - Add YAML-specific fields: `created`, `updated`, `priority` (default: medium), `tags`
   - Add empty `doubles` template for each case
   - Add empty `regression_for` field template
   - Convert JSON comments (not possible) → YAML inline comments
4. Write to `packages/test-cases/{domain}/{Module}.yaml`
5. Validate against schema
6. Archive originals to `Tests/TestCases/.archive/`

### Validation
- ID count before == ID count after
- All fields preserved (type, description, given/when/then, class/method)
- Schema validation passes for all migrated files

---

## R3: Machine-Readable Context Index Format

### Decision
JSON index file (`.context/index.json`) auto-generated from Markdown frontmatter. Replaces current `.context/index.md` (Markdown tables). AI agents read the JSON index to discover entries by keyword matching against `tags` and `triggers` fields.

### Rationale
- JSON is natively parseable by all AI agents (no Markdown table parsing needed)
- Frontmatter extraction is straightforward with grep/sed or Python
- Index regeneration is fast (parse frontmatter only, not full content)
- Keyword matching against tags/triggers is simple string matching (no TF-IDF needed for ~20 entries)

### Schema
See [contracts/context-index-schema.json](./contracts/context-index-schema.json)

### Auto-Generation Strategy
1. Shell script scans `.context/{domain}/{layer}/ctx-*.md` files
2. Extracts YAML frontmatter between `---` markers
3. Parses frontmatter fields using `yq` or Python `yaml` library
4. Assembles JSON index with domain summary counts
5. Writes atomically (temp file → move)

### Keyword Matching Algorithm
For ~20 entries, simple substring matching against `tags[]` and `triggers[]` is sufficient:
```
agent_task_keywords = extract_keywords(current_task)
for entry in index.entries:
    score = count_matches(agent_task_keywords, entry.tags + entry.triggers)
    if score > 0:
        suggest_loading(entry)
```

No TF-IDF or vector embeddings needed at this scale.

### Sources
- [Claude Code Skills Progressive Disclosure](https://code.claude.com/docs/en/skills) — ~100 tokens per skill metadata at startup
- [MCP Tool Discovery](https://modelcontextprotocol.io/specification/2025-06-18/server/tools) — JSON metadata for tool/resource discovery
- [Agent Discovery Protocol (IETF Draft)](https://www.ietf.org/archive/id/draft-cui-ai-agent-discovery-invocation-00.html) — Agent metadata patterns

---

## R4: Progressive Loading Patterns for AI Agents

### Decision
Three-tier architecture per Federal Constitution Article X.1:
- **Tier 0 (Always-loaded)**: CLAUDE.md/CODEX.md/CURSOR.md (<60 lines) + constitution.md + `.claude/rules/`
- **Tier 1 (Directory-triggered)**: AGENTS-SOURCES.md, AGENTS-SCRIPTS.md (~20 lines loading guides)
- **Tier 2 (On-demand)**: Playbooks discovered via `.context/index.json` keyword matching

### Agent-Specific Mechanisms

| Agent | Tier 0 | Tier 1 | Tier 2 |
|-------|--------|--------|--------|
| Claude Code | `.claude/CLAUDE.md` + `.claude/rules/` (auto-loaded) | Directory-triggered `@imports` | Skills + context search via index.json |
| Codex CLI | `.codex/CODEX.md` + `instructions.md` (auto-loaded) | Not natively supported; embed in instructions.md | Manual reference to index.json in prompts |
| Cursor IDE | `.cursor/CURSOR.md` + `.cursor/settings/rules.json` | `.cursor/rules/` with glob patterns (e.g., `Sources/**/*.swift`) | Manual reference to index.json; cursor rules can trigger on file patterns |

### Rationale
- Claude Code has the most sophisticated progressive loading (rules, skills, directory triggers)
- Codex simulates it through condensed instruction files
- Cursor supports glob-based rule activation via `rules.json`
- All three can read `.context/index.json` to discover on-demand content

---

## R5: Meszaros Test Doubles Taxonomy (Swift/Quick/Nimble)

### Decision
Adopt the Meszaros/Fowler canonical taxonomy with 5 types. Hand-rolled doubles preferred over mocking frameworks. `Mock{Xxx}` retained for Stub+Spy hybrids as a project convention.

### 5-Type Taxonomy

| Type | Purpose | Calls dependency? | Returns data? | Records calls? | Verifies behavior? | Has logic? |
|------|---------|-------------------|---------------|----------------|--------------------:|------------|
| Dummy | Fill parameter lists | Never | N/A | No | No | No |
| Stub | Preset return values | Yes | Yes (preset) | No | No | No |
| Spy | Record calls | Yes | Yes (preset) | Yes | No | No |
| Mock | Verify expectations | Yes | Yes (preset) | Yes | Yes | No |
| Fake | Working shortcut | Yes | Yes (computed) | Optional | No | Yes |

### Decision Tree

```
Is the dependency called during the test?
├── No → DUMMY (just fills the parameter list)
└── Yes → Do you need specific return values?
    ├── No → DUMMY (default behavior is sufficient)
    └── Yes → Do you need to verify HOW it was called?
        ├── No → STUB (just returns preset data)
        └── Yes → Do you need pre-programmed expectations?
            ├── No → SPY (records calls, assert after)
            └── Yes → MOCK (expectations set before, verified after)

Does the double need working logic (not just preset values)?
└── Yes → FAKE (e.g., in-memory store, value-type conformance)
```

### Sources
- [Meszaros xUnit Patterns](http://xunitpatterns.com/Mocks,%20Fakes,%20Stubs%20and%20Dummies.html)
- [Fowler: Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Fowler: bliki Test Double](https://martinfowler.com/bliki/TestDouble.html)

---

## R6: Script Best Practices (Bash vs Python, Config-Driven)

### Decision
Follow Google Shell Style Guide complexity threshold (~100 lines). Use Bash for file operations and process orchestration; Python for data processing, YAML manipulation, and complex logic.

### Language Decision Criteria

| Criterion | Bash | Python |
|-----------|------|--------|
| File operations (cp, mv, mkdir) | ✅ | ❌ |
| Process orchestration (run tools) | ✅ | ❌ |
| YAML/JSON processing | ❌ (use `yq`) | ✅ (`yaml`/`json`) |
| String manipulation | ❌ | ✅ |
| >100 lines of logic | ❌ | ✅ |
| CI pipeline steps | ✅ | ❌ |
| Data validation | ❌ | ✅ |
| Cross-platform portability | ⚠️ (BSD vs GNU) | ✅ |

### macOS vs Linux Portability Gotchas

| Tool | macOS (BSD) | Linux (GNU) | Safe Alternative |
|------|------------|-------------|-----------------|
| sed | `sed -i '' 's/...'` | `sed -i 's/...'` | Use `sed -i.bak` + `rm *.bak` |
| grep | No `-P` (PCRE) | Has `-P` | Use `-E` (extended regex) |
| date | `date -v+1d` | `date -d "+1 day"` | Use Python `datetime` |
| readlink | No `-f` | Has `-f` | Use `cd "$(dirname "$0")" && pwd` |
| stat | `stat -f%z` | `stat -c%s` | Use `wc -c < file` |

### Config-Driven Development Pattern

```
YAML Config → Script reads config → Deterministic output
```

- All behavior-controlling values in YAML config files (not hardcoded)
- Scripts read config at startup, validate, then execute
- Config changes don't require script changes
- Consistent with project's existing `Scripts/config/*.yaml` pattern

### Sources
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [GitLab Scripting Standards](https://docs.gitlab.com/ee/development/shell_scripting_guide/)

---

## R7: AI-First Playbook Design Patterns

### Decision
Playbooks are AI-first documents with decision trees, wrong→right code examples, file-pointer references, and dedicated "AI Common Mistakes" sections. Each playbook targets a specific domain and includes concrete codebase references.

### Playbook Design Principles

1. **Decision Trees over Prose**: AI agents process structured decision logic better than narrative explanations
2. **Wrong→Right Code Pairs**: Show the anti-pattern AND the correct pattern side by side
3. **File Pointers over Inline Code**: Reference real codebase files (`Sources/Core/MSPCore/BidLoader.swift:42`) instead of embedding code that can go stale
4. **Trigger Keywords**: Explicit keyword list for index-based discovery
5. **AI Common Mistakes**: ≥3 specific patterns that AI agents commonly produce incorrectly, validated against real agent output

### Anti-Pattern Documentation Format

```markdown
### ❌ Wrong: Force unwrap outside unit tests
```swift
let config = loadConfig()!  // AI commonly generates this
```

### ✅ Right: Safe unwrap with error handling
```swift
guard let config = loadConfig() else {
    logger.error("Failed to load config")
    return
}
```

**Why AI gets this wrong**: Training data contains many examples with `!` for brevity. AI agents default to the shortest working code rather than the safest code.
```

### Sources
- [Claude Code Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- Internal analysis of AI agent output patterns in MSP iOS SDK
