# Constitution: Scripts Directory
> **Version**: 1.0
> **Last Updated**: 2026-01-13
> **Scope**: Augments the Federal Constitution for the `./Scripts/` directory.

This document adds specific laws for all script development. All federal laws from the root `constitution.md` are inherited and remain in full force.

---
## Article VI: The Scripting Integrity Principle
**Core Tenet**: Scripts are production code. They must be robust, predictable, and maintainable.

**6.1 (Error Handling)**: Scripts **must** fail fast and explicitly. Shell scripts must use `set -euo pipefail`.
**6.2 (Idempotency)**: Where possible, scripts should be idempotent to align with Article I of the Federal Constitution.
**6.3 (POSIX Compliance)**: All new shell scripts (`.sh`) must be written to be POSIX-compliant.
