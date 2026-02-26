# DRY 重构清单：Scripts 目录重复代码分析

**创建日期**: 2026-02-06
**目的**: 全面分析 Scripts/ 目录下所有重复代码，制定重构计划

---

## 执行摘要

| 类别 | 重复文件数 | 严重程度 | 建议 |
|------|-----------|---------|------|
| CDN 验证 | 3 | 🔴 高 | 统一到 `shared/cdn_verify.sh` |
| 输入验证 | 2 | 🟡 中 | 统一到 `shared/input_validation.sh` |
| GitHub Release | 4 | 🔴 高 | 提取共享模块 |
| Duration 计算 | 4+ | 🟡 中 | 统一到 `shared/` |
| Zip 创建 | 2 | 🟡 中 | 评估是否可合并 |
| Step 生命周期 | 3+ | 🟢 低 | 已有共享模块，需要更多使用 |
| 重试逻辑 | 5+ | 🟡 中 | 统一使用 `utils/retry.sh` |
| 通知构建 | 3 | 🟢 低 | 数据层/发送层分离，保持现状 |

---

## 1. CDN 验证 🔴

### 当前状态

| 文件 | 行数 | 主要函数 |
|------|-----|---------|
| `Scripts/lib/shared/cdn_verify.sh` | 244 | `cdn_verify_url`, `cdn_verify_urls`, `cdn_wait_for_propagation` |
| `Scripts/release/publish/pods/lib/cdn_verify.sh` | ~200 | `wait_for_cdn_propagation`, `verify_cdn_availability` |
| `Scripts/release/publish/spm/lib/cdn_verification.sh` | ~430 | `spm_verify_cdn_availability`, `spm_quick_cdn_check` |

### 重复分析

```
shared/cdn_verify.sh (基础设施 ✅)
├── cdn_verify_url() - 验证单个 URL
├── cdn_verify_urls() - 批量验证 URL
├── cdn_wait_for_propagation() - 等待 CDN 传播
└── cdn_build_github_release_url() - 构建 URL

pods/lib/cdn_verify.sh (重复 ❌)
├── wait_for_cdn_propagation() - 与 shared 重复
└── verify_cdn_availability() - 与 cdn_verify_url 重复

spm/lib/cdn_verification.sh (部分重复 ⚠️)
├── spm_verify_cdn_availability() - URL 检查逻辑与 shared 重复
├── spm_quick_cdn_check() - 与 cdn_verify_url 重复
└── spm_verify_checksum_from_cdn() - 独特功能 ✅
```

### 重构任务

- [ ] **R001** 删除 `pods/lib/cdn_verify.sh`，使用 `shared/cdn_verify.sh`
- [ ] **R002** 重构 `spm/lib/cdn_verification.sh`：
  - [ ] R002a: `spm_verify_cdn_availability` 内部使用 `cdn_verify_urls`
  - [ ] R002b: 删除 `spm_quick_cdn_check`，使用 `cdn_verify_url`
  - [ ] R002c: 保留 `spm_verify_checksum_from_cdn` (独特功能)
- [ ] **R003** 更新 `pods/publish.sh` source `shared/cdn_verify.sh`
- [ ] **R004** 验证所有调用点正常工作

---

## 2. 输入验证 🟡

### 当前状态

| 文件 | 行数 | 主要函数 |
|------|-----|---------|
| `Scripts/lib/shared/input_validation.sh` | ~150 | `validate_version_format`, `validate_branch_name`, `validate_release_branch` |
| `Scripts/release/publish/pods/lib/input_validation.sh` | ~200 | `parse_arguments`, `validate_inputs`, `check_release_branch` |

### 重复分析

```
shared/input_validation.sh (基础设施 ✅)
├── validate_version_format() - 版本格式验证
├── validate_branch_name() - 分支名验证
└── validate_release_branch() - 发布分支验证

pods/lib/input_validation.sh (部分重复 ⚠️)
├── parse_arguments() - Pods 特定参数解析 ✅
├── validate_inputs() - 包含通用验证逻辑 ❌
└── check_release_branch() - 与 shared 重复 ❌
```

### 重构任务

- [ ] **R005** 重构 `pods/lib/input_validation.sh`:
  - [ ] R005a: `validate_inputs` 内部使用 `validate_version_format`
  - [ ] R005b: 删除 `check_release_branch`，使用 `validate_release_branch`
  - [ ] R005c: 保留 `parse_arguments` (Pods 特定)
- [ ] **R006** 确保 `modular.sh` 使用 `shared/input_validation.sh`

---

## 3. GitHub Release 操作 🔴

### 当前状态

