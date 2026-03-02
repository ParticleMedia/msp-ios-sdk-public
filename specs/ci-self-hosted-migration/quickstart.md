# Quickstart: CI Self-Hosted Runner Migration

## What Changed

The CI pipeline migrated from 11 GitHub-hosted macOS jobs (1224 lines YAML) to 2 self-hosted jobs (43 lines YAML) running on the Beijing ARM64 runner.

## New Files

| File | Purpose |
|------|---------|
| `.github/workflows/ci.yml` | Workflow definition (2 jobs, ~43 lines) |
| `Scripts/ci/ci-validate-quick.sh` | Quick validation (lint, syntax, tests) |
| `Scripts/ci/ci-pipeline.sh` | Full build + test pipeline |

## How It Works

```
PR opened/pushed
  └─> validate job (~5 min)
       ├── Shell syntax check
       ├── YAML config validation
       ├── Asset verification
       ├── Test case validation
       ├── Bash unit tests
       ├── Bash integration tests
       ├── Podspec lint
       └── Swift package resolve
  └─> build-and-test job (~40 min, after validate passes)
       ├── Environment validation
       ├── Workspace generation + Pod install
       ├── Pre-build Pod dependencies
       ├── Build all XCFrameworks (11 modules from release.yaml)
       ├── Build DemoApp (non-critical)
       ├── Consistency check (non-critical)
       └── Unit tests + coverage
```

## Local Testing

Run the scripts locally to debug issues:

```bash
# Quick validation only
bash Scripts/ci/ci-validate-quick.sh

# Full pipeline
bash Scripts/ci/ci-pipeline.sh
```

## Runner Requirements

The Beijing self-hosted runner (`bj_ios`) needs:
- macOS 15.x, Xcode 16.4, Ruby 3.1+
- CocoaPods, XcodeGen, Python 3, jq
- GitHub Actions Runner with labels: `self-hosted, macOS, ARM64, bj_ios`

## Adding a New Validation Step

Edit `Scripts/ci/ci-validate-quick.sh` — add a new function and call it via `run_step`:

```bash
validate_my_check() {
    # your validation logic
}

run_step "My new check" validate_my_check || true
```

No workflow YAML changes needed.

## Adding a New Module

Add the module to `Scripts/config/release.yaml` under `pods.modules`. The CI pipeline reads this list at runtime — no CI configuration changes needed.
