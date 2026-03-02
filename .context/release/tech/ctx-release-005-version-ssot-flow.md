# ctx-release-005: SDK 版本 SSOT 及完整发布流程

> **Domain**: release
> **Layer**: tech
> **Status**: active
> **Created**: 2026-02-28
> **Updated**: 2026-02-28

## SSOT 定义

**唯一权威版本来源**: `Scripts/config/sdk_version.conf`

格式:
```bash
# Single source of truth for SDK release version.
# Updated by release scripts.
SDK_VERSION="x.y.z"
```

读写 API (定义在 `Scripts/release/utils/version.sh`):
| 函数 | 作用 |
|------|------|
| `read_sdk_version_from_config` | 从 SSOT 读取版本，失败返回 1 |
| `set_sdk_version_in_config "$VERSION"` | 写入 SSOT |
| `resolve_effective_sdk_version "$preferred"` | 优先返回参数，fallback 读 SSOT |

版本更新 + 提交 DRY 函数 (定义在 `Scripts/release/publish/pods/lib/version_commit.sh`):
| 函数 | 作用 |
|------|------|
| `update_and_commit_plist_version "mspcore" "$ver"` | 更新 MSPCore Config.plist + 立即 commit |
| `update_and_commit_plist_version "novacore" "$ver"` | 更新 NovaCore Config.plist + 立即 commit |
| `ensure_version_files_committed "$ver"` | 安全网：检查三个文件是否都已 commit |

## 完整发布流程（含每一步 git 操作）

```
Phase 1: 创建 Release 分支 (branch.sh)
──────────────────────────────────────
  git checkout main
  git pull origin main
  git checkout -b release/x.y.z
  git push origin release/x.y.z


Phase 2: Release 分支上的 Commits
──────────────────────────────────

  ① chore(release): set SDK version SSOT to x.y.z
  │   modular.sh: set_sdk_version_in_config → commit sdk_version.conf
  │   release branch 上的第一个 commit
  │
  ② git tag x.y.z + git push origin/public tag
  │   必须在 GitHub Release 之前（CocoaPods 验证需要 tag）
  │
  ③ chore(release): update NovaCore Config.plist SDKVersion to x.y.z
  │   Step 0.9: update_and_commit_plist_version "novacore"
  │   改完立即提交，在 build NovaCore.xcframework 之前
  │
  ④ build NovaCore.xcframework
  │   发布 MSPiOSCore, SharedLibraries, GoogleAdsTypes, Adapters
  │   （GitHub Release + pod trunk push，无 git commit）
  │
  ⑤ chore(release): update MSPCore Config.plist SDKVersion to x.y.z
  │   release_msp_core: update_and_commit_plist_version "mspcore"
  │   改完立即提交，在 rebuild MSPCore.xcframework 之前
  │
  ⑥ rebuild MSPCore.xcframework → zip → publish MSPCore
  │
  ⑦ ensure_version_files_committed（安全网，通常 no-op）
  │
  ⑧ git push origin release/x.y.z
  │
  ⑨ gh pr create → PR 合并回 base branch


Phase 3: PR 合并
────────────────
  release/x.y.z → PR review → merge 到 main
  SSOT 和所有版本文件随 PR 进入 main
```

## TestFlight 版本读取（独立于发布流程）

```
deploy.sh
  │  source version.sh
  │  TF_SDK_VERSION = read_sdk_version_from_config()
  │    └─ 读 git 里的 sdk_version.conf（release 合并后自动生效）
  │    └─ 失败时 fallback "0.0.1" 并 warn
  │  export TF_SDK_VERSION
  ▼
archive.sh
  xcodebuild archive \
    CURRENT_PROJECT_VERSION="$TF_NEXT_BUILD_NUMBER" \
    MARKETING_VERSION="${TF_SDK_VERSION:-0.0.1}" \
    ...
```

**不需要手动改任何东西**。Release 写入 SSOT 并 commit → 合并到 main → TestFlight 打包时自动读取。

## 关键约束 (违反则版本流转出错)

1. **SSOT 必须在 release branch 上第一个被 commit** — 所有后续步骤读取它
2. **Step 0.9 只读不写 SSOT** — 写入已在 modular.sh 完成
3. **改完即 commit** — 每个版本文件修改后必须立即 git commit，不能等到流程末尾统一提交（历史教训：NovaCore Config.plist 改完没 commit，中间步骤失败后变更丢失）
4. **两处 Config.plist 更新都用 `update_and_commit_plist_version`** — DRY，禁止 inline git add/commit（历史教训：inline 只 stage 了 MSPCore，遗漏 NovaCore）
5. **`ensure_version_files_committed` 仅作为安全网** — 正常流程中它应该 no-op
6. **TestFlight 必须从 SSOT 读取** — 不能硬编码 MARKETING_VERSION
7. **Version update 必须在 XCFramework build 之前** — 否则二进制内嵌旧版本 (参见 ctx-release-004)

## 涉及文件清单

| 文件 | 角色 |
|------|------|
| `Scripts/config/sdk_version.conf` | SSOT 文件 |
| `Scripts/release/utils/version.sh` | SSOT 读写 API |
| `Scripts/release/publish/pods/lib/version_commit.sh` | `update_and_commit_plist_version` (DRY) + `ensure_version_files_committed` (安全网) |
| `Scripts/release/orchestrator/modular.sh` | 首次写入 + commit SSOT |
| `Scripts/release/orchestrator/branch.sh` | 创建 release 分支 |
| `Scripts/release/publish/pods/lib/release_orchestration.sh` | Step 0.9 (NovaCore) + release_msp_core (MSPCore) |
| `Scripts/testflight/deploy.sh` | 读 SSOT → export TF_SDK_VERSION |
| `Scripts/testflight/lib/archive.sh` | 注入 MARKETING_VERSION |
| `Sources/Core/MSPCore/MSPCore/Resources/Config.plist` | MSPCore 版本 plist |
| `Sources/Core/NovaCore/NovaCore/NBResourceBundle.bundle/Config.plist` | NovaCore 版本 plist |

## 相关 Context

- `ctx-release-004`: XCFramework 版本未更新的根因（构建时序问题）— 本流程的修复依据
