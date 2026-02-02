# Scripts Directory

Automation scripts for MSP iOS SDK development, testing, and release.

## Directory Structure

```
Scripts/
├── msp-release.sh              # Main release orchestrator
├── switch-target.sh            # Mode switching (pods-dev/pods-release/spm-release)
├── resume-smart.sh             # Smart resume for interrupted releases
├── tools/                      # Shared automation tools (for all AI agents)
│   ├── get-test-template.sh    # Print unit test template
│   └── validate-script.sh      # Validate script with shellcheck
├── templates/                  # Shared templates
│   └── release-notes-template.md
├── release/
│   ├── orchestrator/           # Release coordination
│   │   └── modular.sh          # Modular release workflow
│   ├── publish/
│   │   ├── pods/publish.sh     # CocoaPods publishing
│   │   └── spm/publish.sh      # SPM publishing
│   ├── config/
│   │   ├── release.yaml        # Active release config
│   │   └── release.yaml.template
│   ├── utils/                  # Shared utilities
│   ├── verify*/                # Verification systems
│   └── verify-matrix/          # Multi-target verification
├── target-switching/           # Mode switching internals
│   ├── common.sh               # Shared constants
│   ├── round-trip-test.sh      # Mode switching validation
│   └── *.sh                    # Helper scripts
├── xcframeworks/               # XCFramework build scripts
│   ├── build-core.sh           # Build core XCFrameworks
│   ├── build-adapters.sh       # Build adapter XCFrameworks
│   └── build-thirdparty.sh     # Build third-party XCFrameworks
├── spm/                        # SPM management
├── spm-sync/                   # Pods to SPM sync
│   └── spm_sync_all.sh         # Sync all dependencies
├── lib/                        # Shared libraries
├── notify/                     # Slack notifications
└── config/                     # Configuration files
```

## CI Scripts and Config (GitHub Actions)

CI workflows call scripts in `Scripts/ci/` and use config in `Scripts/config/`:

- Scripts
  - `ensure-xcodegen.sh` - install/check XcodeGen
  - `lint-podspecs.sh` - lint podspecs (quick)
  - `validate-shell-syntax.sh` - bash syntax check
  - `install-pods.sh` - CocoaPods install (fallback + repo-update)
  - `verify-xcframework.sh` - verify single XCFramework exists
  - `verify-xcframework-deps.sh` - verify stage dependencies
  - `validate-workspace-schemes.sh` - verify workspace schemes
  - `prebuild-pod-deps.sh` - prebuild Pod schemes
  - `generate-workspace.sh` - generate workspace + DemoApp project

- Config
  - `ci-build-stages.yml` - stage module order + adapter mapping
  - `ci-framework-deps.yml` - required XCFrameworks per stage
  - `ci-pod-schemes.yml` - required/prebuilt Pod schemes

## Release System Architecture

### Entrypoints

| Script | Purpose |
|--------|---------|
| `msp-release.sh` | Main release orchestrator with subcommands |
| `switch-target.sh` | Switch between development modes |

### Subcommands

```bash
./Scripts/msp-release.sh <subcommand> [options]
```

| Subcommand | Description |
|------------|-------------|
| `run <version>` | Execute full release |
| `resume` | Resume interrupted release from state file |
| `fix-public-tag <version>` | Push tag to public remote after GitHub Push Protection skip |
| `verify` | Run verification suite |
| `verify-matrix` | Run multi-target verification |
| `rollback` | Rollback failed release |
| `preflight` | Run pre-release checks only |
| `pods <version>` | CocoaPods-only release |
| `spm <version>` | SPM-only release |

### Release Flow

```
msp-release.sh run
    │
    ├── Preflight checks (git, branch, version)
    │
    ├── Build XCFrameworks
    │   └── Scripts/xcframeworks/build-core.sh
    │
    ├── Tag & Push
    │   ├── Create local tag
    │   ├── Push to origin
    │   └── Push to public (with Push Protection handling)
    │
    ├── GitHub Release
    │   ├── Create release
    │   └── Upload XCFramework ZIPs
    │
    ├── CocoaPods Publishing
    │   ├── Generate podspecs
    │   └── Push to Trunk
    │
    └── Verification
        └── Remote integration tests
```

