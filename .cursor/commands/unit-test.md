---
description: Generate a boilerplate Quick/Nimble unit test file for a given Swift class.
---

## User Input

```text
$ARGUMENTS
```

## Goal

Generate a Quick/Nimble test file for the specified class.

## Steps

1. **Find the class**: Search for the class name in `Sources/` to determine its module and file location. Use `./Sources/tools/find-class.sh <ClassName>` if available.
2. **Determine module**: The module name is typically the parent directory name (e.g., `MSPCore`, `NovaAdapter`).
3. **Load playbooks**: Read these context files before generating:
   - `.context/testing/tech/ctx-testing-001-unit-test-quick-nimble.md` (Quick/Nimble rules)
   - `.context/testing/tech/ctx-testing-002-bdd-best-practices.md` (BDD structure)
4. **Get template**: Run `./Scripts/tools/get-test-template.sh` to get the boilerplate.
5. **Populate placeholders**: Replace `{{module_name}}` and `{{class_name}}` with actual values.
6. **Generate test cases**: Analyze the class's public API and generate meaningful test cases following Given-When-Then pattern.
7. **Create file**: Place at `Tests/{ModuleName}Tests/{ClassName}Spec.swift`.

## Rules

- Use Quick/Nimble BDD style (`describe`/`context`/`it`)
- Hand-write test doubles (stub/spy/fake) — NEVER use third-party mocking frameworks
- Use `@TestState` for test variables
- Follow Given-When-Then pattern inside each `it` block
- Force-unwrap (`!`) is acceptable inside `it()` assertion blocks

## Example

For class `BidLoader` in module `MSPCore`:
- File path: `Tests/MSPCoreTests/BidLoaderSpec.swift`
- Module: `MSPCore`
- Class: `BidLoader`
