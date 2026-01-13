---
name: constitutional-auditor
description: A reusable knowledge module for checking code compliance against constitution.md files. This is a building block - use the code-reviewer agent for full PR reviews.
allowed-tools: Read, Glob
---
# Constitutional Auditor Skill

## Purpose
A focused, single-responsibility skill that checks code against the project's `constitution.md` hierarchy. This skill is designed to be **invoked by Agents** or used standalone for quick compliance checks.

## Scope
- **Does**: Check constitutional compliance, cite violations
- **Does NOT**: Assess architecture, design patterns, or code quality beyond constitution

## Execution Steps
1. **Load Constitutions**: Read the root `constitution.md` and any applicable subdirectory `constitution.md` (e.g., `Sources/constitution.md` for Swift files).
2. **Identify Applicable Articles**: Based on file type and location, determine which articles apply.
3. **Audit**: Compare the code against each applicable article.
4. **Report Violations**: For each violation, output:
   - Article reference (e.g., `Sources/constitution.md Article IV.3`)
   - Violation description
   - Suggested fix

## Output Format
```
## Constitutional Audit Results

### Violations Found: N

1. **[Article IV.3]** Force-unwrap detected at line 42
   - Location: `Sources/Core/MSPCore/BidLoader.swift:42`
   - Fix: Use `guard let` or `if let` instead of `!`

2. **[Article I.2]** Direct .xcodeproj modification detected
   - Location: `MSPCore.xcodeproj/project.pbxproj`
   - Fix: Modify `project.yml` and run XcodeGen instead
```
