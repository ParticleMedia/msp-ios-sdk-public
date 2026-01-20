# Constitution: Tests Directory
> **Version**: 1.0
> **Last Updated**: 2026-01-13
> **Scope**: Augments the Federal Constitution for the `./Tests/` directory.

This document adds specific laws for test code quality. All federal laws from the root `constitution.md` are inherited and remain in full force.

---
## Article VIII: The Test Readability Principle
**Core Tenet**: Tests are documentation. They must be clear, descriptive, and easy to understand.

**8.1 (BDD Style)**: All tests must follow the `describe-context-it` structure provided by Quick, making them read like behavioral specifications.
**8.2 (Clear Assertions)**: Use Nimble's expressive matchers to write clear and understandable assertions. Avoid complex logic within tests.
**8.3 (No Magic Values)**: Inputs and expected outputs in tests should be declared as well-named constants or variables, not "magic" numbers or strings.
