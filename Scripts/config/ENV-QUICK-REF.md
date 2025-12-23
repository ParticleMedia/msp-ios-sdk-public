# Environment Variables Quick Reference

## 🚀 Quick Commands

### Local Release
```bash
# Method 1: Setup script (recommended)
source Scripts/utils/setup-release-env.sh local
./Scripts/msp-release.sh run 0.3.0-rc.6

# Method 2: direnv (most elegant)
cp .envrc.example .envrc && direnv allow
./Scripts/msp-release.sh run 0.3.0-rc.6

# Method 3: Manual
export MSP_RELEASE_TIER=release MSP_ALLOW_LOCAL_RELEASE=1 MSP_ALLOW_TRUNK_PUSH=1
./Scripts/msp-release.sh run 0.3.0-rc.6
```

### Rerelease (existing version)
```bash
source Scripts/utils/setup-release-env.sh rerelease
./Scripts/msp-release.sh run 0.3.0-rc.6
```

### Test (no actual push)
```bash
source Scripts/utils/setup-release-env.sh test
./Scripts/msp-release.sh run 0.3.0-rc.6
```

---

## 📋 Variables Cheat Sheet

| Variable | Local | CI | Value |
|----------|-------|----|----|
| `MSP_RELEASE_TIER` | ✅ | ✅ | `release` |
| `MSP_ALLOW_LOCAL_RELEASE` | ✅ | ❌ | `1` |
| `MSP_ALLOW_TRUNK_PUSH` | ✅ | ✅ | `1` |
| `MSP_ALLOW_EXISTING_TAG` | ⚠️ | ⚠️ | `1` (rerelease only) |

---

## 🎯 Profiles

| Profile | Command | Use Case |
|---------|---------|----------|
| `local` | `source Scripts/utils/setup-release-env.sh local` | Normal release |
| `ci` | `source Scripts/utils/setup-release-env.sh ci` | CI/CD pipeline |
| `rerelease` | `source Scripts/utils/setup-release-env.sh rerelease` | Republish version |
| `test` | `source Scripts/utils/setup-release-env.sh test` | Test/preflight |

---

## ❌ Don't Use

| Variable | Why |
|----------|-----|
| `CI`, `GITHUB_ACTIONS` | Auto-set in CI |
| `SLACK_BOT_TOKEN`, `MSP_SLACK_DM_OVERRIDE` | Rarely needed |
| ~~`MSP_ALLOW_PUBLIC_PUSH_FAILURE`~~ | **Never use** |

---

## 📚 Full Documentation

See [README-ENV.md](./README-ENV.md) for complete guide.

