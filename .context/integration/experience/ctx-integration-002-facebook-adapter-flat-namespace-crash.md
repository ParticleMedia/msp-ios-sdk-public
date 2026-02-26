---
id: ctx-integration-002
title: "MSPFacebookAdapter mh_dylib + dynamic_lookup 导致 Release strip 后 flat namespace crash"
domain: integration
layer: experience
tags:
  - facebook-adapter
  - dynamic-lookup
  - flat-namespace
  - staticlib
  - mh-dylib
  - linker-crash
triggers:
  - "flat namespace crash after Release strip"
  - "dynamic_lookup causes runtime crash"
  - "mh_dylib vs staticlib adapter choice"
  - "FBAudienceNetwork adapter linking strategy"
summary: "mh_dylib + dynamic_lookup causes flat namespace crash after strip; switch to staticlib + headers-only shim"
version: "1.0"
status: active
created: "2026-02-16"
updated: "2026-02-22"
---

# MSPFacebookAdapter mh_dylib + dynamic_lookup 导致 Release strip 后 flat namespace crash

## 问题描述

MSPFacebookAdapter 在 Release 构建后，宿主 App 集成时运行时 crash。

**症状**：
- Release strip 后出现 flat namespace 相关的 dyld crash
- Debug 模式下不复现，仅 Release strip 后触发

**触发条件**：
- MSPFacebookAdapter 以 `mh_dylib`（动态库）形式构建
- 使用 `-undefined dynamic_lookup` 允许未定义符号
- 宿主 App 链接 FBAudienceNetwork SDK

## 根因分析

之前的方案：
```yaml
MACH_O_TYPE: mh_dylib
OTHER_LDFLAGS: $(inherited) -undefined dynamic_lookup
```

**问题链**：
1. `mh_dylib` 使 MSPFacebookAdapter 编译为动态库
2. `-undefined dynamic_lookup` 告诉链接器允许未解析的 FBAudienceNetwork 符号，运行时再绑定
3. `dynamic_lookup` 使用 **flat namespace** 符号查找（而非 two-level namespace）
4. Release 模式的 `strip` 移除了部分符号信息
5. Strip 后 flat namespace 的运行时符号查找失败 → crash

**关键洞察**：`-undefined dynamic_lookup` 是一个危险的链接器选项。它绕过了 macOS/iOS 的 two-level namespace 安全机制，在 strip 后特别容易出问题。应该尽量避免使用。

## 解决方案

切换为 **staticlib + headers-only shim**：

1. **podspec**：`static_framework = true`（之前是 `false`）
2. **project.yml.template**：`MACH_O_TYPE: staticlib`（之前是 `mh_dylib`）
3. **移除** `OTHER_LDFLAGS: -undefined dynamic_lookup`
4. `FBAudienceNetworkShim` 保留但仅作为 **headers-only** 编译 shim

**原理**：
- `staticlib` 模式下，`ar` 只打包 MSPFacebookAdapter 自身的 `.o` 文件
- FBAudienceNetwork 的符号不会被嵌入 adapter 的静态库中
- 所有 FB 符号在宿主 App link time 通过 CocoaPods 依赖正常解析
- 不需要 `dynamic_lookup`，消除了 flat namespace 风险

## 适用场景

以下情况应检索此上下文：
- Adapter 类模块需要选择 static vs dynamic 链接方式
- 链接器报 flat namespace 相关错误
- `-undefined dynamic_lookup` 出现在构建配置中
- Release strip 后出现运行时 crash 但 Debug 正常
- 关键词：flat namespace, dynamic_lookup, mh_dylib, staticlib, FBAudienceNetwork, strip crash

## 检查清单

新增 Adapter 模块时确认：
- [ ] 使用 `static_framework = true`（除非有明确理由用动态库）
- [ ] 不使用 `-undefined dynamic_lookup`
- [ ] 第三方 SDK 符号在宿主 App link time 解析，不嵌入 adapter 二进制
- [ ] Release + strip 后实际测试验证

## 相关资源

- 修复 commit: `746c123e37a2697bb18a0b5849b4342078caa499`
- 修改文件：
  - `MSPFacebookAdapter.podspec`
  - `Sources/Adapters/MSPFacebookAdapter/project.yml.template`

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-release-001](../../release/experience/ctx-release-001.md) | **互补 — FB SDK 发布侧视角** | 本文解决构建链接方式（mh_dylib→staticlib），release-001 解决发布后符号冲突（shim framework） |
| [ctx-integration-001](../../integration/experience/ctx-integration-001-novacore-duplicate-symbols.md) | **同类 — 符号链接类问题** | NovaCore 的 UNEXPORTED_SYMBOLS_FILE 方案；两者都是 XCFramework 链接策略问题 |
