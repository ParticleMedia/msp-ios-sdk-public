# Environment Variables Guide

## Overview

MSP iOS SDK release system requires minimal environment variable configuration. This guide explains the **simplified configuration** approach.

---

## 🎯 Quick Start (3 variables!)

### Local Release

**Method 1: Using setup script** (Recommended)
```bash
source Scripts/utils/setup-release-env.sh local
./Scripts/msp-release.sh run 0.3.0-rc.6
```

**Method 2: Using direnv** (Most elegant)
```bash
# One-time setup
cp .envrc.example .envrc
direnv allow

# Auto-loaded when you cd into project
./Scripts/msp-release.sh run 0.3.0-rc.6
```

**Method 3: Manual export**
```bash
export MSP_RELEASE_TIER=release
export MSP_ALLOW_LOCAL_RELEASE=1
export MSP_ALLOW_TRUNK_PUSH=1

./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

### CI Release

**GitHub Actions**:
```yaml
- name: Release
  env:
    MSP_RELEASE_TIER: release
    MSP_ALLOW_TRUNK_PUSH: 1
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    ./Scripts/msp-release.sh run ${{ inputs.version }}
```

**Note**: `CI` and `GITHUB_ACTIONS` are automatically set by CI environment.

---

## 📋 Environment Variables Reference

### Core Variables (Required)

| Variable | Local | CI | Default | Description |
|----------|-------|----|---------| ------------|
| `MSP_RELEASE_TIER` | ✅ | ✅ | `preflight` | Release tier: `preflight` or `release` |
| `MSP_ALLOW_LOCAL_RELEASE` | ✅ | ❌ | `0` | Allow release tier on local machine |
| `MSP_ALLOW_TRUNK_PUSH` | ✅ | ✅ | `0` | Allow push to CocoaPods Trunk |

### Optional Variables

| Variable | Use Case | Default | Description |
|----------|----------|---------|-------------|
| `MSP_ALLOW_EXISTING_TAG` | Rerelease | `0` | Allow overwriting existing tags |
| `MSP_SLACK_ALERT_ENV` | Slack notifications | `prod` | Slack environment: `test` or `prod` |
| `SLACK_WEBHOOK_URL` | Slack notifications | From `slack.conf` | Slack webhook URL |

### Variables You DON'T Need

| Variable | Why Not Needed |
|----------|----------------|
| `CI` | Automatically set by CI environment |
| `GITHUB_ACTIONS` | Automatically set by GitHub Actions |
| `SLACK_BOT_TOKEN` | Only needed for DMs (rare) |
| `MSP_SLACK_DM_OVERRIDE` | Only needed for DMs (rare) |
| ~~`MSP_ALLOW_PUBLIC_PUSH_FAILURE`~~ | **Never use** (causes tag inconsistency) |

---

## 🔧 Configuration Profiles

### Profile: Local Release

**3 variables**:
```bash
source Scripts/utils/setup-release-env.sh local
```

Equivalent to:
```bash
export MSP_RELEASE_TIER=release
export MSP_ALLOW_LOCAL_RELEASE=1
export MSP_ALLOW_TRUNK_PUSH=1
export MSP_SLACK_ALERT_ENV=test  # optional
```

---

### Profile: CI Release

**2 variables**:
```bash
source Scripts/utils/setup-release-env.sh ci
```

Equivalent to:
```bash
export MSP_RELEASE_TIER=release
export MSP_ALLOW_TRUNK_PUSH=1
export MSP_SLACK_ALERT_ENV=prod  # optional
```

---

### Profile: Rerelease

**4 variables** (local + rerelease permission):
```bash
source Scripts/utils/setup-release-env.sh rerelease
```

Equivalent to:
```bash
export MSP_RELEASE_TIER=release
export MSP_ALLOW_LOCAL_RELEASE=1
export MSP_ALLOW_TRUNK_PUSH=1
export MSP_ALLOW_EXISTING_TAG=1  # allows overwriting
```

---

### Profile: Test (Preflight)

**3 variables** (no actual push):
```bash
source Scripts/utils/setup-release-env.sh test
```

Equivalent to:
```bash
export MSP_RELEASE_TIER=preflight
export MSP_ALLOW_LOCAL_RELEASE=1
export MSP_ALLOW_TRUNK_PUSH=0  # no push
```

---

## 🎯 Recommended Setup

### For Individual Developers

**Option 1: direnv** (Most elegant)
```bash
# Install direnv
brew install direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# Setup
cp .envrc.example .envrc
direnv allow