| 文件 | 行数 | 主要函数 |
|------|-----|---------|
| `Scripts/release/utils/github.sh` | ~300 | `github_create_release`, `github_upload_asset`, `github_delete_release` |
| `Scripts/release/publish/pods/lib/github_release.sh` | ~400 | `create_or_verify_github_release`, `upload_zip_to_github` |
| `Scripts/release/publish/pods/lib/github_release_ext.sh` | ~300 | `ensure_release_exists_or_create`, `upload_with_retry` |
| `Scripts/release/publish/spm/lib/xcframework_zip.sh` | ~300 | `spm_upload_to_github_release`, `spm_probe_zip_url` |

### 重复分析

```
utils/github.sh (通用工具 ✅)
├── github_create_release() - 创建 release
├── github_upload_asset() - 上传资产
└── github_delete_release() - 删除 release

pods/lib/github_release.sh (Pods 封装 ⚠️)
├── create_or_verify_github_release() - 包装 github_create_release
└── upload_zip_to_github() - 包装 github_upload_asset

pods/lib/github_release_ext.sh (扩展功能 ⚠️)
├── ensure_release_exists_or_create() - 幂等创建
└── upload_with_retry() - 重试上传

spm/lib/xcframework_zip.sh (SPM 版本 ❌)
├── spm_upload_to_github_release() - 与 upload_zip_to_github 重复
└── spm_probe_zip_url() - 与 cdn_verify_url 重复
```

### 重构任务

- [ ] **R007** 整合 GitHub Release 功能到 `shared/github_release.sh`:
  - [ ] R007a: 从 `utils/github.sh` 迁移基础函数
  - [ ] R007b: 添加 `ensure_release_exists` (幂等创建)
  - [ ] R007c: 添加 `upload_asset_with_retry` (重试上传)
- [ ] **R008** 重构 `spm/lib/xcframework_zip.sh`:
  - [ ] R008a: 删除 `spm_upload_to_github_release`，使用共享模块
  - [ ] R008b: 删除 `spm_probe_zip_url`，使用 `cdn_verify_url`
  - [ ] R008c: 保留 `spm_create_deterministic_zip` (独特功能)
  - [ ] R008d: 保留 `spm_compute_zip_checksum` (独特功能)
- [ ] **R009** 重构 `pods/lib/github_release.sh` 使用共享模块
- [ ] **R010** 删除 `pods/lib/github_release_ext.sh` (功能合并到共享模块)

---

## 4. Duration 计算 🟡

### 当前状态

重复出现在以下文件:
- `Scripts/release/orchestrator/lib/summary.sh` - `orch_calculate_duration()`
- `Scripts/release/orchestrator/modular.sh` - 内联代码
- `Scripts/release/utils/state.sh` - 内联代码
- `Scripts/plugins/github-actions.sh` - 内联代码
- `Scripts/release/utils/logger.sh` - 内联代码

### 重复代码模式

```bash
# 重复模式 - 在 5+ 文件中出现
local start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" "+%s" 2>/dev/null || \
                    date -d "$start_time" "+%s" 2>/dev/null)
local end_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" "+%s" 2>/dev/null || \
                  date -d "$end_time" "+%s" 2>/dev/null)
local duration_seconds=$((end_epoch - start_epoch))
local minutes=$((duration_seconds / 60))
local seconds=$((duration_seconds % 60))
```

### 重构任务

- [ ] **R011** 创建 `Scripts/lib/shared/time_utils.sh`:
  - [ ] R011a: `time_calculate_duration(start, end)` - 计算持续时间
  - [ ] R011b: `time_format_duration(seconds)` - 格式化为 "Xm Ys"
  - [ ] R011c: `time_to_epoch(datetime)` - 跨平台时间转换
- [ ] **R012** 更新所有文件使用 `time_utils.sh`:
  - [ ] R012a: `summary.sh` - 使用 `time_calculate_duration`
  - [ ] R012b: `modular.sh` - 移除内联代码
  - [ ] R012c: `state.sh` - 移除内联代码
  - [ ] R012d: `github-actions.sh` - 移除内联代码
  - [ ] R012e: `logger.sh` - 移除内联代码

---

## 5. Zip 创建 🟡

### 当前状态

| 文件 | 行数 | 主要函数 |
|------|-----|---------|
| `Scripts/release/publish/spm/lib/xcframework_zip.sh` | ~150 | `spm_create_deterministic_zip` |
| `Scripts/release/publish/pods/lib/zip_management.sh` | ~400 | `create_zip_from_xcframework`, `ensure_zip_file_exists_for_pod` |

### 差异分析

