# Target Switching

## Modes

### pods-dev

Development mode with source files.

```bash
./Scripts/switch-target.sh pods-dev
```

- All modules compile from source
- Third-party SDKs from CocoaPods
- Default mode for SDK development
- Generates `msp-ios-sdk.xcworkspace`

### pods-release

Pre-release validation mode with binary XCFrameworks.

```bash
./Scripts/switch-target.sh pods-release
```

- Core modules use binary XCFrameworks
- Adapters remain source-only
- Validates XCFramework integrity
- Requires XCFrameworks to be built first

### spm-release

SPM distribution testing mode.

```bash
./Scripts/switch-target.sh spm-release
```

- Core modules via SPM binaryTarget
- Adapters as SPM source targets
- Generates Package.swift from template
- Used for SPM release validation

## Mode Switching Behavior

### What Gets Generated

| Mode | project.yml | workspace.yml | Package.swift |
|------|-------------|---------------|---------------|
| pods-dev | From template | From template | Not used |
| pods-release | From template | From template | Not used |
| spm-release | From template | From template | From template |

### Environment Variables

| Variable | pods-dev | pods-release | spm-release |
|----------|----------|--------------|-------------|
| `MSP_RELEASE` | 0 | 1 | 1 |
| `MSP_MODE` | pods-dev | pods-release | spm-release |
| `TARGET_MODE` | pods-dev | pods-release | spm-release |

## Round-Trip Testing

Validates mode switching consistency:

```bash
./Scripts/target-switching/round-trip-test.sh
```

### Test Sequence

1. Switch to pods-dev, build DemoApp, verify git clean
2. Switch to pods-release, verify generated files, verify git clean
3. Switch to spm-release, verify Package.swift, verify git clean
4. Switch back to pods-dev, build DemoApp, verify git clean

### Options

```bash
# Run multiple cycles
./Scripts/target-switching/round-trip-test.sh --loops=3

# Skip DemoApp builds
./Scripts/target-switching/round-trip-test.sh --skip-build

# Auto-repair failures
./Scripts/target-switching/round-trip-test.sh --fix
```

## Prerequisites

### pods-release / spm-release

Requires core XCFrameworks to be built:

```bash
./Scripts/xcframeworks/build-core.sh
```

Required XCFrameworks:
- MSPSharedLibraries.xcframework
- MSPOMSDK.xcframework
- MSPCore.xcframework
- MSPiOSCore.xcframework
- NovaCore.xcframework

### spm-release

Additionally requires ThirdParty XCFrameworks:

```bash
./Scripts/spm/sync_thirdparty_pods.sh
```

Or run the full SPM sync:

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

## Template Files

All generated files are created from templates:

| Template | Generated |
|----------|-----------|
| `Sources/*/project.yml.template` | `project.yml` |
| `workspace.yml.template` | `workspace.yml` |
| `Package.swift.template` | `Package.swift` |

Templates use placeholders:
- `{{ MODE_PROJECTS }}` - Mode-specific project includes
- `{{ XCFRAMEWORK_PATH }}` - XCFramework location
- `{{ MSP_RELEASE }}` - Binary vs source flag