# Auto-loads when you cd into project ✨
```

**Option 2: Setup script**
```bash
# Create alias
echo 'alias msp-env="source Scripts/utils/setup-release-env.sh"' >> ~/.zshrc

# Usage
msp-env local
./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

### For Teams

**Share template files**:
1. `.envrc.example` - For direnv users
2. `Scripts/utils/setup-release-env.sh` - For script users
3. `Scripts/config/slack.conf.example` - For Slack config

**Documentation**:
- Point developers to this guide
- Provide quick start commands

---

### For CI/CD

**GitHub Actions** (recommended):
```yaml
jobs:
  release:
    env:
      MSP_RELEASE_TIER: release
      MSP_ALLOW_TRUNK_PUSH: 1
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
    steps:
      - run: ./Scripts/msp-release.sh run ${{ inputs.version }}
```

**Shell script**:
```bash
#!/bin/bash
export MSP_RELEASE_TIER=release
export MSP_ALLOW_TRUNK_PUSH=1
export SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL_FROM_SECRETS"

./Scripts/msp-release.sh run "$VERSION"
```

---

## 📊 Before vs After

| Aspect | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Variables (Local)** | 11 | 3 | -73% |
| **Variables (CI)** | 9 | 2 | -78% |
| **Setup complexity** | High | Low | Much simpler |
| **Error-prone** | Yes | No | Safer |

---

## 🔍 Troubleshooting

### Issue: "Release tier cannot be executed locally"

**Cause**: Missing `MSP_ALLOW_LOCAL_RELEASE`

**Solution**:
```bash
export MSP_ALLOW_LOCAL_RELEASE=1
# Or use: source Scripts/utils/setup-release-env.sh local
```

---

### Issue: "trunk push disabled"

**Cause**: Missing `MSP_ALLOW_TRUNK_PUSH`

**Solution**:
```bash
export MSP_ALLOW_TRUNK_PUSH=1
```

---

### Issue: "Tag already exists"

**Cause**: Trying to rerelease without permission

**Solution**:
```bash
export MSP_ALLOW_EXISTING_TAG=1
# Or use: source Scripts/utils/setup-release-env.sh rerelease
```

---

## 📚 Related Documentation

- [Slack Configuration Guide](./README-SLACK.md) - Slack notification setup
- [Release Guide](../docs/RELEASE.md) - Complete release process
- [Token Injection Guide](/tmp/token-injection-guide.md) - Token management

---

## ✅ Best Practices

1. **Use configuration profiles** instead of manual exports
2. **Use direnv** for automatic loading (most elegant)
3. **Use test mode** for Slack when developing (`MSP_SLACK_ALERT_ENV=test`)
4. **Never set** `MSP_ALLOW_PUBLIC_PUSH_FAILURE` (causes issues)
5. **Store secrets** in `slack.conf` (local) or GitHub Secrets (CI)

---

## 🎉 Summary

**You only need 3 variables for local release:**
```bash
MSP_RELEASE_TIER=release
MSP_ALLOW_LOCAL_RELEASE=1
MSP_ALLOW_TRUNK_PUSH=1
```

**And 2 variables for CI release:**
```bash
MSP_RELEASE_TIER=release
MSP_ALLOW_TRUNK_PUSH=1
```

**That's it!** 🚀