```
spm/lib/xcframework_zip.sh
├── spm_create_deterministic_zip() - 使用固定时间戳确保 reproducible
└── 用途: SPM Package.swift checksum 一致性

pods/lib/zip_management.sh
├── create_zip_from_xcframework() - 包含 modulemap 处理
├── _ensure_modulemaps_in_xcframework() - ObjC 支持
└── 用途: CocoaPods 二进制分发
```

### 重构建议

这两个模块有**不同的用途**，不建议强制合并：
- SPM: 需要 reproducible zip (checksum 一致性)
- Pods: 需要 modulemap 处理 (ObjC 支持)

### 重构任务

- [ ] **R013** 评估是否可以提取共同部分到 `shared/zip_utils.sh`:
  - [ ] R013a: `zip_create_from_directory(src, dest)` - 基础 zip 创建
  - [ ] R013b: 让 SPM/Pods 模块在此基础上添加特定逻辑
- [ ] **R014** 如果不合并，至少统一命名和文档风格

---

## 6. Step 生命周期 🟢

### 当前状态

| 文件 | 状态 |
|------|-----|
| `Scripts/lib/shared/step_lifecycle.sh` | ✅ 共享模块已存在 |
| `Scripts/release/orchestrator/modular.sh` | ✅ 已使用 |
| `Scripts/release/publish/pods/publish.sh` | ⚠️ 有内联实现 |
| `Scripts/release/publish/spm/publish.sh` | ⚠️ 有内联实现 |

### 重构任务

- [ ] **R015** 确保所有 publish 脚本使用 `shared/step_lifecycle.sh`:
  - [ ] R015a: `pods/publish.sh` - 移除内联 step 函数
  - [ ] R015b: `spm/publish.sh` - 移除内联 step 函数
- [ ] **R016** 验证函数签名兼容性

---

## 7. 重试逻辑 🟡

### 当前状态

| 文件 | 重试函数 |
|------|---------|
| `Scripts/release/utils/retry.sh` | `retry_with_backoff`, `retry_command` |
| `Scripts/release/publish/pods/lib/pod_trunk.sh` | 内联重试 |
| `Scripts/release/publish/pods/lib/tag_management.sh` | 内联重试 |
| `Scripts/lib/shared/cdn_verify.sh` | 内联重试 |
| `Scripts/release/publish/spm/lib/cdn_verification.sh` | 内联重试 |
| `Scripts/release/publish/spm/lib/xcframework_zip.sh` | 内联重试 |

### 重构任务

- [ ] **R017** 扩展 `utils/retry.sh` 功能:
  - [ ] R017a: 添加 `retry_with_exponential_backoff()`
  - [ ] R017b: 添加 `retry_until_success(cmd, max_attempts, delay)`
- [ ] **R018** 替换所有内联重试逻辑:
  - [ ] R018a: `pod_trunk.sh`
  - [ ] R018b: `tag_management.sh`
  - [ ] R018c: `cdn_verify.sh` (shared)
  - [ ] R018d: `cdn_verification.sh` (spm)
  - [ ] R018e: `xcframework_zip.sh` (spm)

---

## 8. 通知构建 🟢

### 当前状态

| 文件 | 层次 | 功能 |
|------|-----|------|
| `Scripts/release/orchestrator/lib/notify_builder.sh` | 数据层 | 构建 JSON 数据 |
| `Scripts/release/utils/notify.sh` | 发送层 | Slack DM/Channel |
| `Scripts/notify/notify_core.sh` | 核心层 | 统一入口 |

### 分析

这三个文件是**不同层次**的功能，不是重复：
- `notify_builder.sh` - 准备数据
- `notify.sh` - 封装发送逻辑
- `notify_core.sh` - 统一 API

### 建议

保持现状，但需要：
- [ ] **R019** 确保 `notify_builder.sh` 输出与 `notify_core.sh` 输入兼容
- [ ] **R020** 添加集成测试验证端到端流程

---

## 9. 其他发现

### 9.1 ROOT_DIR 解析重复

几乎所有脚本都有类似代码:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

### 重构任务

- [ ] **R021** 考虑创建 `Scripts/lib/path_init.sh`:
  - [ ] R021a: 提供 `init_script_paths()` 函数
  - [ ] R021b: 自动设置 SCRIPT_DIR, ROOT_DIR

### 9.2 Logging Fallback 重复

多个文件有相同的 fallback 日志函数定义：
```bash
if ! command -v log::info &>/dev/null; then
    log_info() { ... }
    log_error() { ... }
    ...
fi
```

### 重构任务

- [ ] **R022** 确保所有脚本正确 source `logger.sh`
- [ ] **R023** 移除不必要的 fallback 定义

---

## 10. XCFramework 构建与验证 🔴

### 当前状态

