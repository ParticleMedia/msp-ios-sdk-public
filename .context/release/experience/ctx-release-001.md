---
id: ctx-release-001
title: "Pod 发布后使用方启动 crash - FB SDK 静态链接冲突"
domain: release
layer: experience
tags:
  - facebook
  - static-linking
  - xcframework
  - crash
  - symbol-conflict
  - shim-framework
triggers:
  - "FB SDK crash after pod release"
  - "FBFinalClassViolationException on app launch"
  - "duplicate symbol FBAudienceNetwork"
  - "shim framework for static linking"
summary: "FBAudienceNetwork static linking in XCFramework causes duplicate symbol crash; solved with shim framework"
version: "1.0"
status: active
created: "2026-01-29"
updated: "2026-02-22"
---

# Pod 发布后使用方启动 crash - FB SDK 静态链接冲突

## 问题描述

发布 MSPFacebookAdapter 的 XCFramework 后，使用方在集成时出现启动 crash：

**症状**：
- App 启动时立即 crash
- 错误类型：`FBFinalClassViolationException`
- 错误位置：`FBAdSettings` KVO/swizzle 冲突
- 仅在使用方项目同时引用了 FBAudienceNetwork SDK 时发生

**触发条件**：
1. MSPFacebookAdapter 以 XCFramework 形式发布
2. 使用方通过 CocoaPods 也引用了 FBAudienceNetwork
3. App 启动时初始化广告 SDK

## 根因分析

问题的本质是**符号重复**（duplicate symbols）导致的运行时冲突：

1. **Binary XCFramework 静态链接了 FBAudienceNetwork**
   - 我们的 adapter 在构建时将 FB SDK 静态链接进了 binary
   - XCFramework 中包含了完整的 FB SDK 代码

2. **使用方通过 CocoaPods 动态引入了相同的 SDK**
   - 使用方的 Podfile 中声明了 `pod 'FBAudienceNetwork'`
   - CocoaPods 会提供另一份 FBAudienceNetwork 实现

3. **Runtime 符号冲突**
   - 两份 `FBAdSettings` 类同时存在
   - KVO 和 method swizzling 机制检测到类被重复定义
   - 触发 `FBFinalClassViolationException`

**为什么会静态链接？**
- XCFramework 构建时 `FRAMEWORK_SEARCH_PATHS` 指向了 FB SDK 的 binary
- Linker 自动将 framework 内的符号链接进产物
- 使用了 `vendored_frameworks` 导致 CocoaPods 无法管理依赖

## 解决方案

创建 **Shim Framework** 来避免静态链接：

### 方案设计

```
传统方式（会导致静态链接）:
MSPFacebookAdapter.xcodeproj
  └─ FRAMEWORK_SEARCH_PATHS → 真实 FB SDK
      └─ Linker 静态链接 → ❌ 符号嵌入 binary

Shim 方式（避免静态链接）:
MSPFacebookAdapter.xcodeproj
  └─ FRAMEWORK_SEARCH_PATHS → FBAudienceNetwork.framework (shim)
      └─ 仅包含 headers + module.modulemap
      └─ Linker 找不到实现 → -undefined dynamic_lookup
          └─ ✅ 符号留空，runtime 解析
```

### 具体实现

1. **创建 Shim Framework**（`Scripts/xcframeworks/create_fb_shim.sh`）
   ```
   FBAudienceNetwork.framework/
   ├── Headers/           # 从真实 SDK 复制所有头文件
   │   ├── FBAdSettings.h
   │   ├── FBInterstitialAd.h
   │   └── ...
   └── Modules/
       └── module.modulemap  # 定义模块接口
   ```
   - 只包含头文件，不包含任何 binary
   - 提供完整的 API 接口声明
   - 不触发 auto-linking

2. **修改 project.yml.template**
   ```yaml
   FRAMEWORK_SEARCH_PATHS:
     - $(SRCROOT)/Vendors/Shims  # 指向 shim，不是真实 SDK

   OTHER_LDFLAGS:
     - -undefined dynamic_lookup  # 允许 undefined symbols
   ```

3. **构建流程**
   - Xcode 编译时：通过 shim 的 headers 验证 API 调用
   - Linker 时：发现没有 binary，留下 undefined symbols
   - Runtime 时：App 的 FBAudienceNetwork 提供实现

### 结果

- MSPFacebookAdapter.xcframework 不再包含 FB SDK 代码
- 使用方的 FBAudienceNetwork（通过 CocoaPods）成为唯一实现
- 没有符号冲突，没有 crash

## 适用场景

这个方案适用于以下情况：

1. **SDK Adapter 模式**
   - 你的 library 是第三方 SDK 的 adapter/wrapper
   - 不想将第三方 SDK 打包进你的产物

2. **静态库冲突**
   - 第三方 SDK 以静态库形式提供
   - 使用方也会引用相同的 SDK

3. **Symbol 重复问题**
   - 遇到 duplicate symbol 错误
   - Runtime crash 提示类被重复定义

4. **XCFramework 发布**
   - 需要以 binary 形式发布
   - 但依赖的库希望由使用方管理

**关键词**：static linking, duplicate symbol, FBAudienceNetwork, shim framework, -undefined dynamic_lookup

## 相关资源

- 相关 commit: ea820b5a
- 相关文件:
  - `Scripts/xcframeworks/create_fb_shim.sh`
  - `Sources/Adapters/MSPFacebookAdapter/project.yml.template`
  - `Vendors/Shims/FBAudienceNetwork.framework/`
- 相关文档: Xcode Linker flags, CocoaPods vendored_frameworks

## 关联 Playbooks — 静态链接 Duplicate Symbol 系列

本 playbook 是**静态链接 duplicate symbol 三部曲**之一，共享同一根因：XCFramework 静态链接第三方库 → 使用方也引入同一库 → runtime duplicate symbol crash。

| Playbook | 场景 | 解法 |
|----------|------|------|
| **本文 (ctx-release-001)** | FBAudienceNetwork — Adapter 直接依赖第三方 SDK | Shim Framework (headers-only + dynamic_lookup) |
| [ctx-release-003](./ctx-release-003.md) | Kingfisher — Core 内部使用，Adapter 需要功能 | Wrapper API (Core 暴露包装接口) |
| [ctx-integration-001](../../integration/experience/ctx-integration-001-novacore-duplicate-symbols.md) | SnapKit/Kingfisher/Lottie — Core 静态链接多个库 | UNEXPORTED_SYMBOLS_FILE (隐藏符号) |
