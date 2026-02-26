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
triggers:
  - "NovaCore duplicate symbol crash with SnapKit or Kingfisher"
  - "xcframework static link third-party library conflict"
  - "UNEXPORTED_SYMBOLS_FILE usage for symbol hiding"
  - "host app duplicate symbol linker error"
summary: "NovaCore statically links SnapKit/Kingfisher/Lottie causing duplicate symbols; solved with UNEXPORTED_SYMBOLS_FILE"
version: "1.0"
status: active
created: "2026-02-15"
updated: "2026-02-22"
---

# NovaCore.xcframework 静态链接第三方库导致使用方 duplicate symbol crash

## 问题描述

SDK 使用方集成 `NovaCore.xcframework` 后，如果宿主 App 也使用了 SnapKit、Kingfisher 或 Lottie，会在链接阶段或运行时出现 **duplicate symbol crash**。

**症状**：
- 链接器报 `duplicate symbol '_$s7SnapKit...'` 或 `'_$s10Kingfisher...'`
- 运行时 crash：`duplicate class in flat namespace`

**触发条件**：
- NovaCore.xcframework 以 XCFramework 形式发布（release 模式）
- 宿主 App 同时使用 SnapKit / Kingfisher / Lottie 中的任一库

**重要区分 — Dev 模式 vs Release 模式**：
- **Dev 模式（CocoaPods workspace）**：不会出现此问题。MSPKingfisher、MSPSnapKit 是独立的 Pod wrapper，和宿主 App 的依赖各自独立编译
- **Release 模式（XCFramework 构建）**：NovaCore 通过 `OTHER_LDFLAGS` 静态链接 `-lMSPKingfisher -lMSPSnapKit -llottie-ios`，这些符号会被嵌入到 `NovaCore.xcframework` 的二进制中，和宿主 App 的同名库冲突

## 根因分析

NovaCore 在 release 构建时，通过 `project.yml.template` 配置了：
```yaml
OTHER_LDFLAGS:
  - -lMSPKingfisher
  - -lMSPSnapKit
  - -llottie-ios
```

这使得 Kingfisher/SnapKit/Lottie 的所有符号被**静态链接**进 `NovaCore.framework` 二进制。当 XCFramework 发布后，这些符号在全局符号表中可见，导致和宿主 App 中相同库的符号冲突。

**关键洞察**：问题只在 **release/发布** 流程中出现，dev 模式因为 CocoaPods workspace 的隔离机制不受影响。排查时如果只在 dev 模式测试，会误以为没问题。

## 解决方案

### 方案一：UNEXPORTED_SYMBOLS_FILE（推荐，当前采用）

1. **创建 `unexported_symbols.txt`**（放在 NovaCore 源码目录）：
   ```
   # Hide SnapKit symbols
   _$s7SnapKit*
   _$s*7SnapKit*
   _OBJC_CLASS_$_*SnapKit*
   _OBJC_METACLASS_$_*SnapKit*

   # Hide Kingfisher symbols
   _$s10Kingfisher*
   _$s*10Kingfisher*
   _OBJC_CLASS_$_*Kingfisher*
   _OBJC_METACLASS_$_*Kingfisher*

   # Hide Lottie symbols
   _$s6Lottie*
   _$s*6Lottie*
   _OBJC_CLASS_$_*Lottie*
   _OBJC_METACLASS_$_*Lottie*
   ```

2. **在 `project.yml.template` 添加 build setting**：
   ```yaml
   UNEXPORTED_SYMBOLS_FILE: $(SRCROOT)/unexported_symbols.txt
   ```

3. **NovaAdapter 移除直接依赖**：
   - 移除 `import MSPSnapKit`，用原生 `NSLayoutConstraint` 替换 `snp.makeConstraints`
   - 移除 `import Kingfisher`，用 `NovaImageLoader`（NovaCore 暴露的 wrapper API）替换 `kf.setImage`
   - 从 NovaAdapter 的 `project.yml.template` 移除 Kingfisher/SnapKit/Lottie/Shimmer xcframework 依赖

### 方案二：@_implementationOnly import（已部分采用，配合方案一）

在 NovaCore 中使用 `@_implementationOnly import Kingfisher` 确保 Kingfisher 的 API 不暴露在 NovaCore 的公开接口中。但这**不能解决符号冲突**——只解决 API 可见性问题。必须配合 `UNEXPORTED_SYMBOLS_FILE` 才能完整解决。

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
- [ ] `project.yml.template` 配置了 `UNEXPORTED_SYMBOLS_FILE`
- [ ] NovaAdapter 不直接 import 任何被 NovaCore 内部使用的第三方库
- [ ] 新增的第三方静态链接库已添加到 `unexported_symbols.txt`

## 相关资源

- 原始修复 commit: `d1bac8c2074ad7b660f75af43bc0e8bfb770eb04` (release/3.0.x 分支)
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
| **本文 (ctx-integration-001)** | SnapKit/Kingfisher/Lottie — Core 静态链接多个库 | UNEXPORTED_SYMBOLS_FILE (隐藏符号) |
