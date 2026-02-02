# CI Repro Notes

## Failing Run

- URL: https://github.com/ParticleMedia/msp-ios-sdk/actions/runs/21199631917/job/60982523131?pr=384
- Context: Repository refactor caused CI to fail consistently after changes.

## Suspected Failure Vectors (from workflow review)

- **DemoApp path mismatch**: `ci-pull-request.yml` references `DemoApp/` but repo contains `MSPDemoApp/`.
- **Adapter path inconsistencies**:
  - Workflow uses `Adapters/MSPGoogleAdapter` but repo has `MSPGoogleAdapter/` at root and adapters under `Sources/Adapters/`.
  - Workflow uses `Sources/Adapters/LiftoffAdapter`, `Sources/Adapters/InmobiAdapter`, `Sources/Adapters/UnityAdapter` while repo also has top-level adapter directories.
- **Xcode version mismatch across workflows**: `ci-pull-request.yml` uses Xcode 16.4, unit-tests/manual-build/release use 15.2.
- **Tooling assumptions**: unit-tests workflow relies on `jq`, `bc`, and `xcpretty` being available.

## Repro Steps (local)

1. Run `bash setup_ci_cd.sh` and observe any path validation errors.
2. Run `bash Scripts/ci/ci_validate.sh` and ensure it validates required paths/scripts.
3. Run `bash Scripts/tests/run-unit-tests.sh` to ensure it discovers workspace/scheme correctly.
4. Compare paths referenced in workflows against actual repo paths.

## Notes

- CI fixes should prioritize aligning workflow paths to current repo layout and adding clear failure messages.
