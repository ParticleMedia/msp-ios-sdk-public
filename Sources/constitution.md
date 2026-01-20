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

**4.4 (Logging Standards)**: [Required] Use `Logger` API (iOS 14+) for all logging with proper subsystem and category organization.
- Define subsystem as bundle identifier (e.g., `com.newsbreak.msp`)
- Define category per module (e.g., "Network", "AdRendering", "BidManager")
- Use appropriate log levels: `.debug`, `.info`, `.notice`, `.error`, `.fault`
- Mark sensitive data with `.private` privacy level
- Example:
  ```swift
  import OSLog
  let logger = Logger(subsystem: "com.newsbreak.msp", category: "BidManager")
  logger.debug("Requesting bid with id: \(bidId, privacy: .public)")
  logger.error("Failed to load ad: \(error.localizedDescription, privacy: .public)")
  ```

**4.5 (Error Handling Standards)**: [Required] Use structured error handling with domain-specific error types.
- Define domain-specific Error enums for each module (e.g., `AdLoadingError`, `NetworkError`, `BidError`)
- Use `Result<T, Error>` for async operations with completion handlers
- Use `throws` for sync operations that can fail
- Never use Optional to represent error states (use Result or throws instead)
- Log errors at point of origin with sufficient context
- Example:
  ```swift
  enum AdLoadingError: Error {
      case networkFailure(underlyingError: Error)
      case invalidResponse
      case timeout
  }

  func fetchAd(completion: @escaping (Result<Ad, AdLoadingError>) -> Void) {
      // Async with Result
  }

  func parseAd(data: Data) throws -> Ad {
      // Sync with throws
  }
  ```

**4.6 (Project Configuration Workflow)**: [Non-Negotiable] All Xcode project changes must use XcodeGen (References Federal Constitution Article I.2).
- Modify `*.yml.template` files (e.g., `project.yml.template`), then run XcodeGen to regenerate `.xcodeproj`
- Never commit `.xcodeproj` changes directly
- Rationale: `.xcodeproj` and `.xcworkspace` are in `.gitignore`; only template files are source-controlled

---
## Article V: The Test-First Imperative [Non-Negotiable]
**Core Tenet**: All new features or bug fixes for production code must begin by writing one or more failing tests. Code without corresponding tests is considered incomplete.

**5.1 (TDD Cycle)**: Strictly adhere to the "Red-Green-Refactor" cycle.
**5.2 (Mandatory Testing Framework)**: All new unit tests **must** use the **Quick & Nimble** framework to facilitate Behavior-Driven Development (BDD) style testing.
