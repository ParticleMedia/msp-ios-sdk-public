# Shared Templates

> **Version**: 1.0
> **Last Updated**: 2026-01-14

This directory serves as an **index** for shared templates used across the project.

---

## Template Locations

Templates are **not stored in `.agents-shared/`** - they remain in their original locations. This file provides a reference.

### Test Templates
| Template | Location | Purpose |
|----------|----------|---------|
| Unit Test Spec | `Tests/templates/unit_test_spec.swift.template` | Quick/Nimble test boilerplate |

### Script Templates
| Template | Location | Purpose |
|----------|----------|---------|
| Release Notes | `Scripts/templates/release-notes-template.md` | Changelog entry format |

---

## Template Syntax

All templates use `{{placeholder}}` syntax:

```swift
// Example from unit_test_spec.swift.template
import Quick
import Nimble
@testable import {{module_name}}

class {{class_name}}Spec: QuickSpec {
    // ...
}
```

### Common Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{module_name}}` | Swift module name | MSPCore |
| `{{class_name}}` | Class under test | BidLoader |
| `{{version}}` | Version number | 1.0.0-rc.23 |

---

## Usage

### For Skills
Skills can reference templates:
```markdown
## Step 2: Get Template
Run: `./Scripts/tools/get-test-template.sh`
```

### For Agents
Agents can directly read templates:
```bash
cat Tests/templates/unit_test_spec.swift.template
```
