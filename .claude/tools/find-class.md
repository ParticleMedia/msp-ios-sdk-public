---
id: find-class
description: "Finds the definition of a Swift type (class/struct/protocol/enum) in Sources/."
run: ./Sources/tools/find-class.sh "$1"
---
# Find Class Tool

## Purpose
Locates where a Swift type is defined in the codebase.

## Shared Script
`Sources/tools/find-class.sh` (usable by all agents)

## Usage
- **Claude**: `find-class <TypeName>`
- **Other Agents**: `./Sources/tools/find-class.sh <TypeName>`

## Example
```bash
./Sources/tools/find-class.sh BidLoader
# Output:
# === Searching for: BidLoader ===
#
# --- Type Definitions ---
# Sources/Core/MSPCore/BidLoader.swift:15:public class BidLoader {
#
# --- Extensions ---
# Sources/Core/MSPCore/BidLoader+Networking.swift:8:extension BidLoader {
```

## Output
Returns `file:line` for:
- Type definitions (class, struct, protocol, enum, actor)
- Extensions of the type
