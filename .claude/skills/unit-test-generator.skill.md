---
name: unit-test-generator
description: A skill to generate a boilerplate Quick/Nimble unit test file using the official project template.
allowed-tools: Read, Glob, Bash
uses-tool: get-test-template
---
# Unit Test Generator Skill

## Objective
Generate a complete, boilerplate test file for a given Swift class using the project's official template.

## Inputs
- **class_name**: The Swift class to test (required)
- **module_name**: The module containing the class (auto-detected if not provided)

## Execution Steps

### Step 1: Determine Module
If module not provided, search for the class:
```bash
grep -r "class {class_name}" Sources/
```
The module name is the directory name under `Sources/` (e.g., `Sources/Core/MSPCore/` → `MSPCore`).

### Step 2: Execute Template Tool
Run the `get-test-template` tool to retrieve the template:
```bash
cat "$(git rev-parse --show-toplevel)/Tests/templates/unit_test_spec.swift.template"
```

### Step 3: Populate Template
Replace placeholders in the template:
- `{{module_name}}` → actual module name
- `{{class_name}}` → actual class name

### Step 4: Determine File Path
Test files follow this convention:
```
Tests/{ModuleName}Tests/{ClassName}Spec.swift
```

### Step 5: Present Result
Output the populated template and suggested file path.

## Output Format
```
## Generated Test File

**Path**: `Tests/{ModuleName}Tests/{ClassName}Spec.swift`

```swift
// populated template content
```

**Next Steps**:
1. Create the file at the suggested path
2. Replace TODO comments with actual mock dependencies
3. Add test cases for each public method
```

## Example
For `BidLoader` in `MSPCore`:
- Input: `class_name=BidLoader`
- Module: `MSPCore` (auto-detected from `Sources/Core/MSPCore/BidLoader.swift`)
- Output path: `Tests/MSPCoreTests/BidLoaderSpec.swift`
