# ctx-release-004: XCFramework 二进制中版本号未更新

> **Domain**: release
> **Layer**: experience
> **Status**: active
> **Created**: 2026-02-27
> **Root Cause Confirmed**: Yes

## 问题描述

Release 后 XCFramework 二进制中的版本号仍是旧值，涉及三个模块：

| 模块 | 版本来源 | 二进制中的值 | 正确值 |
|------|---------|------------|--------|
| MSPCore | `Config.plist → SDKVersion` | `0.2.1-migration` | release version |
| NovaCore | `NovaConstants.shared.version` | `0.0.0` | release version |
| MSPNovaAdapter | `getSDKVersion()` | 旧值 | release version |

## 根因

**构建时序问题**：XCFramework 构建发生在版本号更新之前，版本号在编译时锁死。

当前顺序（错误）：
```
build XCFramework → update version → zip 打包
```

正确顺序：
```
update version → build XCFramework → zip 打包
```

### 为什么 MSPCore 运行时版本是对的

`getMSPVersion()`（`MSPHelper.swift:366-392`）的读取顺序：
1. 先找 `MSPCoreResources.bundle` → 读到正确版本（CocoaPods 从 zip 的 `Resources/Config.plist` 生成）
2. 找不到才 fallback 到 framework bundle 内嵌的 → 读到旧版本

Zip 包结构：
```
MSPCore-VERSION.zip
├── Binary/MSPCore.xcframework/  (内嵌旧 Config.plist)
└── Resources/Config.plist       (版本正确，zip 打包时从源文件复制)
```

Release podspec 配置了 `resource_bundles`，所以消费方通过 CocoaPods 集成时会生成 `MSPCoreResources.bundle`，读到的版本是对的。但 XCFramework 二进制内嵌的版本仍然是旧的。

## 子问题：NovaConstants.version 更新后未 commit

`release_orchestration.sh:927-941` 调用 tool 更新了 `NovaConstants.shared.version`，但没有 `git add` + `git commit`。

对比其他模块的提交逻辑：
- Adapter SDK version → `commit_adapter_version_updates()` 负责提交 OK
- MSPCore Config.plist → `ensure_mspcore_version_committed()` 负责提交 OK
- **NovaConstants.version → 只有 update，没有 commit** NG

## 修复方向

1. **时序修复**：把所有 version update（`update_config_plist_version`、adapter SDK version、NovaConstants version）统一挪到 build XCFramework 之前
2. **NovaConstants commit**：在 version update 之后加 `git add` + `git commit`，或纳入 `commit_adapter_version_updates()` 逻辑

## 关键文件

- `Scripts/release/publish/pods/lib/release_orchestration.sh:927-941` — NovaConstants update（无 commit）
- `Scripts/release/publish/pods/lib/release_orchestration.sh:1228-1230` — Config.plist update 时序
- `Scripts/release/publish/pods/lib/version_commit.sh` — 版本提交逻辑
- `Scripts/release/utils/version.sh` — `update_config_plist_version()`
- `Sources/Core/MSPCore/MSPCore/MSPHelper.swift:366-392` — `getMSPVersion()` 读取逻辑
- `Sources/Core/NovaCore/NovaCore/NovaConstants.swift:15` — `version = "0.0.0"`
- `Scripts/release/publish/pods/lib/zip_management.sh:437-464` — zip 打包逻辑
