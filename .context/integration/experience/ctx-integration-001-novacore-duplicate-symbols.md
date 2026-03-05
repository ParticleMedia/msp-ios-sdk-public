---
id: ctx-integration-001
title: "NovaCore.xcframework 静态链接第三方库导致使用方 duplicate symbol crash"
domain: integration
layer: experience
tags:
  - duplicate-symbol
  - xcframework
  - static-linking
  - novacore
  - unexported-symbols
  - snapkit
  - kingfisher
  - omsdk
  - prebidmobile
triggers:
  - "NovaCore duplicate symbol crash with SnapKit or Kingfisher"
  - "xcframework static link third-party library conflict"
  - "UNEXPORTED_SYMBOLS_FILE usage for symbol hiding"
  - "host app duplicate symbol linker error"
  - "OMSDK duplicate class warning"
  - "PrebidMobile OMID class conflict"
summary: "NovaCore statically links SnapKit/Kingfisher causing duplicate symbols; solved with UNEXPORTED_SYMBOLS_FILE. OMSDK deduplication solved by switching PrebidMobile to dynamic linking."
version: "2.0"
status: active
created: "2026-02-15"
updated: "2026-03-03"
---

# NovaCore.xcframework 静态链接第三方库导致使用方 duplicate symbol crash

## 问题描述

SDK 使用方集成 `NovaCore.xcframework` 后，如果宿主 App 也使用了 SnapKit 或 Kingfisher，会在链接阶段或运行时出现 **duplicate symbol crash**。

**症状**：
- 链接器报 `duplicate symbol '_$s7SnapKit...'` 或 `'_$s10Kingfisher...'`
- 运行时 crash：`duplicate class in flat namespace`

**触发条件**：
- NovaCore.xcframework 以 XCFramework 形式发布（release 模式）
- 宿主 App 同时使用 SnapKit / Kingfisher 中的任一库

**重要区分 — Dev 模式 vs Release 模式**：
- **Dev 模式（CocoaPods workspace）**：不会出现此问题。MSPKingfisher、MSPSnapKit 是独立的 Pod wrapper，和宿主 App 的依赖各自独立编译
- **Release 模式（XCFramework 构建）**：NovaCore 通过 `OTHER_LDFLAGS` 静态链接 `-lMSPKingfisher -lMSPSnapKit`，这些符号会被嵌入到 `NovaCore.xcframework` 的二进制中，和宿主 App 的同名库冲突

## 根因分析

NovaCore 在 release 构建时，通过 `project.yml.template` 配置了：
```yaml
OTHER_LDFLAGS:
  - -lMSPKingfisher
  - -lMSPSnapKit
```

这使得 Kingfisher/SnapKit 的所有符号被**静态链接**进 `NovaCore.framework` 二进制。当 XCFramework 发布后，这些符号在全局符号表中可见，导致和宿主 App 中相同库的符号冲突。

**关键洞察**：问题只在 **release/发布** 流程中出现，dev 模式因为 CocoaPods workspace 的隔离机制不受影响。排查时如果只在 dev 模式测试，会误以为没问题。

## 解决方案

### 方案一：UNEXPORTED_SYMBOLS_FILE（推荐，当前采用）

1. **创建 `unexported_symbols.txt`**（放在 NovaCore 源码目录）：
   ```
   # Hide MSPSnapKit symbols (module name: MSPSnapKit, 10 chars in Swift mangling)
   _$s10MSPSnapKit*
   _$s*10MSPSnapKit*
   _$sSo*10MSPSnapKit*
   _$sSo*MSPSnapKit*
   # Also match raw SnapKit references (7 chars) as fallback
   _$s7SnapKit*
   _$s*7SnapKit*
   _$sSo*7SnapKit*
   _$sSo*SnapKit*
   _OBJC_CLASS_$_*SnapKit*
   _OBJC_METACLASS_$_*SnapKit*
   _OBJC_CLASS_$_*MSPSnapKit*
   _OBJC_METACLASS_$_*MSPSnapKit*

   # Hide Kingfisher symbols
   _$s10Kingfisher*
   _$s*10Kingfisher*
   _OBJC_CLASS_$_*Kingfisher*
   _OBJC_METACLASS_$_*Kingfisher*
   ```

   **重要**：MSPSnapKit 的 Swift mangling 前缀是 `_$s10MSPSnapKit*`（10 字符模块名），而非 `_$s7SnapKit*`（7 字符）。之前只用 7 字符 pattern 导致 564 个符号泄漏。

2. **在 `project.yml.template` 添加 build setting**：
   ```yaml
   UNEXPORTED_SYMBOLS_FILE: $(SRCROOT)/unexported_symbols.txt
   ```