**构建相关** (`xcodebuild -create-xcframework` 在 7 个文件中出现):

| 文件 | 行数 | 功能 |
|------|-----|------|
| `Scripts/lib/xcframework_builder.sh` | ~250 | 通用构建库 (`build_xcframework`, `build_for_platform`, `create_xcframework`) |
| `Scripts/xcframeworks/builder.sh` | ~200 | 支持从源码构建和复制预构建 |
| `Scripts/xcframeworks/build_module.sh` | ~200 | 使用 XcodeGen 构建单个模块 |
| `Scripts/xcframeworks/build-core.sh` | ~150 | 核心模块构建，调用 build_module.sh |
| `Scripts/xcframeworks/build-thirdparty.sh` | ~150 | 第三方构建，有自己的 xcodebuild 调用 |
| `Scripts/spm-sync/extract_from_pods.sh` | ~100 | SPM 同步时的 xcframework 创建 |
| `Scripts/xcframeworks/internal/build-nova.sh` | ~100 | Nova 专用构建 |

**验证相关** (`validate_xcframework`/`verify_xcframework` 在 10 个文件中出现):

| 文件 | 功能 |
|------|------|
| `Scripts/xcframeworks/validate_xcframework.sh` | 详细结构验证 (slices, modulemap, umbrella header, swiftinterface) |
| `Scripts/target-switching/validate_xcframeworks.sh` | 批量验证 (`validate_xcframework()` 函数) |
| `Scripts/ci/verify-xcframework.sh` | 简单存在性检查 |
| `Scripts/release/utils/ensure_xcframeworks.sh` | 检测并构建缺失的 xcframeworks |
| `Scripts/release/verify_xcframework/run_xcf.sh` | 深度验证 (架构, swiftmodules, 依赖) |
| `Scripts/lib/xcframework_builder.sh` | 内联验证逻辑 |

### 重复分析

```
构建逻辑重复:
├── xcodebuild archive 调用 - 5+ 文件有各自实现
│   ├── lib/xcframework_builder.sh: build_for_platform()
│   ├── xcframeworks/build_module.sh: 内联
│   └── xcframeworks/build-thirdparty.sh: 内联
├── xcodebuild -create-xcframework 调用 - 7 文件
│   ├── lib/xcframework_builder.sh: create_xcframework()
│   ├── xcframeworks/builder.sh: 内联
│   └── xcframeworks/build_module.sh: 内联
└── 重试逻辑 - 多处内联

验证逻辑重复:
├── 存在性检查 - 5+ 文件
├── Info.plist 检查 - 3+ 文件
├── Slice 检查 (ios-arm64, simulator) - 4+ 文件
└── modulemap/umbrella header 检查 - 2 文件
```

### 重构任务

**构建统一**:

- [ ] **R024** 创建统一的 `Scripts/lib/shared/xcframework_build.sh`:
  - [ ] R024a: `xcf_archive_for_platform(project, scheme, platform, output)` - 统一 archive 调用
  - [ ] R024b: `xcf_create_from_archives(device_archive, sim_archive, output)` - 统一 create-xcframework
  - [ ] R024c: `xcf_build_with_retry(cmd, max_attempts)` - 统一重试逻辑
  - [ ] R024d: `xcf_get_build_settings()` - 统一构建设置

- [ ] **R025** 重构现有构建脚本使用共享模块:
  - [ ] R025a: `lib/xcframework_builder.sh` → 调用 `shared/xcframework_build.sh`
  - [ ] R025b: `xcframeworks/build_module.sh` → 调用共享模块
  - [ ] R025c: `xcframeworks/builder.sh` → 调用共享模块
  - [ ] R025d: `xcframeworks/build-thirdparty.sh` → 调用共享模块

**验证统一**:

- [ ] **R026** 创建统一的 `Scripts/lib/shared/xcframework_validate.sh`:
  - [ ] R026a: `xcf_validate_exists(path)` - 存在性检查
  - [ ] R026b: `xcf_validate_structure(path)` - 结构验证 (Info.plist, slices)
  - [ ] R026c: `xcf_validate_content(path, module_name)` - 内容验证 (modulemap, umbrella header)
  - [ ] R026d: `xcf_validate_full(path, module_name)` - 完整验证 (组合上述)

- [ ] **R027** 重构现有验证脚本使用共享模块:
  - [ ] R027a: `xcframeworks/validate_xcframework.sh` → thin wrapper
  - [ ] R027b: `target-switching/validate_xcframeworks.sh` → 使用 `xcf_validate_structure`
  - [ ] R027c: `ci/verify-xcframework.sh` → 使用 `xcf_validate_exists`
  - [ ] R027d: `release/utils/ensure_xcframeworks.sh` → 使用 `xcf_validate_exists`

