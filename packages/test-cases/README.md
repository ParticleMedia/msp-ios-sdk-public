# Test Cases (YAML)

Centralized test case definitions as the **source of truth** for TDD.

## Schema Version: 2.0

### Module-level fields (v2.0)
- `bundle` (required): Xcode test target — `MSPCoreTests`, `NovaCoreTests`, `MSPiOSCoreTests`, `AdapterTests`

### Case-level fields (v2.0)
- `file`: Path to the Swift spec file (required when `status` is `implemented`)
- `status`: `implemented` (default) | `planned` | `skipped`
- `fixtures`: Optional array of mock-data paths (relative to `packages/mock-data/`)

## Workflow (YAML-First)

```
1. Register prefix       →  _prefixes.yaml
2. Define test cases      →  {subdirectory}/{Module}.yaml
3. Validate YAML          →  python Scripts/tools/test-cases.py validate
4. Implement Swift tests  →  {Module}Spec.swift with [ID] markers
5. Check sync             →  python Scripts/tools/test-cases.py sync
6. View coverage          →  python Scripts/tools/test-cases.py coverage
```

## ID Format

**Format**: `[PREFIX###]`
- `PREFIX` = 2-4 uppercase letters (unique per module, registered in `_prefixes.yaml`)
- `###` = 3-digit sequence number

| Module | Prefix | IDs | Bundle | Location |
|--------|--------|-----|--------|----------|
| DebugAdLoad | DAL | DAL001-DAL015 | MSPCoreTests | debug/DebugAdLoad.yaml |
| DebugRadioCell | DRC | DRC001-DRC002 | MSPCoreTests | debug/DebugRadioCell.yaml |
| NovaMraidSupporting | NMS | NMS001-NMS002 | NovaCoreTests | mraid/NovaMraidSupporting.yaml |

## Test Doubles (Meszaros Taxonomy)

Each test case may specify `doubles` — the test doubles it requires:

| Type | Naming | Purpose |
|------|--------|---------|
| Dummy | `Dummy*` | Satisfy parameters, never used |
| Stub | `Stub*` | Provide canned responses |
| Spy | `Spy*` | Record calls for verification |
| Mock | `Mock*` | Stub + Spy (verify behavior) |
| Fake | `Fake*` | Working implementation (simplified) |

## Regression Tests

Use `regression_for` field to link a test case to the bugfix it guards:

```yaml
- id: DAL016
  type: behavior
  description: "Empty placements no longer crash"
  regression_for: "fix/empty-placements-crash"
```

## Commands

```bash
python Scripts/tools/test-cases.py validate       # Validate YAML
python Scripts/tools/test-cases.py sync            # Check implementation
python Scripts/tools/test-cases.py coverage        # Status by bundle
python Scripts/tools/test-cases.py validate sync   # CI: both
python Scripts/tools/test-cases.py validate sync coverage  # Full check
```

## Schema

See `_schema.yaml` for the full JSON Schema definition.
Use `_template.yaml` as a starting point for new modules.
