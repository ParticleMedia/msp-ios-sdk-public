# Quickstart: Fix Unit Test Builds

## Goals
- Regenerate the workspace deterministically.
- Run unit tests without dependency compilation errors.
- Build the demo app without test-only configuration requirements.

## Prerequisites
- Standard project setup completed (dependencies installed, scripts available).

## Steps
1. Regenerate the workspace via the standard target-switching script.
2. Run the unit test suite using the AllTests scheme.
3. Build the demo app target using the default build action.
4. Run the round-trip validation script before commit.

## Expected Results
- All unit test targets compile and run successfully.
- The demo app build succeeds without test-only dependency requirements.
- The validation script completes without errors.