---

## 11. XcodeGen 操作 🔴

### 当前状态

`xcodegen generate` 在 **13 个文件** 中出现，但没有共享模块。

| 文件 | 用途 |
|------|------|
| `Scripts/tools/generate-workspace.sh` | 工具脚本 |
| `Scripts/target-switching/generate_workspace.sh` | 目标切换 |
| `Scripts/switch-target.sh` | 主切换脚本 |
| `Scripts/ci/install-pods.sh` | CI 安装 |
| `Scripts/ci/generate-workspace.sh` | CI 生成 |
| `Scripts/workspace/update.sh` | 工作区更新 |
| `Scripts/xcframeworks/build-core.sh` | 核心构建 |
| `Scripts/xcframeworks/build-thirdparty.sh` | 第三方构建 |
| `Scripts/xcframeworks/build_module.sh` | 模块构建 |
| `Scripts/xcframeworks/internal/build-*.sh` | 内部构建 (多个) |

### 重复代码模式

```bash
# 模式 1
if ! xcodegen generate --spec "$project_yml" 2>&1; then
    log::warn "Failed to generate project"
fi

# 模式 2 - 略有不同
if xcodegen generate --spec "$PROJECT_SPEC" 2>&1; then
    log::success "Xcode project generated"
fi

# 模式 3 - 带目录切换
(cd "$demoapp_dir" && xcodegen generate --spec project.yml)
```

### 重构任务

- [ ] **R028** 创建 `Scripts/lib/xcodegen.sh`:
  - [ ] R028a: `xcodegen_generate(spec_path, working_dir)` - 统一生成调用
  - [ ] R028b: `xcodegen_validate_output(xcodeproj_path)` - 验证生成结果
  - [ ] R028c: `xcodegen_handle_failure(error_code)` - 统一错误处理
- [ ] **R029** 重构现有脚本使用共享模块 (13 个文件)

---

## 12. Checksum/Hash 计算 🔴

### 当前状态

SHA256 计算在 **10 个文件** 中有不同实现，跨平台兼容性不一致。

| 文件 | 模式 |
|------|------|
| `Scripts/release/publish/spm/lib/xcframework_zip.sh` | swift package compute-checksum |
| `Scripts/release/publish/spm/lib/cdn_verification.sh` | shasum -a 256 |
| `Scripts/release/publish/pods/lib/zip_management.sh` | shasum -a 256 |
| `Scripts/release/publish/pods/lib/github_release_ext.sh` | shasum with validation |
| `Scripts/release/publish/pods/lib/pod_publish.sh` | 内联 |
| `Scripts/plugins/github-actions.sh` | shasum -a 256 |
| `Scripts/release/generate_podspec.sh` | 内联 |
| `Scripts/release/cli/resume.sh` | 内联 |
| `Scripts/lib/asset_validation.sh` | shasum -a 256 |
| `Scripts/lib/ci.sh` | sha256sum |

### 重复代码模式

```bash
# 模式 1 - 基本
checksum=$(shasum -a 256 "$file" 2>/dev/null | awk '{print $1}')

# 模式 2 - 带验证
checksum=$(shasum -a 256 "$zip_path" 2>/dev/null | cut -d' ' -f1)
if [[ ! "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
    # error handling
fi

# 模式 3 - 跨平台 fallback (不一致)
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 ...
elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum ...
fi
```

### 重构任务

- [ ] **R030** 创建 `Scripts/lib/checksum.sh`:
  - [ ] R030a: `checksum_compute_sha256(file)` - 跨平台 SHA256 计算
  - [ ] R030b: `checksum_validate_format(hash)` - 验证格式 (64 位 hex)
  - [ ] R030c: `checksum_verify_file(file, expected_hash)` - 验证文件
- [ ] **R031** 重构现有脚本使用共享模块 (10 个文件)

---

## 13. SPM 操作 🟡

### 当前状态

SPM 相关操作分散在 **32 个文件** 中，没有统一模块。

主要重复：
- Package.swift 修改/patch
- swift package resolve/build 调用
- 版本更新

### 重构任务

- [ ] **R032** 创建 `Scripts/lib/spm.sh`:
  - [ ] R032a: `spm_patch_package_swift(file, changes)` - Package.swift 修改
  - [ ] R032b: `spm_resolve_dependencies()` - 依赖解析
  - [ ] R032c: `spm_validate_manifest(package_path)` - 清单验证
  - [ ] R032d: `spm_update_version(new_version)` - 版本更新
- [ ] **R033** 重构现有脚本使用共享模块

---

## 14. JSON 处理 (jq) 🟢

