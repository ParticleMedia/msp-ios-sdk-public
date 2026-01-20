---
id: list-public-api
description: "Lists all public/open declarations in a Swift module."
run: ./Sources/tools/list-public-api.sh "$1"
---
# List Public API Tool

## Purpose
Enumerates all public and open declarations in a module for API review.

## Shared Script
`Sources/tools/list-public-api.sh` (usable by all agents)

## Usage
- **Claude**: `list-public-api <ModulePath>`
- **Other Agents**: `./Sources/tools/list-public-api.sh <ModulePath>`

## Example
```bash
./Sources/tools/list-public-api.sh Sources/Core/MSPCore
```

## Output
Lists types, functions, and properties marked `public` or `open`.

## Use Case
- API review before release
- Checking for unintended public exposure
- Documenting module surface area
