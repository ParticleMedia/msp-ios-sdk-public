# Constitution: Scripts Directory
> **Version**: 2.0
> **Last Updated**: 2026-02-26
> **Scope**: Augments the Federal Constitution for the `./Scripts/` directory.

This document adds specific laws for all script development. All federal laws from the root `constitution.md` are inherited and remain in full force.

---
## Article VI: The Scripting Integrity Principle
**Core Tenet**: Scripts are production code. They must be robust, predictable, and maintainable.

**6.1 (Error Handling)**: Scripts **must** fail fast and explicitly. Shell scripts must use `set -euo pipefail`.
**6.2 (Idempotency)**: Where possible, scripts should be idempotent to align with Article I of the Federal Constitution.
**6.3 (POSIX Compliance)**: All new shell scripts (`.sh`) must be written to be POSIX-compliant.
**6.4 (Canonical Artifacts)**: All build and release scripts **must** write XCFramework outputs to `Build/ReleaseArtifacts/XCFrameworks`. Legacy **repo-root** paths (`Build/XCFrameworks`, top-level `Binary/`) are forbidden and must not be created or referenced. The only allowed `Binary/` path is `Build/ReleaseArtifacts/Binary` (release zip staging).
**6.5 (Centralized Configuration)**: [Non-Negotiable] `Scripts/config/release.yaml` is the single source of truth for release configuration. Duplicate or shadow config files are forbidden.
**6.6 (Module Guards)**: Shared library modules sourced by multiple scripts should use sourcing guards (e.g., `_MODULE_SOURCED` pattern) to prevent double-sourcing side effects.

---
## Article VII: The Script Testing Imperative
**Core Tenet**: Scripts must be validated by automated tests. Untested scripts are liabilities.

**7.1 (Unit Test Coverage)**: New release pipeline modules in `Scripts/release/` must have corresponding unit tests in `Scripts/tests/unit/cases/`.
**7.2 (Pod-Specific Handling)**: When adding pod-specific logic (e.g., resource bundles, special zip contents), both `generate_podspec.sh` and `zip_management.sh` must be updated atomically, with corresponding test cases.
**7.3 (Test Infrastructure)**: Unit tests use the helpers in `Scripts/tests/unit/helpers.sh`. Tests must use `assert_*` functions (`assert_equals`, `assert_contains`, `assert_exit_code`, `assert_file_exists`, `assert_not_equals`) and `info()` for consistent output.
