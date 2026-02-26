---
id: ctx-ci-003
title: "模块重复构建导致 Swift 编译器 ABI 冲突崩溃"
domain: ci
layer: experience
tags:
  - swift-compiler-crash
  - abi-conflict
  - duplicate-build
  - cocoapods
  - xcframework
  - sil-deserialization
triggers:
  - "Swift compiler crash deserializing SIL function"
  - "duplicate module build ABI conflict"
  - "module in both pod schemes and build stages"
  - "compiler crash PerformanceSILLinker"
summary: "Module built in both pod prebuild and xcframework stages causes Swift compiler ABI conflict crash"
version: "1.0"
status: active
created: "2026-01-29"
updated: "2026-02-22"
---

# 模块重复构建导致 Swift 编译器 ABI 冲突崩溃

## 问题描述

Swift 编译器在链接阶段崩溃，错误信息显示在反序列化 SIL 函数时失败。

**症状**:
- Swift 编译器 crash，输出 stack trace
- 错误信息：`While deserializing SIL function "$s{ModuleName}..."`
- 错误发生在 `PerformanceSILLinker` 阶段
- 提示：`ASSERT_failure` 或 `abort()`

**触发条件**:
- 混合使用 CocoaPods 和 XCFramework
- 同一个模块在多处被构建
- 编译器在多个路径找到同一模块的不同版本

## 根因分析

**根本原因**: 同一个模块被重复构建，产生了两个版本，编译器链接时产生 ABI 不兼容。

**典型场景 - CocoaPods + XCFramework 混用**:

模块 `MSPPrebidAdapter` 同时出现在：
1. `ci-pod-schemes.yml` → 作为 Pod 预构建 → 输出到 `build-shared/Build/Products/Release-iphoneos/MSPPrebidAdapter`
2. `ci-build-stages.yml` → 作为 Adapter XCFramework 构建 → 输出到 `Build/ReleaseArtifacts/XCFrameworks/MSPPrebidAdapter.xcframework`

**编译器行为**:
```
swiftc ... \
  -I /path/to/build-shared/.../MSPPrebidAdapter \  # ← Pod 版本
  -F /path/to/Build/ReleaseArtifacts/XCFrameworks  # ← XCFramework 版本
```

编译器尝试链接时，发现两个版本的模块：
- 它们的 module interface 可能不同（构建时间、优化级别、依赖版本等）
- 在反序列化阶段检测到 ABI 不匹配
- 触发 ASSERT，编译器崩溃

**为什么会有两个版本**:
- Pod 预构建：`prebuild-pod-deps.sh` 读取 `ci-pod-schemes.yml`
- XCFramework 构建：按照 `ci-build-stages.yml` 的 adapters 列表构建

如果一个模块同时在两个配置文件中，就会被构建两次。

## 解决方案

### 诊断方法

1. **检查编译器路径**:
   查看编译失败的 log，找到 `swiftc` 的 `-I` 和 `-F` 参数：
   ```
   -I .../build-shared/.../ModuleName      # ← Pod 位置
   -F .../Build/ReleaseArtifacts/XCFrameworks  # ← XCFramework 位置
   ```

   如果同一个模块在两个路径都存在，说明有重复构建。

2. **检查配置文件**:
   ```bash
   grep "ModuleName" Scripts/config/ci-pod-schemes.yml Scripts/config/ci-build-stages.yml
   ```

   如果同时出现在两个文件，确认冲突。

### 修复方法

**原则**: 每个模块只能在一个地方定义。

**判断规则**:
- **Adapter 模块**（业务适配层）→ 应该在 `ci-build-stages.yml` 的 `adapters.modules`
- **第三方 Pod 依赖**（如 SnapKit, Kingfisher）→ 应该在 `ci-pod-schemes.yml`
- **Core 模块**（核心功能层）→ 应该在 `ci-build-stages.yml` 的 stage1-4

**修复步骤**:
1. 从 `ci-pod-schemes.yml` 中移除 Adapter 模块
2. 确保 Adapter 模块只在 `ci-build-stages.yml` 中定义
3. 清理 build cache 重新构建

