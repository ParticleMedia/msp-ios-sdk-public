---
name: unit-test-generator
description: Generate boilerplate Quick/Nimble unit test files using project template
category: generation
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Read, Glob, Bash]
quick_reference: "When: Creating unit tests. Steps: (1) Get template via `./Scripts/tools/get-test-template.sh` (2) Replace {{module_name}} and {{class_name}} (3) Save to Tests/{Module}Tests/{ClassName}Spec.swift"
---

# Unit Test Generator Skill

> **Type**: Generation Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Create boilerplate test files following project conventions

---

## Purpose

Generate complete, standardized Quick/Nimble unit test files for Swift classes using the project's official template. Ensures consistency across all test files and adherence to BDD testing patterns.

---

## Scope

**Does**:
- Generate boilerplate test structure
- Auto-detect module names
- Apply project-specific test template
- Follow naming conventions

**Does NOT**:
- Write actual test logic (requires domain knowledge)
- Mock complex dependencies (human judgment needed)
- Design test strategy (use architect for complex cases)

---

## When to Use

- Creating unit tests for a new class
- Adding test coverage for untested code
- Following up after implementing a new feature
- When you need a standardized test file structure

---

## Required Inputs

1. **class_name**: The Swift class to test (required)
2. **module_name**: The module containing the class (optional, auto-detected if not provided)

---

## Execution Steps

### Step 1: Determine Module

If module not provided, search for the class:
```bash
grep -r "class {class_name}" Sources/
```

The module name is the directory name under `Sources/` (e.g., `Sources/Core/MSPCore/` → `MSPCore`).

**Common Modules**:
- `MSPCore` - Core SDK functionality
- `MSPiOSSDK` - Public iOS SDK API
- `MSPNovaAdapter` - Nova ad network adapter

---

### Step 2: Retrieve Template

Read the official test template:
```bash
cat "$(git rev-parse --show-toplevel)/Tests/templates/unit_test_spec.swift.template"
```

**Template Location**: `Tests/templates/unit_test_spec.swift.template`

---

### Step 3: Populate Template

Replace placeholders in the template:
- `{{module_name}}` → actual module name
- `{{class_name}}` → actual class name

**Example**:
```swift
// Template
@testable import {{module_name}}

class {{class_name}}Spec: QuickSpec {
    // ...
}

// Populated for BidLoader in MSPCore
@testable import MSPCore

class BidLoaderSpec: QuickSpec {
    // ...
}
```

---

### Step 4: Determine File Path

Test files follow this convention:
```
Tests/{ModuleName}Tests/{ClassName}Spec.swift
```

**Examples**:
- `BidLoader` in `MSPCore` → `Tests/MSPCoreTests/BidLoaderSpec.swift`
- `AdManager` in `MSPiOSSDK` → `Tests/MSPiOSSDKTests/AdManagerSpec.swift`

---

### Step 5: Present Result

Output the populated template and suggested file path with next steps.

---

## Output Format

```markdown
## Generated Test File

**Path**: `Tests/{ModuleName}Tests/{ClassName}Spec.swift`

```swift
// populated template content
```

**Next Steps**:
1. Create the file at the suggested path
2. Replace TODO comments with actual mock dependencies
3. Add test cases for each public method
4. Run tests: `swift test --filter {ClassName}Spec`
```

---

## Example Usage

### For Claude Code

```markdown
@../.agents-shared/skills/unit-test-generator.skill.md

Generate unit test for BidLoader class in MSPCore module
```

### For Codex CLI

```bash
$ codex "generate unit test for BidLoader class"
# Codex will:
# 1. Auto-detect module (MSPCore)
# 2. Apply template
# 3. Create Tests/MSPCoreTests/BidLoaderSpec.swift
```

### For Cursor

**Composer Mode**:
```
Generate unit test for @file:Sources/Core/MSPCore/BidLoader.swift

Use template: @file:Tests/templates/unit_test_spec.swift.template
Create at: Tests/MSPCoreTests/BidLoaderSpec.swift
```

---

## Example

**Input**:
- `class_name`: `BidLoader`
- `module_name`: Auto-detected

**Detection**:
```bash
$ grep -r "class BidLoader" Sources/
Sources/Core/MSPCore/BidLoader.swift:public class BidLoader {
# Module: MSPCore
```

**Output Path**: `Tests/MSPCoreTests/BidLoaderSpec.swift`

**Generated Content**:
```swift
import Quick
import Nimble
@testable import MSPCore

class BidLoaderSpec: QuickSpec {
    override func spec() {
        describe("BidLoader") {
            var sut: BidLoader!

            beforeEach {
                // TODO: Initialize BidLoader with mock dependencies
                sut = BidLoader()
            }

            afterEach {
                sut = nil
            }

            context("when loading bid") {
                it("should return valid bid") {
                    // TODO: Implement test
                }
            }
        }
    }
}
```

---

## Tips for Effective Test Generation

1. **Check Existing Tests**: Look at similar test files for patterns
2. **Identify Dependencies**: Note what needs to be mocked
3. **Cover Public API**: Focus on public/open methods first
4. **Follow BDD**: Use describe-context-it structure
5. **Run Early**: Create file and run tests immediately to catch issues

---

## Related Skills

- `sources-bug-analyst.skill.md`: For debugging test failures
- `constitutional-auditor.skill.md`: Verify test follows constitution
- `quick-fix.skill.md`: For fixing failing tests (to be created)