### 当前状态

`jq` 在 **25+ 个文件** 中使用，模式分散。

### 重复代码模式

```bash
# 模式 1 - 带 fallback (重复最多)
echo "$json" | jq -r '.field // empty' 2>/dev/null || echo ""

# 模式 2 - state 文件读取 (10+ 次)
device_executed="$(echo "$json" | jq -r '.device_verify.executed // false' 2>/dev/null || echo "false")"
```

### 重构任务

- [ ] **R034** 评估是否需要创建 `Scripts/lib/json_utils.sh`:
  - [ ] R034a: `jq_safe(json, query, default)` - 统一 jq 调用
  - [ ] R034b: `jq_extract_field(json, field, default)` - 字段提取
- [ ] **R035** 如果创建，重构关键文件使用共享模块

---

## 15. CocoaPods 使用执行 🟡

### 当前状态

已有 `Scripts/lib/cocoapods.sh` (1,124 行)，但 **33 个文件** 中有直接 `pod install` 调用未使用共享模块。

### 未使用共享模块的文件

- `Scripts/ci/install-pods.sh` - 独立实现
- `Scripts/release/verify_remote/cocoapods/pod_install.sh` - 重复逻辑
- 多个 demoapp 脚本 - 内联调用

### 重构任务

- [ ] **R036** 强制使用 `cocoapods.sh`:
  - [ ] R036a: 重构 `ci/install-pods.sh` 使用 `cocoapods.sh`
  - [ ] R036b: 删除或重构 `pod_install.sh` 使用共享模块
  - [ ] R036c: 审计并更新 demoapp 脚本

---

## 16. Notification Render Config-Driven 改造 🟡

### 当前状态

`Scripts/notify/render.sh` (1914 行) 已有 `notify_mapping.yaml` 配置文件，但存在 **~800 行硬编码模板** 绕过配置系统。

| 函数 | 行范围 | 行数 | 问题 |
|------|--------|-----|------|
| `_notify_render::render_production_email()` | 716-964 | ~250 | 硬编码 HTML 模板 |
| `_notify_render::render_preflight_email()` | 971-1087 | ~115 | 硬编码 HTML 模板 |
| `_notify_render::render_production_blockkit()` | 1240-1542 | ~300 | 硬编码 Slack BlockKit JSON |
| `_notify_render::render_preflight_blockkit()` | 1548-1694 | ~145 | 硬编码 Slack BlockKit JSON |

### 现有配置文件

`Scripts/config/notify_mapping.yaml` 已定义模板结构：
- `dm_template` - DM 通知模板
- `channel_template` - 频道通知模板
- `block_template` - Slack BlockKit 模板
- `email html_template` - 邮件 HTML 模板

支持占位符：`{{VERSION}}`, `{{AUTHOR}}`, `{{MODULES}}`, `{{DURATION}}`, `{{STATUS}}`, `{{ENVIRONMENT}}`, etc.

### 问题分析

```
现状：
notify_mapping.yaml (配置文件 ✅)
├── 定义了模板结构
├── 支持占位符替换
└── 但大部分模板未使用

render.sh (实现文件 ❌)
├── render_production_email() - 硬编码 HTML (~250 行)
├── render_preflight_email() - 硬编码 HTML (~115 行)
├── render_production_blockkit() - 硬编码 JSON (~300 行)
└── render_preflight_blockkit() - 硬编码 JSON (~145 行)
```

### 重构任务

- [ ] **R037** 迁移邮件模板到 `notify_mapping.yaml`:
  - [ ] R037a: 提取 `render_production_email()` 到 YAML 模板
  - [ ] R037b: 提取 `render_preflight_email()` 到 YAML 模板
  - [ ] R037c: 更新 `render.sh` 从配置读取邮件模板
- [ ] **R038** 迁移 Slack BlockKit 模板到 `notify_mapping.yaml`:
  - [ ] R038a: 提取 `render_production_blockkit()` 到 YAML 模板
  - [ ] R038b: 提取 `render_preflight_blockkit()` 到 YAML 模板
  - [ ] R038c: 更新 `render.sh` 从配置读取 BlockKit 模板
- [ ] **R039** 创建模板引擎:
  - [ ] R039a: 实现 `notify_render_template(template_name, variables)` 函数
  - [ ] R039b: 支持占位符替换 (`{{VAR}}` 模式)
  - [ ] R039c: 将 `render.sh` 从 1914 行精简到 ~500 行 (模板引擎 + 调度逻辑)

### 预期收益