**示例**:
```yaml
# ci-pod-schemes.yml
schemes:
  - MSPKingfisher      # ✅ 第三方依赖
  - MSPSnapKit         # ✅ 第三方依赖
  - lottie-ios         # ✅ 第三方依赖
  # - MSPPrebidAdapter # ❌ 移除！这是 Adapter，不是 Pod
  - SwiftProtobuf      # ✅ 第三方依赖

# ci-build-stages.yml
adapters:
  modules:
    - MSPPrebidAdapter # ✅ 正确位置
    - MSPFacebookAdapter
    # ...
```

## 级联问题：修复后的连锁反应

**⚠️ 重要**: 移除模块的 Pod 预构建后，可能导致其他依赖这些 Pod XCFrameworks 的 CI job 失败。

### 症状
修复主问题（移除 `MSPPrebidAdapter` 从 `ci-pod-schemes.yml`）后，出现两个新的失败：

1. **consistency-check 失败**:
   ```
   error: local binary target 'MSPSnapKit' at '.../Build/ReleaseArtifacts/XCFrameworks/MSPSnapKit.xcframework' does not contain a binary artifact.
   ```

2. **unit-tests 失败**:
   ```
   error: The workspace named "msp-ios-sdk" does not contain a scheme named "MSPTests".
   ```

### 根因
这两个 job 原本依赖 Pod 预构建产生的第三方 XCFrameworks（MSPSnapKit, PrebidMobile 等），但它们的工作流缺少必要的设置步骤：

- `consistency-check`: 只下载了构建产物，没有运行 Pod 安装和预构建
- `unit-tests`: 没有在 Pod 安装后重新生成 workspace 和 schemes

### 修复方法

**consistency-check job 需要添加**:
```yaml
- name: Setup Ruby
- name: Ensure XcodeGen
- name: Cache CocoaPods
- name: Install Root Dependencies
  run: bash Scripts/ci/install-pods.sh --repo-update
- name: Pre-build Pod Dependencies
  run: bash Scripts/ci/prebuild-pod-deps.sh
```

**unit-tests job 需要添加**:
```yaml
- name: Regenerate Workspace After Pod Install
  run: bash Scripts/ci/regenerate-workspace.sh
- name: Verify Workspace and Schemes
  run: bash Scripts/ci/validate-workspace-schemes.sh msp-ios-sdk.xcworkspace
```

### 经验教训

**配置变更的完整性检查清单**:
1. ✅ 修复直接问题（移除重复定义）
2. ✅ 识别所有依赖该配置的 CI jobs
3. ✅ 确保这些 jobs 有替代方案获取依赖
4. ✅ 验证完整的 CI pipeline，不只是主构建流程

**关键点**: Pod 预构建不仅为主构建提供依赖，也为其他验证性 jobs（consistency-check, unit-tests）提供依赖。移除预构建时，需要确保这些 jobs 也能获取到所需的依赖。

## 适用场景

- CocoaPods + XCFramework 混合构建环境
- Swift 编译器崩溃，提示 SIL 反序列化错误
- 模块在多个构建配置中定义
- CI job 缺少第三方依赖导致失败

**关键词**: `compiler crash`, `SIL`, `ABI conflict`, `duplicate module`, `deserializing SIL function`, `Package.swift validation`, `workspace scheme`

## 相关资源

- 相关 commit:
  - f2bc5ccd (fix(ci): remove MSPPrebidAdapter from pod prebuild schemes)
  - 162a835e (fix(ci): add pod prebuild and workspace regeneration to consistency/unit-test jobs)
- 相关文件:
  - `Scripts/config/ci-pod-schemes.yml`
  - `Scripts/config/ci-build-stages.yml`
  - `Scripts/ci/prebuild-pod-deps.sh`
  - `.github/workflows/ci-pull-request.yml`
- Apple 文档: Swift ABI Stability

## 关联 Playbooks

| Playbook | 关系 |
|----------|------|
| [ctx-sources-004](../../sources/tech/ctx-sources-004-script-best-practices.md) | 上游 — config-driven 构建编排避免重复构建 |
| [ctx-integration-001](../../integration/experience/ctx-integration-001-novacore-duplicate-symbols.md) | 同类 — 另一种 duplicate symbol 场景（静态链接） |