### Release Artifacts (Canonical Paths)

All build outputs are consolidated under:

```
Build/ReleaseArtifacts/
├── XCFrameworks/   # Built XCFrameworks (core/adapters/third-party)
├── Archives/       # Xcode archives
├── Binary/         # Release staging (Binary/ inside pod zip)
└── Zips/           # Release zip outputs
```

Legacy paths (compat only):
None. `Build/ReleaseArtifacts/` is the single source of truth.

## TODO

- Re-enable post-release verification steps (local/remote/device/XCF) once SPM local build issues are resolved. Currently disabled by default via `MSP_DISABLE_POST_VERIFICATION=1`.
- Re-enable SPM 本地构建验证（`spm_local_validation`）逻辑并移除 `SKIP_SPM_LOCAL_VALIDATION`/`MSP_SKIP_SPM_LOCAL_BUILD` 的默认跳过，待 SPM 发布恢复稳定后再执行真实本地验证。
- Add a documented verification profile or flag to toggle post-release checks without touching preflight.
- Re-enable CI-only restriction for production releases when CI pipeline is ready (`Scripts/release/utils/safety.sh`).

## Advanced Commands

### Verify Matrix

Run verification across multiple configurations:

```bash
./Scripts/msp-release.sh verify-matrix
```

### Round-Trip Test

Validate mode switching consistency:

```bash
./Scripts/target-switching/round-trip-test.sh
./Scripts/target-switching/round-trip-test.sh --loops=3
./Scripts/target-switching/round-trip-test.sh --skip-build
```

### Build XCFrameworks

```bash
# Build core modules
./Scripts/xcframeworks/build-core.sh

# Build adapters
./Scripts/xcframeworks/build-adapters.sh

# Build third-party
./Scripts/xcframeworks/build-thirdparty.sh
```

### SPM Sync

```bash
# Sync all third-party from Pods to SPM
./Scripts/spm-sync/spm_sync_all.sh

# Sync ThirdParty XCFrameworks from Pods
./Scripts/spm/sync_thirdparty_pods.sh
```

## Control Flow

### State Management

Release state is persisted to `.msp-release-state.json` for resume capability:

- Step completion tracking
- Pod publishing progress
- Error recovery points

### DRY_RUN Behavior

When `DRY_RUN=true`:
- Git operations execute but don't push
- CocoaPods Trunk push is skipped
- GitHub Release creation is skipped
- All validation still runs

### Profile System

Profiles configure release behavior:

| Profile | DRY_RUN | MSP_ALLOW_TRUNK_PUSH |
|---------|---------|---------------------|
| `production` | false | 1 |
| `local-dev` | true | 0 |
| `ci-test` | true | 0 |
| `quick-test` | true | 0 |

## Script Dependencies

Required tools:
- `xcodegen` - Xcode project generation
- `cocoapods` - Pod management
- `gh` - GitHub CLI (for releases)
- `jq` - JSON processing
- `shellcheck` - Shell script validation (for tools/)

## Shared Tools (AI Agents)

The `tools/` directory contains scripts shared across all AI agents (Claude, Cursor, Copilot, Codex).

| Tool | Usage | Description |
|------|-------|-------------|
| `get-test-template.sh` | `./Scripts/tools/get-test-template.sh` | Print Quick/Nimble unit test template |
| `validate-script.sh` | `./Scripts/tools/validate-script.sh <path>` | Validate shell script with shellcheck |

### Usage Example

```bash
# Get test template
./Scripts/tools/get-test-template.sh

# Validate a script
./Scripts/tools/validate-script.sh Scripts/msp-release.sh
```

### Adding New Tools

1. Create script in `Scripts/tools/`
2. Add `set -euo pipefail` at the top
3. Make executable: `chmod +x Scripts/tools/<name>.sh`
4. Document in `AGENTS.md` Section 3.1
5. (Optional) Create Claude wrapper in `.claude/tools/`

See also: [Docs/AI_AGENTS.md](../Docs/AI_AGENTS.md) for full AI agent architecture.
