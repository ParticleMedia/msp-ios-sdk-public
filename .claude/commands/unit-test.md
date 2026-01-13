---
name: /unit-test
description: Generates a boilerplate Quick/Nimble unit test file for a given Swift class.
uses-skill: unit-test-generator
---
# Task: Generate Unit Test Boilerplate

Generate a Quick/Nimble test file for the class: `{{$1}}`.

## Steps
1. **Find the class**: Search for `{{$1}}` in `Sources/` to determine its module and file location.
2. **Determine module**: The module name is typically the parent directory name (e.g., `MSPCore`, `NovaAdapter`).
3. **Generate test**: Use the `get-test-template` tool (run the shell command defined in `.claude/tools/get-test-template.md`).
4. **Populate placeholders**: Replace `{{module_name}}` and `{{class_name}}` with actual values.
5. **Suggest file path**: Tests go in `Tests/{ModuleName}Tests/{ClassName}Spec.swift`.

## Example Output
For class `BidLoader` in module `MSPCore`:
- File path: `Tests/MSPCoreTests/BidLoaderSpec.swift`
- Module: `MSPCore`
- Class: `BidLoader`
