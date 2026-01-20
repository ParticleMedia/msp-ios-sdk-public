# Constitution: Sources Directory
> **Version**: 1.0
> **Last Updated**: 2026-01-12
> **Scope**: Augments the Federal Constitution for the `./Sources/` directory.

This document adds stricter, domain-specific laws for all production source code development. All federal laws from the root `constitution.md` are inherited and remain in full force.

---
## Article IV: The Principle of Core Swift Practices
**Core Tenet**: Write idiomatic, robust, and maintainable Swift code.

**4.1 (Value-Types First)**: Must prefer `struct` and `enum` for modeling data.
**4.2 (Immutability by Default)**: Must prefer `let` for declaring constants.
**4.3 (Safe Error Handling)**: [Non-Negotiable] Errors must never be "swallowed." Force-unwrapping optionals (`!`) is forbidden unless 100% safe. All `public` APIs must have Swift DocC comments.

---
## Article V: The Test-First Imperative [Non-Negotiable]
**Core Tenet**: All new features or bug fixes for production code must begin by writing one or more failing tests. Code without corresponding tests is considered incomplete.

**5.1 (TDD Cycle)**: Strictly adhere to the "Red-Green-Refactor" cycle.
**5.2 (Mandatory Testing Framework)**: All new unit tests **must** use the **Quick & Nimble** framework to facilitate Behavior-Driven Development (BDD) style testing.