| 指标 | 当前 | 目标 |
|------|-----|------|
| render.sh 行数 | 1914 | ~500 |
| 硬编码模板 | ~800 行 | 0 行 |
| 模板修改方式 | 改代码 | 改配置 |
| 新增通知类型 | 复制粘贴代码 | 添加 YAML 配置 |

---

## 17. 全局硬编码值 Config-Driven 改造 🔴

### 当前状态

大量硬编码值分散在 **60+ 个脚本** 中，违反 Constitution Article I.3 (Single Source of Truth) 原则。

### 17.1 CocoaPods 相关硬编码

| 类别 | 硬编码值 | 出现位置 | 建议配置 |
|------|---------|---------|----------|
| Specs 仓库 URL | `https://github.com/CocoaPods/Specs.git` | 3+ 文件 | `specs_repo_url` |
| CDN URL | `https://cdn.cocoapods.org/` | 3+ 文件 | `cdn_url` |
| Pod Install 超时 | `1800` (30分钟) | switch-target.sh:143, cocoapods.sh | `pod_install_timeout` |
| Spec Lint 超时 | `1800` | podspec.sh:192, 426 | `spec_lint_timeout` |
| Trunk Push 超时 | `1800` | podspec.sh:535 | `trunk_push_timeout` |
| 重试次数 | `3` | cocoapods.sh:504 | `max_update_attempts` |
| 重试延迟 | `10`秒 | switch-target.sh:107 | `retry_delay` |
| 缓存 TTL | `300`秒, `60`秒 | cocoapods.sh:500-501 | `cache_ttl`, `failure_cache_ttl` |
| 锁等待超时 | `60`秒 | cocoapods.sh:518 | `lock_timeout` |

### 17.2 构建设置硬编码

| 类别 | 硬编码值 | 出现位置 | 建议配置 |
|------|---------|---------|----------|
| iOS 部署目标 | `15.0` | xcode.sh:46, common.sh:40, xcframework_builder.sh:29, asset_sync.sh:141, workspace/update.sh:146+ | `ios_deployment_target` |
| Swift 版本 | `5.0` | generate_workspace.sh:370+, workspace/update.sh | `swift_version` |
| Swift Tools 版本 | `5.9` | generate-wrappers.sh:81, inject_sdk_spm.sh:72, patch_package.swift.sh:45 | `swift_tools_version` |
| 设备架构 | `arm64` | xcode.sh:39, switch-target.sh:354 | `device_architectures` |
| 模拟器架构 | `arm64 x86_64` | xcode.sh:40 | `simulator_architectures` |
| XCF Slice 名称 | `ios-arm64`, `ios-arm64_x86_64-simulator` | validate_xcframework.sh:31-32, verify_no_fb_symbols.sh:6-7 | `xcframework_slices` |
| XCF 构建超时 | `1800`, `3600` | xcframework_builder.sh:21, build-core.sh:297 | `xcframework_build_timeout` |

### 17.3 测试/模拟器硬编码

| 类别 | 硬编码值 | 出现位置 | 建议配置 |
|------|---------|---------|----------|
| 模拟器设备 | `iPhone 15`, `iPhone 16`, `iPhone 15 Pro` | **12+ 文件**: sdk-package-size.sh:73, round-trip-test.sh:252, run-unit-tests.sh:11, build-mspcore.sh:325, demo_app_builder.sh:66, xcode.sh:488, verify_local/pods.sh:38, ci_validate.sh:343, verify_remote/pods.sh:170, verify.sh:328, sample_app.sh:225 | `simulator_device` |
| 模拟器 OS | `18.5`, `18.0` | round-trip-test.sh:252, ci_validate.sh | `simulator_os` |

### 17.4 CDN/网络超时硬编码

| 类别 | 硬编码值 | 出现位置 | 建议配置 |
|------|---------|---------|----------|
| CDN 等待时间 | `120`秒 | cdn_verify.sh:58, github_release_ext.sh:214 | `cdn_wait_time` |
| CDN 验证超时 | `5-10`秒 | cdn_verification.sh:139, spm/publish.sh:884 | `cdn_verify_timeout` |
| 下载超时 | `30`秒 | github_release_ext.sh:161 | `download_timeout` |
| 连接超时 | `10`秒 | cocoapods.sh:791 | `connect_timeout` |

### 17.5 路径硬编码

| 类别 | 硬编码值 | 出现位置 | 建议配置 |
|------|---------|---------|----------|
| 临时目录 | `/tmp/nova_asset_sync_$$` | asset_sync.sh:39 | `temp_dir` |
| 临时目录 | `/tmp/nova_asset_validation_$$` | asset_validation.sh:37 | `temp_dir` |
| 锁目录 | `/tmp/msp-locks` | lock.sh:40 | `lock_dir` |
| 分析目录 | `/tmp/msp-analytics` | analytics.sh:8 | `analytics_dir` |

