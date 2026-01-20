---
id: validate-script
description: "Validates a shell script using shellcheck per Scripts/constitution.md."
run: ./Scripts/tools/validate-script.sh "$1"
---
# Validate Script Tool

## Purpose
Runs shellcheck on a shell script to ensure it meets quality standards.

## Shared Script
`Scripts/tools/validate-script.sh` (usable by all agents)

## Usage
- **Claude**: `validate-script <script-path>`
- **Other Agents**: `./Scripts/tools/validate-script.sh <script-path>`

## Example
```bash
./Scripts/tools/validate-script.sh Scripts/msp-release.sh
```

## Output
- Exit 0: Script passes validation
- Exit 1: Shellcheck found issues

## Constitutional Reference
**Scripts/constitution.md**: All shell scripts must be validated with shellcheck.
