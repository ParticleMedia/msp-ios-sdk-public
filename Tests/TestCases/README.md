# Test Cases

Test case definitions as the **source of truth** for TDD.

## Workflow

```
1. Define test cases     →  {Module}.json
2. Validate JSON         →  python test-cases.py validate
3. Implement tests       →  {Module}Spec.swift with [ID] markers
4. Check sync            →  python test-cases.py sync
```

## ID Format

**Format**: `[PREFIX###]`
- `PREFIX` = 2-4 uppercase letters (unique per module, registered in `_prefixes.json`)
- `###` = 3-digit sequence number

| Module | Prefix | IDs |
|--------|--------|-----|
| DebugAdLoad | DAL | DAL001, DAL002 |
| DebugRadioCell | DRC | DRC001, DRC002 |

**New module?** Register prefix in `_prefixes.json` first.

## Naming Convention

JSON filename (`module`) must be substring of Swift test file name:

```
DebugAdLoad.json  →  DebugAdLoadViewModelSpec.swift ✓
```

## Commands

```bash
# Validate JSON (check duplicates, prefix conflicts)
python Scripts/tools/test-cases.py validate

# Check implementation sync
python Scripts/tools/test-cases.py sync

# CI: run both (fails if any issues)
python Scripts/tools/test-cases.py validate sync
```

## Files

| File | Purpose |
|------|---------|
| `_prefixes.json` | Prefix registry (register before using) |
| `_template.json` | Template for new modules |
| `*.json` | Test case definitions |