### 重构任务

- [ ] **R040** 创建 `Scripts/config/cocoapods-config.yaml`:
  - [ ] R040a: 迁移 CocoaPods URLs (`specs_repo_url`, `cdn_url`)
  - [ ] R040b: 迁移超时设置 (6+ 个值)
  - [ ] R040c: 迁移重试/缓存设置 (5+ 个值)
  - [ ] R040d: 更新 `cocoapods.sh`, `podspec.sh`, `switch-target.sh` 读取配置
- [ ] **R041** 创建 `Scripts/config/build-config.yaml`:
  - [ ] R041a: 迁移 iOS 部署目标 (`15.0`) - 影响 5+ 文件
  - [ ] R041b: 迁移 Swift 版本 (`5.0`, `5.9`) - 影响 6+ 文件
  - [ ] R041c: 迁移架构配置 - 影响 4+ 文件
  - [ ] R041d: 迁移 XCFramework slice 名称 - 影响 2+ 文件
  - [ ] R041e: 迁移构建超时设置
  - [ ] R041f: 更新 `xcode.sh`, `xcframework_builder.sh`, `common.sh` 读取配置
- [ ] **R042** 创建 `Scripts/config/test-config.yaml`:
  - [ ] R042a: 迁移模拟器设备名称 (`iPhone 15`) - 影响 **12+ 文件**
  - [ ] R042b: 迁移模拟器 OS 版本 (`18.5`)
  - [ ] R042c: 更新所有验证/测试脚本读取配置
- [ ] **R043** 创建 `Scripts/lib/config_loader_ext.sh` 支持新配置文件:
  - [ ] R043a: 添加 `load_cocoapods_config()` 函数
  - [ ] R043b: 添加 `load_build_config()` 函数
  - [ ] R043c: 添加 `load_test_config()` 函数
  - [ ] R043d: 提供环境变量覆盖支持
- [X] **R044** 删除未使用的配置文件 (已完成):
  - [X] R044a: 删除 `environments.conf` (0 引用，被 release.yaml profiles 替代)
  - [X] R044b: 删除 `frameworks.conf` (0 引用，被 release.yaml modules 替代)
  - [X] R044c: 删除 `ci-build-stages.yml` (0 引用，包含过期 adapter 名称)

### 预期收益

| 指标 | 当前 | 目标 |
|------|-----|------|
| 硬编码 iOS 版本 | 5+ 处 | 1 处 (配置文件) |
| 硬编码模拟器设备 | 12+ 处 | 1 处 (配置文件) |
| 硬编码超时值 | 20+ 处 | 3 个配置文件 |
| 修改 iOS 版本需改文件 | 5+ 文件 | 1 文件 |
| 修改模拟器需改文件 | 12+ 文件 | 1 文件 |

---

## 执行优先级

### P0 - 立即修复 (阻塞其他工作)
- R001-R004: CDN 验证统一

### P1 - 高优先级 (本迭代完成)
- R007-R010: GitHub Release 整合
- R005-R006: 输入验证统一
- **R024-R027: XCFramework 构建与验证统一** (常用功能，影响面广)
- **R028-R029: XcodeGen 操作统一** (13 文件，无共享模块)
- **R030-R031: Checksum 计算统一** (10 文件，跨平台问题)
- **R040-R043: 全局硬编码值 Config-Driven 改造** (60+ 文件，SSOT 原则)

### P2 - 中优先级 (下迭代)
- R011-R012: Duration 计算统一
- R015-R016: Step 生命周期使用
- R017-R018: 重试逻辑统一
- **R032-R033: SPM 操作统一** (32 文件)
- **R036: CocoaPods 使用执行** (强制使用 cocoapods.sh)

### P3 - 低优先级 (按需)
- R013-R014: Zip 创建评估
- R019-R020: 通知验证
- R021-R023: 其他清理
- **R034-R035: JSON 处理评估** (可选)
- **R037-R039: Notification Render Config-Driven 改造** (1914 行 → 配置驱动)

---

## 预期收益

| 指标 | 当前 | 目标 |
|------|-----|------|
| 重复代码量 | ~3000 行 | ~500 行 |
| 共享模块覆盖率 | 30% | 90% |
| 维护复杂度 | 高 | 低 |
| Bug 修复传播 | 手动 | 自动 |
| 涉及文件数 | 100+ | 集中到 10 个共享模块 |

---

## 下一步

1. 创建重构任务到 tasks.md
2. 按优先级逐个完成
3. 每个任务需要:
   - 单元测试先行 (TDD)
   - 更新调用方
   - 验证端到端流程
