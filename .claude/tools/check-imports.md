---
id: check-imports
description: "Checks for forbidden third-party imports in Core modules per constitution Article III."
run: ./Sources/tools/check-imports.sh "$1"
---
# Check Imports Tool

## Purpose
Validates that Core modules don't import third-party SDK headers, per Article III.1 of the constitution.

## Shared Script
`Sources/tools/check-imports.sh` (usable by all agents)

## Usage
- **Claude**: `check-imports [ModulePath]`
- **Other Agents**: `./Sources/tools/check-imports.sh [ModulePath]`

## Example
```bash
./Sources/tools/check-imports.sh Sources/Core/MSPCore
# Or check all Core modules:
./Sources/tools/check-imports.sh
```

## Output
- Exit 0: No violations
- Exit 1: Violations found (lists offending imports)

## Constitutional Reference
**Article III.1**: Core modules must not import third-party SDK headers.
