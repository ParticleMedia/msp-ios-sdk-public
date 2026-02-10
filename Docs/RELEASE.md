# Release System

## Lifecycle

### Full Release Flow

```
1. Preflight
   ├── Git status check (clean working tree)
   ├── Branch validation
   ├── Version format validation
   └── CocoaPods Trunk authentication

2. Build
   ├── Build core XCFrameworks
   ├── Build adapter XCFrameworks
   └── Create ZIP archives

3. Git Operations
   ├── Create version tag locally
   ├── Push to origin remote
   └── Push to public remote

4. GitHub Release
   ├── Create release
   ├── Upload XCFramework ZIPs
   └── Generate release notes

5. CocoaPods Publishing
   ├── Generate release podspecs
   ├── Push to Trunk (in dependency order)
   └── Wait for CDN sync

6. Verification
   ├── Remote pod installation test
   └── Build verification
```

## Profiles

| Profile | DRY_RUN | Trunk Push | Use Case |
|---------|---------|------------|----------|
| `production` | false | Yes | Official releases |
| `local-dev` | true | No | Local development testing |
| `ci-test` | true | No | CI/CD validation |
| `quick-test` | true | No | Minimal validation |

### Usage

```bash
./Scripts/msp-release.sh --profile=production run 1.0.0
./Scripts/msp-release.sh --profile=local-dev run 1.0.0
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-pods --pod-wait-choice 1
```

`--pod-wait-choice` can preselect CocoaPods availability handling when CDN sync is delayed:
- `1`: continue waiting (recommended)
- `2`: proceed anyway
- `3`: exit

## DRY_RUN Semantics

When `DRY_RUN=true`:
- Git commands execute locally but skip remote push
- `pod trunk push` is skipped
- GitHub Release creation is skipped
- All validation and verification steps still run
- State file is still updated

When `DRY_RUN=false`:
- All operations execute fully
- Tags are pushed to remotes
- Pods are pushed to Trunk
- GitHub Release is created

## Commands

### run

Execute a full release:

```bash
./Scripts/msp-release.sh run <version>
./Scripts/msp-release.sh --profile=production run 1.0.0
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-pods --pod-wait-choice 1
```

### resume

Resume an interrupted release from the last successful step:

```bash
./Scripts/msp-release.sh resume
```

State is persisted to `.msp-release-state.json`.

### fix-public-tag

Push a tag to the public remote after GitHub Push Protection blocks initial push:

```bash
./Scripts/msp-release.sh fix-public-tag <version>
```

This command:
1. Verifies tag exists locally
2. Verifies tag exists on origin
3. Force-pushes tag to public remote
4. Verifies SHA match across all remotes

## Safety Invariants

### Branch Requirements

- Production releases require `main` or `release/*` branch
- Feature branches allowed for testing with appropriate profile

### Tag Verification

After tagging, the system verifies:
- Tag exists locally
- Tag SHA matches on origin
- Tag SHA matches on public remote

### Pod Order

Pods are published in dependency order:
1. MSPSharedLibraries (no dependencies)
2. MSPOMSDK
3. MSPCore
4. MSPiOSCore
5. NovaCore
6. MSPGoogleAdsTypes
7. Adapters (alphabetical)

## State Management

Release state is persisted to `.msp-release-state.json`:

```json
{
  "version": "1.0.0",
  "step": "publish_pods",
  "completed_steps": ["preflight", "build", "tag"],
  "pods_published": ["MSPSharedLibraries", "MSPCore"],
  "started_at": "2024-01-01T00:00:00Z"
}
```

This enables:
- Resume after failure
- Idempotent re-runs
- Progress tracking
