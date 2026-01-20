# Research: Fix Unit Test Builds

## Decision 1: Align test dependencies with project platform settings
- **Decision**: Configure test dependencies to match the SDK's supported platform and Swift baseline via shared configuration.
- **Rationale**: Mismatched deployment targets and Swift versions are the most common causes of pod compilation failures in test targets.
- **Alternatives considered**:
  - Manually adjusting build settings per target (rejected: not deterministic and violates automation-first rules).
  - Removing or replacing test frameworks (rejected: conflicts with mandated Quick/Nimble usage).

## Decision 2: Keep demo app build isolated from test-only settings
- **Decision**: Ensure test-only settings remain scoped to test targets and do not alter the demo app build path.
- **Rationale**: The demo app must remain buildable without requiring test dependencies or configuration.
- **Alternatives considered**:
  - Sharing test dependencies across app targets (rejected: increases risk of app build regressions).

## Decision 3: Verify via scripted, reproducible build flow
- **Decision**: Use existing automation scripts to regenerate workspace and validate test + demo app builds.
- **Rationale**: Deterministic builds are required by the constitution; scripted flows minimize manual drift.
- **Alternatives considered**:
  - Running builds manually in Xcode UI (rejected: non-deterministic and not automatable).
