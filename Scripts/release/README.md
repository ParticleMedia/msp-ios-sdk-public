# Release System Architecture

> **Version**: 3.1 (Post feature/002 Refactoring)
> **Last Updated**: 2026-02-26
> **Audience**: Developer-facing (深度技术文档)

This document provides a comprehensive deep-dive into the MSP iOS SDK release system architecture, covering the modular design, state management internals, and extension guidelines.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Design Principles](#design-principles)
3. [Module Structure](#module-structure)
4. [State Management Internals](#state-management-internals)
5. [GitHub Release Workflow](#github-release-workflow)
6. [Extension Guide](#extension-guide)

---

## Architecture Overview

### Evolution: From Monolith to Modular

**Before (Monolithic)**:
```
msp-release.sh (single 3000+ line script)
├─ All logic in one file
├─ Hard to test
├─ Hard to maintain
└─ Hard to extend
```

**After feature/002 (Modular)**:
```
Scripts/release/
├─ cli/                 # 命令行接口层
├─ orchestrator/        # 编排层
├─ publish/             # 发布层
├─ utils/               # 工具层
├─ config/              # 配置层
└─ verify*/             # 验证层
```

### Architectural Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    CLI Layer (cli/)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ dispatch.sh  │  │ commands.sh  │  │ help.sh          │  │
│  │ • Routes cmds│  │ • Utilities  │  │ • Documentation  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Orchestration Layer (orchestrator/)             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ modular.sh - Coordinates workflow phases            │    │
│  │  ├─ Preflight → Build → Git Ops → GitHub Release   │    │
│  │  └─ CocoaPods Publishing → Verification            │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 Publishing Layer (publish/)                  │
│  ┌─────────────────────┐       ┌─────────────────────────┐  │
│  │ pods/publish.sh     │       │ spm/publish.sh          │  │
│  │  ├─ Pod ordering    │       │  └─ SPM packaging       │  │
│  │  ├─ Trunk push      │       └─────────────────────────┘  │
│  │  └─ Verification    │                                    │
│  │                     │                                    │
│  │  lib/ (Modular)     │                                    │
│  │  ├─ github_release_ext.sh       # GitHub Release       │  │
│  │  ├─ github_release_verify.sh    # Verification        │  │
│  │  ├─ release_orchestration.sh    # Pod orchestration   │  │
│  │  ├─ distribution_utils.sh       # Binary utils        │  │
│  │  └─ ...                                                │  │
│  └─────────────────────┘                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Utility Layer (utils/)                     │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐    │
│  │ state.sh   │  │ git.sh     │  │ github.sh          │    │
│  │ • State    │  │ • Git ops  │  │ • GH API           │    │
│  └────────────┘  └────────────┘  └────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│               Configuration Layer (config/)                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ release.yaml - Release configuration                │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 Verification Layer (verify*/)                │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐      │
│  │ verify.sh   │  │ verify-     │  │ verify_local/  │      │
│  │ • Remote    │  │ matrix/     │  │ verify_remote/ │      │
│  └─────────────┘  └─────────────┘  └────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Design Principles

### 1. Modularity

**每个模块单一职责**:
- `cli/` - 只负责命令解析和路由
- `orchestrator/` - 只负责工作流编排
- `publish/` - 只负责发布逻辑
- `utils/` - 只提供工具函数

**Benefits**:
- ✅ 易于测试（每个模块可独立测试）
- ✅ 易于维护（修改一个模块不影响其他）
- ✅ 易于扩展（添加新模块或功能）

### 2. State Management

**持久化状态文件 (`.msp-release-state.json`)**:
- 记录每一步的执行结果
- 支持 resume 功能
- 实现幂等性

### 3. Idempotency

**可安全重复执行**:
- 检查状态后决定是否执行
- 已成功的操作自动跳过
- 失败的操作智能重试

### 4. Per-Pod Tracking

**每个 pod 独立状态追踪** (Schema v3):
- `trunk_verified` - CocoaPods Trunk 验证状态
- `github_release_created` - GitHub Release 创建状态
- Resume 时针对每个 pod 的状态智能重试

### 5. Fail-Safe

**非致命错误不阻断流程**:
- GitHub Release 创建失败 → 警告，继续
- 提供补偿命令 (`create-github-releases`)
- 最终验证步骤确保完整性

---

## Module Structure

### CLI Layer (cli/)

**Purpose**: 命令行接口，用户交互入口

| File | Responsibility |
|------|----------------|
| `dispatch.sh` | 命令分发器 - 路由到对应的 do_* 函数 |
| `commands.sh` | 工具命令实现 (fix-public-tag, verify, rollback) |
| `create_github_releases.sh` | GitHub Release 补偿命令 |
| `help.sh` | 帮助系统和 usage 文档 |
| `resume.sh` | Resume 逻辑和状态检查 |
| `wizard.sh` | 交互式向导 |
| `flags.sh` | 命令行参数解析 |
| `env.sh` | 环境变量管理 |

**Key Functions**:
```bash
msp_dispatch_subcommand()           # 命令分发
msp_do_run()                        # run 命令实现
msp_do_resume()                     # resume 命令实现
msp_do_create_github_releases()     # create-github-releases 实现
```

### Orchestrator Layer (orchestrator/)

**Purpose**: 工作流编排，协调各个阶段

| File | Responsibility |
|------|----------------|
| `modular.sh` | 主编排器 - 协调 Preflight → Build → Publish → Verify |

**Workflow Phases**:
```
1. Preflight checks     (preflight/preflight.sh)
2. Build XCFrameworks   (xcframeworks/build-*.sh)
3. Git operations       (utils/git.sh)
4. GitHub Release       (publish/pods/lib/github_release_ext.sh)
5. CocoaPods Publishing (publish/pods/publish.sh)
6. Verification         (verify/verify.sh)
```

### Publishing Layer (publish/)

**Purpose**: 包发布逻辑（CocoaPods, SPM）

#### pods/publish.sh

**Main responsibilities**:
- Pod 发布顺序控制
- 调用 lib/ 中的模块化函数
- 发布状态管理

**Key workflow**:
```bash
main() {
    # Step 0: MSPiOSCore (foundation)
    release_msp_ioscore

    # Step 1: Parallel release MSPSharedLibraries + MSPGoogleAdsTypes
    release_foundation_in_parallel

    # Step 2: Release Adapters (parallel)
    release_adapters

    # Step 3: Release MSPCore (main framework)
    release_msp_core

    # Step 4: Verify all GitHub Releases
    verify_all_github_releases
}
```

#### pods/lib/ (Modular Libraries)

| Module | Purpose |
|--------|---------|
| `github_release_ext.sh` | GitHub Release 创建、上传、验证 |
| `github_release_verify.sh` | 统一验证所有 binary pods 的 GitHub Release |
| `release_orchestration.sh` | 单个 pod 的发布编排 (build → podspec → github release → trunk push) |
| `distribution_utils.sh` | Binary distribution 工具函数 |
| `podspec_utils.sh` | Podspec 生成和验证 |
| `trunk_utils.sh` | CocoaPods Trunk 操作 |
| `zip_management.sh` | ZIP 文件创建和管理（含 MSPCore 特殊处理：Config.plist） |
| `cdn_verify.sh` | CDN 可用性验证 |

**Key functions**:
```bash
# github_release_ext.sh
create_github_release_for_pod()     # 为单个 pod 创建 GitHub Release
verify_and_fix_github_release_zip() # 验证并修复 ZIP 不匹配

# github_release_verify.sh
verify_all_github_releases()        # 统一验证所有 binary pods

# release_orchestration.sh
release_msp_ioscore()               # 发布 MSPiOSCore
release_msp_sharedlibraries()       # 发布 MSPSharedLibraries
release_msp_googleadstypes()        # 发布 MSPGoogleAdsTypes
release_msp_core()                  # 发布 MSPCore
release_adapters()                  # 发布所有 Adapters
```

### Utility Layer (utils/)

**Purpose**: 共享工具函数

| Module | Purpose |
|--------|---------|
| `state.sh` | 状态管理 (read/write .msp-release-state.json) |
| `git.sh` | Git 操作封装 |
| `github.sh` | GitHub API 封装 |

**Key state functions** (state.sh):
```bash
# State initialization
msp_state_init()                    # 初始化 state file

# Pod-level state
msp_state_mark_pod_status()         # 标记 pod 状态
msp_state_get_pod_status()          # 获取 pod 状态

# Trunk verification
msp_state_set_pod_trunk_verified()  # 标记 trunk 验证状态
msp_state_get_pod_trunk_verified()  # 获取 trunk 验证状态

# GitHub Release tracking (v3)
msp_state_set_pod_github_release_created()  # 标记 GitHub Release 已创建
msp_state_get_pod_github_release_created()  # 获取创建状态
msp_state_set_pod_github_release_url()      # 保存 Release URL

# Resume support
msp_state_increment_resume_count()  # 增加 resume 计数
```

### Configuration Layer (config/)

**Purpose**: 发布配置管理

| File | Purpose |
|------|---------|
| `release.yaml` | 主配置文件（profiles, notifications, etc.） |

**Profiles**:
- `production` - DRY_RUN=false, 完整发布
- `local-dev` - DRY_RUN=true, 本地测试
- `ci-test` - DRY_RUN=true, CI/CD 验证

### Verification Layer (verify*/)

**Purpose**: 发布后验证

| Directory | Purpose |
|-----------|---------|
| `verify/` | 远程验证（pod install 测试） |
| `verify-matrix/` | 多目标验证矩阵 |
| `verify_local/` | 本地验证 |
| `verify_xcframework/` | XCFramework 验证 |

---

## State Management Internals

### State File Schema (v4)

> v4 adds `is_prerelease` and `cdn_metrics` top-level fields.
> Old v3 files are backward-compatible — all new accessors use `// false` / `// {}` jq fallbacks.

```json
{
  "schema_version": 4,
  "version": "1.0.4-rc.10",
  "release_mode": "full",
  "resume_count": 0,
  "is_prerelease": false,
  "cdn_metrics": {
    "total_checks": 3,
    "successful_checks": 3,
    "failed_checks": 0,
    "total_retries": 0,
    "avg_latency_ms": 142,
    "max_latency_ms": 210,
    "min_latency_ms": 98,
    "last_check_at": "2026-01-01T00:00:00Z"
  },
  "git": {
    "tag_created": true,
    "github_release_created": true
  },
  "pods": {
    "<pod_name>": {
      "status": "published|failed|pending|inconsistent",
      "trunk_verified": true|false,
      "trunk_verified_at": "ISO8601",
      "github_release_created": true|false,
      "github_release_url": "URL",
      "github_release_verified_at": "ISO8601"
    }
  }
}
```

### State Lifecycle

```
1. msp_state_init()
   └─ 创建空 state file 或重置

2. During release:
   ├─ msp_state_mark_pod_status(pod, "published")
   ├─ msp_state_set_pod_trunk_verified(pod, true)
   └─ msp_state_set_pod_github_release_created(pod, true)  // v3

3. On resume:
   ├─ msp_state_increment_resume_count()
   └─ For each pod:
       ├─ Check github_release_created
       ├─ Check trunk_verified
       └─ Retry if false
```

### Resume Decision Logic

```bash
# In release_orchestration.sh
release_msp_core() {
    # Check GitHub Release status
    local github_release_status
    github_release_status=$(msp_state_get_pod_github_release_created "MSPCore")

    if [[ "$github_release_status" == "true" ]]; then
        log::info "GitHub release already created, skipping"
    else
        log::info "Creating/retrying GitHub release"
        create_github_release_for_pod "MSPCore" "$VERSION"
    fi
}
```

---

## CocoaPods CDN Availability Check

Pod availability is checked directly against the CocoaPods CDN trunk (`cdn.cocoapods.org`) rather than
running `pod repo update` + `pod search`. This eliminates ~3-5 min sync latency and removes the
dependency on a local spec repo mirror.

### CDN URL Format

```
https://cdn.cocoapods.org/Specs/<h0>/<h1>/<h2>/<Pod>/<Version>/<Pod>.podspec.json
```

Where `h0`, `h1`, `h2` are the first 3 hex characters of `md5(<pod_name>)`:

- `MSPCore` → `9/c/4`
- `MSPSharedLibraries` → `7/3/3`
- `AFNetworking` → `a/7/5`

### Retry Policy

| Stage | Behavior |
|-------|----------|
| Retries | 3 per check (exponential backoff: 1s → 2s → 4s) |
| Timeout | 10s per `curl` request |
| Exit 0 | HTTP 200 — pod available |
| Exit 2 | HTTP 404 — not yet propagated |
| Exit 3 | Unreachable / curl error |

### Smart Wait Intervals (after trunk push)

| Stage | Interval | Duration | Checks |
|-------|----------|----------|--------|
| Stage 1 (fast poll) | 15s | ~3 min | 12 |
| Stage 2 (slow poll) | 30s | ~57 min | 114 |
| Total budget | — | 60 min | — |

### CDN Metrics

After each release, CDN check metrics are flushed to the state file under `cdn_metrics`:

```json
"cdn_metrics": {
  "total_checks": 3,
  "successful_checks": 3,
  "failed_checks": 0,
  "total_retries": 1,
  "avg_latency_ms": 142,
  "max_latency_ms": 210,
  "min_latency_ms": 98,
  "last_check_at": "2026-01-01T00:00:00Z"
}
```

---

## Safety Gates

Safety checks run in production mode (`DRY_RUN=false`). All checks are implemented in
`Scripts/release/utils/safety.sh`.

| Check | Behavior |
|-------|----------|
| CI gate | **Unlocked** — local releases allowed from any branch |
| Branch gate | **Unlocked** — any branch allowed |
| `--force` requirement | **Removed** — not required |
| `MSP_ALLOW_LOCAL_RELEASE` | **Removed** — not required |
| Clean Git state | Required in production mode |
| `release.md` | Required; auto-generated skeleton if absent (local only); CI fails hard |
| Version format | X.Y.Z (production) or X.Y.Z-suffix + `MSP_PRERELEASE=1` (prerelease) |

### Prerelease Support

Set `MSP_PRERELEASE=1` (or tick the Jenkins checkbox) to publish a prerelease version:

- VERSION must have a suffix (e.g. `3.6.8-rc.1`)
- Slack notification uses a ⚠️ banner and `warning` color
- State file records `is_prerelease: true` for resume-safe rehydration

---

## GitHub Release Workflow

### Automatic Creation Flow

```
Pod发布流程中的 GitHub Release 创建:

1. release_msp_ioscore()
   │
   ├─ Build XCFramework
   ├─ Generate Podspec
   │
   ├─ create_github_release_for_pod("MSPiOSCore", version)
   │   │
   │   ├─ create_or_verify_github_release(version)
   │   │   └─ gh release create (if not exists)
   │   │
   │   ├─ upload_zip_to_github(version, zip_path)
   │   │   └─ gh release upload
   │   │
   │   ├─ wait_for_cdn_propagation(version)
   │   │   └─ sleep 60-120s (based on file size)
   │   │
   │   ├─ verify_cdn_availability(version, zip_name)
   │   │   └─ curl --head <zip_url>
   │   │
   │   └─ msp_state_set_pod_github_release_created("MSPiOSCore", true) ✨
   │       └─ Update state.json
   │
   └─ publish_pod_to_cocoapods("MSPiOSCore", version)
```

### Unified Verification (Phase 4)

After all pods published:

```bash
# In publish.sh
verify_all_github_releases() {
    local binary_pods=(
        MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes
        MSPPrebidAdapter MSPFacebookAdapter MSPNovaAdapter
        MSPAmazonAdapter MSPGoogleAdapter MSPMolocoAdapter
        MSPLiftoffAdapter MSPCore
    )

    for pod in "${binary_pods[@]}"; do
        local zip_url="https://github.com/.../releases/download/${version}/${pod}-${version}.zip"

        if curl --head --silent --fail "$zip_url" &>/dev/null; then
            msp_state_set_pod_github_release_created "$pod" "true"
        else
            msp_state_set_pod_github_release_created "$pod" "false"
        fi
    done
}
```

### Manual Recovery

如果自动创建失败，使用补偿命令：

```bash
./Scripts/msp-release.sh create-github-releases 1.0.4-rc.10
```

**工作流程**:
```
create_github_releases_command(version):
    for each binary_pod:
        status = msp_state_get_pod_github_release_created(pod)

        if status == "true":
            skip (already created)
        else:
            create_github_release_for_pod(pod, version)
            msp_state_set_pod_github_release_created(pod, true)
```

---

## Extension Guide

### Adding a New Command

**Step 1**: Create command module in `cli/`

```bash
# cli/my_new_command.sh
my_new_command() {
    local version="$1"
    # Implementation
}

export -f my_new_command
```

**Step 2**: Add dispatch handler in `cli/dispatch.sh`

```bash
msp_do_my_command() {
    # Source module if not loaded
    if ! command -v my_new_command &>/dev/null; then
        source "$_DISPATCH_ROOT_DIR/Scripts/release/cli/my_new_command.sh"
    fi

    my_new_command "${REMAINING_ARGS[@]}"
}

# Add to dispatch switch
case "$subcommand" in
    my-command)
        msp_do_my_command
        ;;
esac

export -f msp_do_my_command
```

**Step 3**: Update help text in `cli/help.sh`

```bash
COMMANDS:
    my-command <args>    Description of my command
```

### Adding New State Fields

**Step 1**: Update state.sh

```bash
# utils/state.sh
msp_state_set_my_field() {
    local value="$1"
    # Implementation using _msp_state_update_json
}

msp_state_get_my_field() {
    # Implementation using jq
}

export -f msp_state_set_my_field
export -f msp_state_get_my_field
```

**Step 2**: Update state initialization schema in `msp_state_init()`

**Step 3**: Use in your module

```bash
msp_state_set_my_field "value"
local value=$(msp_state_get_my_field)
```

### Adding a New Pod Release Function

**Step 1**: Add function in `publish/pods/lib/release_orchestration.sh`

```bash
release_my_new_pod() {
    log_section "Releasing MyNewPod"

    # Idempotency check
    if check_pod_availability "MyNewPod" "$VERSION"; then
        log::info "Already published, skipping"
        return 0
    fi

    # Build, podspec, GitHub Release, trunk push
    # ...

    # Update state
    msp_state_mark_pod_status "MyNewPod" "published"
    msp_state_set_pod_github_release_created "MyNewPod" "true"
}

export -f release_my_new_pod
```

**Step 2**: Call from `publish/pods/publish.sh` in correct order

```bash
main() {
    # ...
    release_my_new_pod "$RELEASE_VERSION"
    # ...
}
```

### Pod-Specific Resource Handling (MSPCore)

MSPCore requires `Config.plist` for `getMSPVersion()`. This needs special handling in two places:

**1. generate_podspec.sh** — Adds `resource_bundles` to the generated podspec:
```ruby
spec.vendored_frameworks = "Binary/MSPCore.xcframework"
spec.resource_bundles = {
  'MSPCoreResources' => ['Resources/Config.plist']
}
```

**2. zip_management.sh** — Includes `Config.plist` in the release zip:
```
MSPCore-1.0.5.zip
├── Binary/MSPCore.xcframework/
└── Resources/Config.plist
```

When adding resource files to other pods, follow this same two-file pattern and add unit tests in `Scripts/tests/unit/cases/`.

### Testing Your Changes

```bash
# Unit test
./Scripts/tests/unit/run_all.sh

# Local dry-run
./Scripts/msp-release.sh --profile=local-dev run 0.0.1-test

# Check state file
cat .msp-release-state.json | jq .

# Resume test
./Scripts/msp-release.sh resume
```

---

## Best Practices

### 1. Always Use State Management

✅ **Good**:
```bash
if [[ "$(msp_state_get_pod_status "MSPCore")" == "published" ]]; then
    skip
fi
```

❌ **Bad**:
```bash
# Hardcoded checks without state
```

### 2. Fail-Safe for Non-Critical Operations

✅ **Good**:
```bash
if ! create_github_release_for_pod "$pod" "$version"; then
    log::warn "GitHub Release failed, continuing..."
    # Don't exit
fi
```

❌ **Bad**:
```bash
create_github_release_for_pod "$pod" "$version" || exit 1
```

### 3. Modular Function Composition

✅ **Good**:
```bash
release_pod() {
    build_xcframework || return 1
    generate_podspec || return 1
    create_github_release || return 1
    publish_to_trunk || return 1
}
```

❌ **Bad**:
```bash
# All logic in one giant function
```

### 4. Use Shared Utilities

✅ **Good**:
```bash
source "$ROOT_DIR/Scripts/release/utils/state.sh"
msp_state_set_pod_status "MSPCore" "published"
```

❌ **Bad**:
```bash
# Direct jq manipulation
echo '{"status":"published"}' | jq . > state.json
```

---

## Troubleshooting

### State File Corrupted

```bash
# Backup and reset
cp .msp-release-state.json .msp-release-state.json.backup
rm .msp-release-state.json

# Restart release
./Scripts/msp-release.sh run <version>
```

### GitHub Release Not Created

```bash
# Check state
cat .msp-release-state.json | jq '.pods[] | select(.github_release_created == false)'

# Manual recovery
./Scripts/msp-release.sh create-github-releases <version>
```

### Resume Not Working

```bash
# Check state file exists
ls -la .msp-release-state.json

# Check schema version
cat .msp-release-state.json | jq .schema_version

# Manual resume with verbose logging
./Scripts/msp-release.sh resume --verbose
```

---

## References

- [Docs/RELEASE.md](../../Docs/RELEASE.md) - User-facing release guide
- [Scripts/README.md](../README.md) - Scripts overview
- [constitution.md](../../constitution.md) - Governance rules
- [.context/release/](../../.context/release/) - Release knowledge base

---

**Last Updated**: 2026-02-26 by Claude Code (feat/002-release-system-refactor)
