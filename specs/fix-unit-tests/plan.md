# Implementation Plan: Fix Unit Test Builds

**Branch**: `fix-unit-tests` | **Date**: 2026-01-20 | **Spec**: `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/spec.md`
**Input**: Feature specification from `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable all unit test targets to compile and run without dependency-related errors while keeping the demo app build clean. The plan focuses on aligning dependency configuration, platform settings, and build scripts to produce deterministic local and CI builds.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.x (project baseline is Swift 5.0)  
**Primary Dependencies**: CocoaPods, Quick, Nimble, OHHTTPStubs, XcodeGen  
**Storage**: N/A  
**Testing**: Quick + Nimble, OHHTTPStubs  
**Target Platform**: iOS 15+  
**Project Type**: mobile SDK + demo app  
**Performance Goals**: Unit test workflow completes in under 20 minutes on CI  
**Constraints**: Deterministic builds; no manual Xcode project edits; Podfile is SSOT for dependency versions; no manual workarounds for build issues  
**Scale/Scope**: 4 unit test targets plus demo app build

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **PASS**: `constitution.md` Article I.2 - No direct `.xcodeproj` or `.xcworkspace` edits; use templates and XcodeGen.
- **PASS**: `constitution.md` Article I.3 - Podfile remains the single source of truth for dependency versions.
- **PASS**: `constitution.md` Article I.4 - Fix root causes in scripts/config; no manual workarounds.
- **PASS**: `constitution.md` Article II.2 - Plan includes running `./Scripts/target-switching/round-trip-test.sh` before commit.
- **PASS**: `Sources/constitution.md` Article V - If production code changes, add/adjust Quick+Nimble tests first (Red-Green-Refactor).
- **PASS**: `Tests/constitution.md` Article VIII - Keep tests in describe/context/it with clear Nimble assertions.
- **PASS**: `Scripts/constitution.md` Article VI - Script edits remain POSIX-compliant and fail fast.

**Post-Design Check**: PASS (no design artifacts introduce constitutional violations).

## Project Structure

### Documentation (this feature)

```text
/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Sources/
├── MSPCore/
├── MSPiOSCore/
├── NovaCore/
└── Adapters/

/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Tests/
├── MSPCoreTests/
├── MSPiOSCoreTests/
├── NovaCoreTests/
└── AdapterTests/

/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Scripts/
└── target-switching/

/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/Examples/
└── [demo app]
```

**Structure Decision**: Use the existing SDK + demo app layout under `Sources/`, `Tests/`, and `Examples/`, with build orchestration in `Scripts/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations identified.

## Phase 0: Outline & Research

- Populate `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/research.md` with decisions and rationale around dependency alignment, demo app isolation, and scripted validation.
- Confirm no open unknowns remain in Technical Context.

## Phase 1: Design & Contracts

- Populate `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/data-model.md` with entities and validation rules from the spec.
- Create `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/contracts/README.md` to document that no external API contracts are required.
- Create `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/specs/fix-unit-tests/quickstart.md` with deterministic steps to regenerate workspace, run tests, build demo app, and run validation.
- Run `/Users/pengyu.gou@newsbreak.com/Downloads/WorkSpace/msp-ios-sdk/.specify/scripts/bash/update-agent-context.sh codex`.
- Re-check Constitution gates after design artifacts are created.

## Phase 2: Planning

- Identify implementation tasks for dependency alignment, script adjustments, and CI validation updates.
- Ensure tasks include deterministic verification steps for local and CI execution.