3. **NovaAdapter 移除直接依赖**：
   - 移除 `import MSPSnapKit`，用原生 `NSLayoutConstraint` 替换 `snp.makeConstraints`
   - 移除 `import Kingfisher`，用 `NovaImageLoader`（NovaCore 暴露的 wrapper API）替换 `kf.setImage`
   - 从 NovaAdapter 的 `project.yml.template` 移除 Kingfisher/SnapKit/Shimmer xcframework 依赖

### 方案二：@_implementationOnly import（已部分采用，配合方案一）

在 NovaCore 中使用 `@_implementationOnly import Kingfisher` 确保 Kingfisher 的 API 不暴露在 NovaCore 的公开接口中。但这**不能解决符号冲突**——只解决 API 可见性问题。必须配合 `UNEXPORTED_SYMBOLS_FILE` 才能完整解决。

## 已解决的历史问题

### Lottie 重复（已通过移除依赖解决 — 2026-03-03）

NovaCore 之前静态链接了 lottie-ios（2,858 个符号，151 个 ObjC 类），与宿主 App 的 Lottie 在 ObjC runtime 层面冲突。解决方案是**彻底移除 lottie-ios 依赖**，用纯 UIView/CAAnimation 实现（`NovaAdTapToTryAnimationView`）替代 Lottie JSON 动画。

### OMSDK 重复（已通过动态链接解决 — 2026-03-03）

`PrebidMobile.xcframework` 静态链接了 `OMSDK-Static_Newsbreak1`，导出 38 个 `OMIDNewsbreak1*` ObjC 类，与 MSPNovaAdapter 分发的 `OMSDK_Newsbreak1.xcframework` 中相同的 38 个类冲突。解决方案：
1. 修改 PrebidMobile fork，改为**动态链接**外部 `OMSDK_Newsbreak1.xcframework`
2. 将 OMSDK 的分发从 MSPNovaAdapter 统一移到 MSPSharedLibraries

## 适用场景

以下情况应检索此上下文：
- SDK 使用方报告 `duplicate symbol` 错误
- 新增第三方库被静态链接到 xcframework 中
- 修改 NovaCore 的依赖链或构建配置
- 发布后使用方出现链接或运行时 crash
- 关键词：duplicate symbol, xcframework, static link, 符号冲突, NovaCore crash

## 检查清单

发布前确认：
- [ ] `unexported_symbols.txt` 包含所有被静态链接的第三方库符号
- [ ] MSPSnapKit 的 pattern 使用 `_$s10MSPSnapKit*`（10 字符模块名）
- [ ] `project.yml.template` 配置了 `UNEXPORTED_SYMBOLS_FILE`
- [ ] NovaAdapter 不直接 import 任何被 NovaCore 内部使用的第三方库
- [ ] 新增的第三方静态链接库已添加到 `unexported_symbols.txt`
- [ ] PrebidMobile.xcframework 不包含 OMSDK 符号（`nm -g | grep OMID` 应全为 `U`）

## 相关资源

- 原始修复 commit: `d1bac8c2074ad7b660f75af43bc0e8bfb770eb04` (release/3.0.x 分支)
- MSPSnapKit 符号泄漏修复: `e7e485b2b` (feature/fix_duplicate_dependency)
- OMSDK 去重修复: `32b696b9a` (feature/fix_duplicate_dependency)
- Lottie 移除: `91feca49f` (feature/fix_duplicate_dependency)
- 适配到 1.0.4 分支的文件：
  - `Sources/Core/NovaCore/unexported_symbols.txt`
  - `Sources/Core/NovaCore/project.yml.template`
  - `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift`
  - `Sources/Adapters/NovaAdapter/project.yml.template`
- 构建脚本: `Scripts/xcframeworks/build_module.sh`
- NovaCore 构建模块: `Scripts/release/publish/pods/lib/novacore_build.sh`

## 关联 Playbooks — 静态链接 Duplicate Symbol 系列

本 playbook 是**静态链接 duplicate symbol 三部曲**之一，共享同一根因：XCFramework 静态链接第三方库 → 使用方也引入同一库 → runtime duplicate symbol crash。

| Playbook | 场景 | 解法 |
|----------|------|------|
| [ctx-release-001](../../release/experience/ctx-release-001.md) | FBAudienceNetwork — Adapter 直接依赖第三方 SDK | Shim Framework (headers-only + dynamic_lookup) |
| [ctx-release-003](../../release/experience/ctx-release-003.md) | Kingfisher — Core 内部使用，Adapter 需要功能 | Wrapper API (Core 暴露包装接口) |
| **本文 (ctx-integration-001)** | SnapKit/Kingfisher — Core 静态链接多个库 | UNEXPORTED_SYMBOLS_FILE (隐藏符号) |
