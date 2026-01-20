---
id: get-test-template
description: "Prints the standard boilerplate content for a Quick/Nimble unit test spec file."
run: ./Scripts/tools/get-test-template.sh
---
# Get Test Template Tool

## Purpose
Retrieves the Quick/Nimble unit test template from the shared templates location.

## Shared Script
`Scripts/tools/get-test-template.sh` (usable by all agents)

## Usage
- **Claude**: Invokes this tool via `run:` field
- **Other Agents**: Run `./Scripts/tools/get-test-template.sh` directly

## Output
Returns the raw template content with placeholders:
- `{{module_name}}` - The Swift module to import
- `{{class_name}}` - The class under test
