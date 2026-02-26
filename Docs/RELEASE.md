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
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-pods
```

CocoaPods CDN availability is checked automatically. If a pod is not yet synced, the system waits up to 60 minutes before failing.

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
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-pods
```

### resume

Resume an interrupted release from the last successful step:

```bash
./Scripts/msp-release.sh resume
```

State is persisted to `.msp-release-state.json`. Resume intelligently retries failed operations:
- ✅ **Trunk verification** - Re-verifies if `trunk_verified=false`
- ✅ **GitHub Release creation** - Re-creates if `github_release_created=false`
- ✅ **Idempotent** - Skips already-successful operations

### create-github-releases

Create or verify GitHub Releases for all binary distribution pods (补偿命令):

```bash
./Scripts/msp-release.sh create-github-releases <version>
```

Use this when:
- GitHub Releases were not created during normal release flow
- Some pods are missing GitHub Release assets
- You need to verify all binary pods have proper releases

This command:
1. Checks state file for each pod's `github_release_created` status
2. Skips pods that already have releases
3. Creates missing GitHub Releases with zip uploads
4. Updates state file with results

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

## GitHub Release Workflow

### Automatic Creation

During normal release flow, GitHub Releases are created automatically for each binary distribution pod:

```
1. Build XCFramework
2. Create ZIP archive
3. create_github_release_for_pod()
   ├─ Create/verify GitHub Release
   ├─ Upload ZIP to release assets
   ├─ Wait for CDN propagation (60-120s based on file size)
   ├─ Verify ZIP is accessible via CDN
   └─ ✨ Update state: github_release_created=true
4. Unified verification (after all pods published)
   └─ verify_all_github_releases() checks all binary pods
```

### Binary Distribution Pods

These pods require GitHub Releases (use HTTP distribution in podspec):

- MSPiOSCore
- MSPSharedLibraries
- MSPGoogleAdsTypes
- MSPPrebidAdapter
- MSPFacebookAdapter
- MSPNovaAdapter
- MSPAmazonAdapter
- MSPGoogleAdapter
- MSPMolocoAdapter
- MSPLiftoffAdapter
- MSPCore

### Troubleshooting

**Scenario 1: GitHub Release creation failed during release**

If some pods published but GitHub Releases weren't created:

```bash
# Check state file
cat .msp-release-state.json | jq '.pods[] | select(.github_release_created == false)'

# Retry creation
./Scripts/msp-release.sh create-github-releases 1.0.4-rc.10
```

**Scenario 2: Resume after GitHub Release failure**

```bash
# Resume will automatically retry failed GitHub Release creation
./Scripts/msp-release.sh resume
```

The system checks `github_release_created` status and retries if `false`.

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

Pods are published in dependency order (11 pods, all binary distribution):

```
Step 0: MSPiOSCore                (foundation, no dependencies)
Step 1: MSPSharedLibraries        (parallel)
        MSPGoogleAdsTypes         (parallel)
Step 2: Adapters (all parallel):
        MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter,
        MSPNovaAdapter, MSPAmazonAdapter, MSPMolocoAdapter, MSPLiftoffAdapter
Step 3: MSPCore                   (depends on all above)
```

## State Management

Release state is persisted to `.msp-release-state.json`:

### State Schema (v3)

```json
{
  "schema_version": 3,
  "version": "1.0.4-rc.10",
  "release_mode": "full",
  "base_branch": "main",
  "release_branch": "release/1.0.4-rc.10",
  "resume_count": 0,
  "git": {
    "tag_created": true,
    "tag_name": "1.0.4-rc.10",
    "release_branch_pushed": true,
    "github_release_created": true
  },
  "pods": {
    "MSPCore": {
      "status": "published",
      "trunk_verified": true,
      "trunk_verified_at": "2026-02-16T09:13:50Z",
      "github_release_created": true,
      "github_release_url": "https://github.com/ParticleMedia/msp-ios-sdk-public/releases/tag/1.0.4-rc.10",
      "github_release_verified_at": "2026-02-16T09:15:00Z"
    }
  },
  "timestamps": {
    "started_at": "2026-02-16T09:00:00Z",
    "updated_at": "2026-02-16T09:15:00Z"
  }
}
```

### Per-Pod State Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | `published`, `failed`, `pending`, `inconsistent` |
| `trunk_verified` | boolean | CocoaPods Trunk verification status |
| `trunk_verified_at` | ISO8601 | Verification timestamp |
| `github_release_created` | boolean | ✨ **v3** GitHub Release creation status |
| `github_release_url` | string | ✨ **v3** Release URL |
| `github_release_verified_at` | ISO8601 | ✨ **v3** Verification timestamp |

### Resume Behavior

When resuming, the system checks each pod's state and:
1. **If `trunk_verified=false`** → Re-verify trunk availability
2. **If `github_release_created=false`** → Re-create GitHub Release
3. **If `status=failed`** → Retry publication
4. **If already successful** → Skip (idempotent)

This enables:
- ✅ Resume after failure
- ✅ Idempotent re-runs
- ✅ Per-pod progress tracking
- ✅ Intelligent retry logic
