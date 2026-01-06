# Scripts Directory - Complete Guide

Automation scripts for MSP iOS SDK development, testing, and release.

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Directory Structure](#directory-structure)
3. [Release System](#release-system)
   - [Environment Setup](#environment-setup)
   - [Release Workflow](#release-workflow)
   - [Fix Commands](#fix-commands)
4. [Configuration](#configuration)
   - [Environment Variables](#environment-variables)
   - [Slack Notifications](#slack-notifications)
5. [Architecture](#architecture)
6. [Troubleshooting](#troubleshooting)
7. [CI/CD Integration](#cicd-integration)
8. [Before vs After](#before-vs-after)

---

## Quick Reference

### Local Release (Phase B)
```bash
# Profile-based (recommended)
./Scripts/msp-release.sh --profile=production run 0.3.0-rc.6

# Environment variables
DRY_RUN=false MSP_ALLOW_TRUNK_PUSH=1 ./Scripts/msp-release.sh run 0.3.0-rc.6
```

### Rerelease (existing version)
```bash
source Scripts/utils/setup-release-env.sh rerelease
./Scripts/msp-release.sh run 0.3.0-rc.6
```

### Fix Public Tag
```bash
./Scripts/msp-release.sh fix-public-tag 0.3.0-rc.6
```

### Test Mode (no actual push)
```bash
source Scripts/utils/setup-release-env.sh test
./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

## Directory Structure

```
Scripts/
├── msp-release.sh                     # Main release orchestrator
├── switch-target.sh                   # Mode switching (dev/sim)
├── utils/
│   └── setup-release-env.sh          # Environment setup (4 profiles)
├── config/
│   ├── slack.conf.example            # Slack config template
│   ├── slack.conf                    # Local Slack config (gitignored)
│   └── release.yaml                  # Release configuration
├── release/                           # Release system
│   ├── orchestrator/                 # Release coordination
│   ├── publish/                      # Publishing (CocoaPods, SPM)
│   ├── utils/                        # Utilities
│   └── verify*/                      # Verification systems
├── xcframeworks/                      # XCFramework build
├── spm/                              # SPM management
├── target-switching/                 # Target switching logic
└── notify/                           # Notification helpers
```

---

## Release System

### Environment Setup

The release system has been simplified from **11 variables → 3 variables** for local release.

#### Method 1: Setup Script (Recommended)

**4 Configuration Profiles**:

```bash
# Profile 1: local-dev - Local development (Phase B)
./Scripts/msp-release.sh --profile=local-dev run 0.3.0-rc.6
# Sets: DRY_RUN=true (no actual publishing)

# Profile 2: production - Production release (Phase B)
./Scripts/msp-release.sh --profile=production run 0.3.0-rc.6
# Sets: DRY_RUN=false (full publishing)

# Profile 3: ci-test - CI/CD testing (Phase B)
./Scripts/msp-release.sh --profile=ci-test run 0.3.0-rc.6
# Sets: DRY_RUN=true (validation only)

# Profile 4: quick-test - Quick test (Phase B)
./Scripts/msp-release.sh --profile=quick-test run 0.3.0-rc.6
# Sets: DRY_RUN=true (minimal validation)
```

**Usage**:
```bash
# Choose a profile based on your needs
source Scripts/utils/setup-release-env.sh <profile>

# Then run release
./Scripts/msp-release.sh run <version>
```

#### Method 2: direnv (Auto-load)

**One-time setup**:
```bash
# Install direnv (if not installed)
brew install direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# Setup project
cp .envrc.example .envrc
direnv allow
```

**Usage**:
```bash
# Environment loads automatically when you cd into project
cd msp-ios-sdk
# ✅ MSP Release environment loaded (direnv)
#    Release tier: release
#    Local release: enabled
#    Trunk push: enabled

./Scripts/msp-release.sh run 0.3.0-rc.6
```

#### Method 3: Manual Export (Phase B)

```bash
# Option 1: Profile-based (recommended)
./Scripts/msp-release.sh --profile=production run 0.3.0-rc.6

# Option 2: Environment variables
DRY_RUN=false MSP_ALLOW_TRUNK_PUSH=1 ./Scripts/msp-release.sh run 0.3.0-rc.6

./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

### Release Workflow

#### Step 1: Setup Environment
```bash
source Scripts/utils/setup-release-env.sh local
```

#### Step 2: Run Release
```bash
./Scripts/msp-release.sh run 0.3.0-rc.6
```

**What happens during release**:

1. **Pre-flight Checks**
   - Verify Git status (clean working tree)
   - Check current branch
   - Validate version format
   - Verify CocoaPods Trunk authentication

2. **Build Phase**
   - Build XCFrameworks for core modules
   - Generate distribution artifacts
   - Create ZIP archives for GitHub Release

3. **Tag & Push**
   - Create Git tag locally
   - Push tag to origin remote
   - Push tag to public remote (with GitHub Push Protection handling)
   - **Verify tag SHA** between local and public remote

4. **GitHub Release**
   - Create GitHub Release
   - Upload XCFramework ZIPs
   - Generate release notes

5. **CocoaPods Publishing**
   - Generate release podspecs
   - Push to CocoaPods Trunk (7 pods)
   - Wait for CDN sync

6. **Verification**
   - Remote integration tests
   - CocoaPods installation tests
   - SPM installation tests

7. **Notifications**
   - Send Slack success notification
   - Include release summary and metrics

**Typical Duration**: 30-60 minutes (includes CDN sync wait time)

#### Step 3: Verify Release

```bash
# Check CocoaPods
for pod in MSPCore NovaAdapter MSPPrebidAdapter MSPGoogleAdapter MSPFacebookAdapter AmazonAdapter; do
  echo "=== $pod ==="
  pod trunk info "$pod" | grep "0.3.0-rc.6"
done

# Check GitHub Release
gh release view 0.3.0-rc.6

# Check SPM
swift package resolve
```

---

### Fix Commands

#### fix-public-tag

**Purpose**: Fix tag SHA mismatch between local and public remote.

**When to use**:
- GitHub Push Protection blocks tag push to public remote
- Tag SHA verification fails (local SHA ≠ public SHA)
- Need to rerelease after fixing issues

**Usage**:
```bash
./Scripts/msp-release.sh fix-public-tag <version>
```

**Example**:
```bash
./Scripts/msp-release.sh fix-public-tag 0.3.0-rc.6
```

**What it does**:
1. Verifies tag exists locally
2. Checks current public remote tag SHA
3. Deletes old tag from public remote (if exists)
4. Pushes correct tag from local to public remote
5. Verifies SHA matches between local and public

**Common Scenario**:
```bash
# Scenario: GitHub Push Protection blocked the tag push
# Result: Tag exists on origin but not on public, or points to wrong commit

# Step 1: Visit the GitHub URL shown in error message
# Step 2: Click "Allow this secret" or fix the secret issue
# Step 3: Run fix command
./Scripts/msp-release.sh fix-public-tag 0.3.0-rc.6

# Step 4: Continue release (if not completed)
./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

## Configuration

### Environment Variables

#### Core Variables (Required)

| Variable | Local | CI | Default | Description |
|----------|-------|----|---------|-------------|
| ~~`MSP_RELEASE_TIER`~~ | ~~✅~~ | ~~✅~~ | ~~`preflight`~~ | **REMOVED in Phase B** |
| `DRY_RUN` | ✅ | ✅ | `true` | Skip publish steps when true |
| `MSP_ALLOW_TRUNK_PUSH` | ✅ | ✅ | `0` | Allow push to CocoaPods Trunk |

**For local release** (Phase B), you need **2 variables**:
```bash
DRY_RUN=false
MSP_ALLOW_TRUNK_PUSH=1
```

**For CI release** (Phase B), you need **2 variables**:
```bash
DRY_RUN=false
MSP_ALLOW_TRUNK_PUSH=1
```

**Or use profile-based configuration** (recommended):
```bash
./Scripts/msp-release.sh --profile=production run 0.3.0-rc.6
```

#### Optional Variables

| Variable | Use Case | Default | Description |
|----------|----------|---------|-------------|
| `MSP_ALLOW_EXISTING_TAG` | Rerelease | `0` | Allow overwriting existing tags |
| `MSP_SLACK_ALERT_ENV` | Slack notifications | `prod` | Slack environment: `test` or `prod` |
| `SLACK_WEBHOOK_URL` | Slack notifications | From `slack.conf` | Slack webhook URL |

#### Variables You DON'T Need

| Variable | Why Not Needed |
|----------|----------------|
| `CI` | Automatically set by CI environment |
| `GITHUB_ACTIONS` | Automatically set by GitHub Actions |
| `SLACK_BOT_TOKEN` | Only needed for DMs (rare use case) |
| `MSP_SLACK_DM_OVERRIDE` | Only needed for DMs (rare use case) |
| ~~`MSP_ALLOW_PUBLIC_PUSH_FAILURE`~~ | **Never use** - causes tag inconsistency issues |

---

### Slack Notifications

Slack notifications inform your team about release progress and results.

#### Option 1: Local Config File (Recommended for Development)

**Setup**:
```bash
# Copy template
cp Scripts/config/slack.conf.example Scripts/config/slack.conf

# Edit and fill in your credentials
vim Scripts/config/slack.conf
```

**File structure** (`Scripts/config/slack.conf`):
```bash
# Basic Configuration (required)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Optional: Environment mode
MSP_SLACK_ALERT_ENV=test  # or "prod"

# Advanced: For DMs (rarely needed)
# SLACK_BOT_TOKEN=xoxb-...
# MSP_SLACK_DM_OVERRIDE=U0910UJPD7B
# MSP_SLACK_TEST_WEBHOOK=https://hooks.slack.com/services/...
```

**Advantages**:
- ✅ Credentials stored locally (gitignored)
- ✅ No need to export environment variables
- ✅ Easy to switch between test/prod modes

#### Option 2: Environment Variables (Recommended for CI)

**Setup**:
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export MSP_SLACK_ALERT_ENV="test"  # or "prod"
```

**Advantages**:
- ✅ No local files needed
- ✅ Easy to manage in CI/CD secrets
- ✅ Explicit and auditable

**GitHub Actions Example**:
```yaml
- name: Release
  env:
    DRY_RUN: false
    MSP_ALLOW_TRUNK_PUSH: 1
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
    MSP_SLACK_ALERT_ENV: prod
  run: |
    ./Scripts/msp-release.sh run ${{ inputs.version }}
```

#### Getting Slack Credentials

**1. Webhook URL** (for channel notifications):
- Go to https://api.slack.com/apps
- Select your app → **Incoming Webhooks**
- Click **Add New Webhook to Workspace**
- Choose channel → Copy webhook URL

**2. Bot Token** (only for DMs - rarely needed):
- Go to your app → **OAuth & Permissions**
- Copy **Bot User OAuth Token** (starts with `xoxb-`)

**3. User ID** (for DMs - rarely needed):
- Right-click user in Slack → **View Profile**
- Click **More** → **Copy member ID**

#### Test Mode vs Production

**Test Mode** (`MSP_SLACK_ALERT_ENV=test`):
- Uses `MSP_SLACK_TEST_WEBHOOK`
- Safe for development and testing
- Won't spam production channels
- Good for experimenting

**Production Mode** (`MSP_SLACK_ALERT_ENV=prod`):
- Uses `SLACK_WEBHOOK_URL`
- Sends to production release channel
- Use for actual releases

**Recommendation**: Always use test mode when developing or testing release scripts.

---

## Architecture

### Release System Overview

The release system is modular and consists of several layers:

```
┌─────────────────────────────────────────────────────────────┐
│                   msp-release.sh (Orchestrator)              │
│  - Main entry point                                          │
│  - Command dispatch (run, fix-public-tag)                    │
│  - State management                                          │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ Pre-checks   │      │   Build      │      │  Publish     │
│              │      │              │      │              │
│ - Safety     │      │ - XCFramework│      │ - GitHub     │
│ - Git status │      │ - Artifacts  │      │ - CocoaPods  │
│ - Auth       │      │ - Podspecs   │      │ - Tag push   │
└──────────────┘      └──────────────┘      └──────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │   Verification       │
                  │                      │
                  │ - Remote integration │
                  │ - CocoaPods install  │
                  │ - SPM resolve        │
                  │ - XCFramework deep   │
                  └──────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │   Notifications      │
                  │                      │
                  │ - Slack webhook      │
                  │ - Success/Failure    │
                  │ - Metrics            │
                  └──────────────────────┘
```

### Key Components

#### 1. Orchestrator (`Scripts/msp-release.sh`)
- Main entry point for all release operations
- Command dispatcher (`run`, `fix-public-tag`, etc.)
- State management and resume capability
- Coordinates all subsystems

#### 2. Safety Checks (`Scripts/release/utils/safety.sh`)
- Environment variable validation
- CI vs Local detection
- Tag existence checks
- Branch validation
- **GitHub Push Protection detection**

#### 3. Build System (`Scripts/xcframeworks/`)
- XCFramework compilation for core modules
- Distribution artifact generation
- ZIP archive creation for GitHub Release

#### 4. Publishing (`Scripts/release/publish/`)
- **GitHub Release**: Create release, upload assets
- **CocoaPods Trunk**: Push 7 pods sequentially
- **Git Tags**: Push to origin and public remotes
- **Tag SHA verification**: Ensure consistency

#### 5. Verification (`Scripts/release/verify*/`)
- Remote verification (CocoaPods, SPM)
- Local sandbox verification
- Device verification (real device testing)
- XCFramework deep verification
- Verification matrix (15 scenarios)

#### 6. Notifications (`Scripts/notify/`)
- Slack webhook integration
- Success/failure alerts
- Release metrics and duration

### Key Features

#### GitHub Push Protection Detection
- Detects when GitHub blocks push due to secrets
- Provides clear instructions with URL
- Offers `fix-public-tag` command to resolve

#### Tag SHA Verification
- Compares local tag SHA with public remote tag SHA
- Detects mismatches automatically
- Fails release if tags point to different commits
- Prevents CocoaPods validation errors

#### Idempotency
- Safe to rerun failed releases
- Skips completed steps
- Resumes from last successful point

#### Smart CDN Wait
- Waits for CocoaPods CDN to sync
- Polls until new version is available
- Configurable timeout and retry logic

#### Dry Run Mode
- Test release process without actual publishing
- Set `DRY_RUN=true` environment variable
- Useful for testing and debugging

### Release Modes (Phase B)

- **DRY_RUN=true**: Test mode, no trunk push (default)
- **DRY_RUN=false**: Production mode, full publishing

The unified `DRY_RUN` control simplifies the release process and replaces the old dual-tier system.

---

## Troubleshooting

### Common Issues

#### 1. "Release tier cannot be executed locally"

**Symptom**:
```
❌ Security: Release tier cannot be executed locally without explicit override
```

**Cause**: Missing `MSP_ALLOW_LOCAL_RELEASE=1`

**Solution**:
```bash
export MSP_ALLOW_LOCAL_RELEASE=1
# Or use: source Scripts/utils/setup-release-env.sh local
```

---

#### 2. "trunk push disabled"

**Symptom**:
```
⚠️  CocoaPods trunk push is disabled (MSP_ALLOW_TRUNK_PUSH != 1)
```

**Cause**: Missing `MSP_ALLOW_TRUNK_PUSH=1`

**Solution**:
```bash
export MSP_ALLOW_TRUNK_PUSH=1
```

---

#### 3. "Tag already exists"

**Symptom**:
```
❌ Tag 0.3.0-rc.6 already exists on origin
```

**Cause**: Trying to rerelease without permission

**Solution**:
```bash
# Option 1: Use rerelease profile
source Scripts/utils/setup-release-env.sh rerelease
./Scripts/msp-release.sh run 0.3.0-rc.6

# Option 2: Set variable manually
export MSP_ALLOW_EXISTING_TAG=1
./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

#### 4. GitHub Push Protection Blocks Push

**Symptom**:
```
remote: error: GH013: Repository rule violations found
remote: - Push protection
remote:
remote:   Visit https://github.com/.../security/secret-scanning/...
```

**Cause**: GitHub detected secrets in `slack.conf` or other files

**Solution**:
1. Visit the URL shown in the error message
2. Review the detected secret
3. Click **"Allow this secret"** (if it's a false positive or test secret)
4. Run fix command:
   ```bash
   ./Scripts/msp-release.sh fix-public-tag 0.3.0-rc.6
   ```
5. Continue release:
   ```bash
   ./Scripts/msp-release.sh run 0.3.0-rc.6
   ```

**Prevention**: Ensure `slack.conf` is in `.gitignore` and not committed.

---

#### 5. Tag SHA Mismatch

**Symptom**:
```
❌ Public Remote Tag SHA Mismatch!
   Local tag:  be0d4bef6c2a3d4e5f6a7b8c9d0e1f2a3b4c5d6e
   Public tag: 451cee1c8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d
```

**Cause**:
- GitHub Push Protection blocked the tag push
- Tag was pushed to origin but not to public
- Tags point to different commits

**Impact**:
- CocoaPods validation will fail
- Users will download wrong version

**Solution**:
```bash
./Scripts/msp-release.sh fix-public-tag 0.3.0-rc.6
```

This will delete the old tag from public remote and push the correct one.

---

#### 6. CocoaPods Validation Failed

**Symptom**:
```
ERROR | [iOS] file patterns: The 'source_files' pattern did not match any file.
```

**Possible Causes**:
- Tag points to wrong commit
- Public remote tag SHA mismatch
- Podspec configuration error

**Solution**:
1. Verify tag SHA:
   ```bash
   git ls-remote --tags public 0.3.0-rc.6
   git ls-remote --tags origin 0.3.0-rc.6
   git show-ref --tags 0.3.0-rc.6
   ```

2. If SHA mismatch, fix it:
   ```bash
   ./Scripts/msp-release.sh fix-public-tag 0.3.0-rc.6
   ```

3. Rerun release:
   ```bash
   ./Scripts/msp-release.sh run 0.3.0-rc.6
   ```

---

#### 7. Slack Notifications Not Working

**Symptom**: Release completes but no Slack notification received

**Possible Causes**:
- Missing `SLACK_WEBHOOK_URL`
- Wrong webhook URL
- Slack app not installed
- Network issue

**Solution**:
1. Verify webhook URL:
   ```bash
   # If using slack.conf
   grep SLACK_WEBHOOK_URL Scripts/config/slack.conf

   # If using environment variable
   echo $SLACK_WEBHOOK_URL
   ```

2. Test webhook manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test message"}' \
     "$SLACK_WEBHOOK_URL"
   ```

3. Check Slack app permissions in https://api.slack.com/apps

---

### Debug Commands

```bash
# Check environment variables
env | grep MSP

# Verify Git tags
git ls-remote --tags public <version>
git ls-remote --tags origin <version>
git show-ref --tags <version>

# Check CocoaPods status
pod trunk info MSPCore
pod search MSPCore

# View release logs
tail -f /tmp/msp-release-final.log

# Test Slack notification
source Scripts/notify/slack.sh
notify_release_success "Test" "0.3.0-rc.6" "MSPCore" "10s" ""
```

---

## CI/CD Integration

### GitHub Actions

**Example Workflow**:
```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g., 0.3.0-rc.6)'
        required: true
        type: string

jobs:
  release:
    runs-on: macos-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'

      - name: Install CocoaPods
        run: gem install cocoapods

      - name: Authenticate CocoaPods
        env:
          COCOAPODS_TRUNK_TOKEN: ${{ secrets.COCOAPODS_TRUNK_TOKEN }}
        run: |
          echo "machine trunk.cocoapods.org" > ~/.netrc
          echo "  login $(pod trunk me --verbose | grep 'Email:' | awk '{print $2}')" >> ~/.netrc
          echo "  password $COCOAPODS_TRUNK_TOKEN" >> ~/.netrc

      - name: Release
        env:
          DRY_RUN: false
          MSP_ALLOW_TRUNK_PUSH: 1
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          MSP_SLACK_ALERT_ENV: prod
        run: |
          ./Scripts/msp-release.sh run ${{ inputs.version }}
```

**Required Secrets**:
- `COCOAPODS_TRUNK_TOKEN` - CocoaPods authentication token
- `SLACK_WEBHOOK_URL` - Slack webhook URL for notifications

---

## Before vs After

### Configuration Complexity

| Aspect | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Variables (Local)** | 11 | 3 | -73% |
| **Variables (CI)** | 9 | 2 | -78% |
| **Setup Time** | ~2 min | ~5 sec | -96% |
| **Setup Commands** | 11 lines | 1 line | -91% |

### Setup Comparison

**Before** (11 variables, error-prone):
```bash
export CI=true
export GITHUB_ACTIONS=true
export MSP_RELEASE_TIER=release  # ❌ Deprecated in Phase B
export MSP_ALLOW_EXISTING_TAG=1
export MSP_ALLOW_LOCAL_RELEASE=1
export MSP_ALLOW_PUBLIC_PUSH_FAILURE=1  # ❌ Causes issues
export MSP_ALLOW_TRUNK_PUSH=1
export SLACK_BOT_TOKEN="xoxb-..."
export MSP_SLACK_DM_OVERRIDE=U0910UJPD7B
export MSP_SLACK_ALERT_ENV=test
export MSP_SLACK_TEST_WEBHOOK="https://..."

./Scripts/msp-release.sh run 0.3.0-rc.6
```

**After** (1 command, simple):
```bash
source Scripts/utils/setup-release-env.sh local
./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

## Additional Resources

- **Main README**: [../README.md](../README.md) - Project overview and architecture
- **Config Templates**:
  - `.envrc.example` - direnv auto-load template
  - `config/slack.conf.example` - Slack configuration template
- **Setup Script**: `utils/setup-release-env.sh` - Environment setup profiles

---

## History & Changes

- **Phase 2** (2025-12-23):
  - GitHub Push Protection detection and handling
  - Tag SHA verification between local and public remotes
  - New `fix-public-tag` command for tag mismatch resolution

- **Phase 3** (2025-12-23):
  - Remove hardcoded secrets from `slack.conf`
  - Add `slack.conf.example` template
  - Environment variable priority system

- **Phase 4** (2025-12-23):
  - Simplify environment variables (11→3 for local, 9→2 for CI)
  - Create configuration profiles (local, ci, rerelease, test)
  - Add direnv support for auto-loading
  - Complete environment variable documentation

---

**For questions or issues**, check the [Troubleshooting](#troubleshooting) section or review release logs at `/tmp/msp-release-final.log`.
