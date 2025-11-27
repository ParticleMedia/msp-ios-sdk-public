# MSP iOS SDK Pods → SPM 统一依赖体系迁移文档

> **文档版本**: 1.0.0  
> **最后更新**: 2024-11-26  
> **适用范围**: MSP iOS SDK v0.0.95+

---

## 目录

1. [背景与问题](#1-背景与问题)
2. [迁移设计目标](#2-迁移设计目标)
3. [新架构设计](#3-新架构设计)
4. [所有新脚本的设计说明](#4-所有新脚本的设计说明)
5. [新的 Package.swift 说明](#5-新的-packageswift-说明)
6. [迁移步骤](#6-迁移步骤开发者如何迁移项目)
7. [如何升级第三方 SDK](#7-如何升级第三方-sdk)
8. [最终目录结构](#8-最终目录结构)
9. [常见问题 FAQ](#9-常见问题faq)

---

## 1. 背景与问题

### 1.1 为什么过去的 SPM 架构不可维护

在本次迁移之前，MSP iOS SDK 的 SPM 支持存在严重的技术债务：

#### 1.1.1 Wrapper Hack 泛滥

```
Sources/Wrappers/
├── FBAudienceNetworkWrapper/
├── InMobiSDKWrapper/
├── IronSourceSDKWrapper/
├── MintegralAdSDKWrapper/
├── MobileFuseSDKWrapper/
├── OpenWrapSDKWrapper/
└── ShimmerWrapper/
```

每个第三方 SDK 都需要一个 Wrapper 模块来"包装"其 XCFramework。这些 Wrapper 模块：
- 增加了 7+ 个额外的 Swift 文件
- 每个都需要独立的 `Package.swift`
- 维护成本极高，容易出错

#### 1.1.2 `#if SWIFT_PACKAGE` 条件编译污染

几乎所有 Adapter 文件都充斥着条件编译：

```swift
#if SWIFT_PACKAGE
import IronSourceSDKWrapper
#else
import IronSource
#endif
```

这导致：
- 代码可读性差
- 测试难度增加
- 容易遗漏某个分支的修改
- CocoaPods 和 SPM 行为不一致

#### 1.1.3 找不到第三方 SDK

SPM 构建时经常出现：
```
error: no such module 'IronSource'
error: cannot find 'FBShimmeringView' in scope
```

原因是：
- 第三方 SDK 的 XCFramework 没有正确放置
- 模块映射（modulemap）缺失或错误
- 依赖链断裂

### 1.2 为什么二进制 XCFramework + SPM 是最难组合

Swift Package Manager 对二进制依赖的支持存在根本性限制：

| 特性 | CocoaPods | SPM |
|-----|-----------|-----|
| binaryTarget 声明依赖 | ✅ 支持 | ❌ 不支持 |
| 动态解析版本 | ✅ 支持 | ❌ 必须显式声明 |
| 运行时链接 | ✅ 自动 | ❌ 需要手动处理 |
| 多模块依赖 | ✅ 自动传递 | ❌ 需要 Wrapper |

**核心问题**：SPM 的 `binaryTarget` 无法声明 `dependencies`。

例如，`MSPCore.xcframework` 内部使用了 `SwiftProtobuf`，但 SPM 无法表达：
```swift
// ❌ 这是无效的 - SPM 不支持
.binaryTarget(
    name: "MSPCore",
    dependencies: ["SwiftProtobuf"],  // 报错！
    path: "Build/XCFrameworks/MSPCore.xcframework"
)
```

### 1.3 Pods 与 SPM 的差异造成什么痛点

| 痛点 | CocoaPods | SPM |
|-----|-----------|-----|
| 依赖解析时机 | 构建时 | 包解析时 |
| 二进制缓存 | 有完善支持 | 基本没有 |
| 版本锁定 | Podfile.lock | Package.resolved |
| 第三方 SDK 分发 | 大多支持 | 很多不支持 |
| Umbrella Header | 自动生成 | 需要手写 |

**最大的痛点**：大多数广告 SDK（Facebook、Mintegral、IronSource 等）**不提供官方 SPM 支持**。

### 1.4 为什么需要重新设计整个依赖体系

旧架构的问题无法通过局部修复解决：

1. **Wrapper 模式不可扩展** - 每增加一个 SDK 就需要新建 Wrapper
2. **版本同步困难** - Pods 和 SPM 使用不同版本
3. **构建失败难以排查** - 条件编译导致两个平台行为不同
4. **无法 Round-Trip** - 从 Pods 切到 SPM 再切回来会失败

**结论**：需要一套**统一的、自动化的、可验证的**依赖体系。

---

## 2. 迁移设计目标

### 2.1 Pods 为唯一真相来源（Single Source of Truth）

```
┌─────────────────────────────────────────────────────────────┐
│                        Podfile                              │
│  (唯一定义所有第三方 SDK 版本的地方)                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      pod install                            │
│  (下载所有依赖到 Pods/)                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  spm_sync_all.sh                            │
│  (从 Pods/ 提取 XCFramework → ThirdParty/)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Package.swift                           │
│  (引用 ThirdParty/ 中的 XCFramework)                        │
└─────────────────────────────────────────────────────────────┘
```

**核心原则**：
- ✅ 只能在 `Podfile` 中修改第三方 SDK 版本
- ❌ 禁止直接修改 `ThirdParty/` 目录
- ❌ 禁止手动编辑 `Package.swift` 的依赖部分

### 2.2 SPM 要与 Pods 完全一致

**版本一致**：
```ruby
# Podfile
pod 'SwiftProtobuf', '~> 1.28.2'
pod 'lottie-ios', '4.5.2'
```

```swift
// Package.swift (必须 exact 匹配)
.package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.28.2"),
.package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.5.2"),
```

**依赖一致**：
- MSPCore 在 Pods 和 SPM 下都依赖 SwiftProtobuf
- NovaCore 在 Pods 和 SPM 下都依赖 Lottie + Shimmer
- NovaAdapter 在 Pods 和 SPM 下都依赖 Kingfisher + SnapKit

**行为一致**：
- 相同的代码路径
- 相同的链接顺序
- 相同的运行时行为

### 2.3 自动化 XCFramework 同步

```bash
# 一条命令完成所有同步
./Scripts/spm-sync/spm_sync_all.sh
```

自动完成：
1. `pod install` - 更新 Pods
2. `extract_from_pods.sh` - 提取 XCFramework
3. `generate_package_swift.sh` - 更新 Package.swift

### 2.4 支持 Round-Trip（Pods ↔ SPM）

```bash
# 从任意状态切换到 Pods
./Scripts/target-switching/switch-target.sh pods

# 从任意状态切换到 SPM  
./Scripts/target-switching/switch-target.sh spm

# 压力测试：多轮切换
./Scripts/target-switching/round-trip-test.sh --stress=3
```

### 2.5 SPM 构建必须零手工依赖

**Fresh Clone 场景**：
```bash
git clone <repo>
cd msp-ios-sdk
./Scripts/target-switching/switch-target.sh spm  # 自动运行 spm_sync_all.sh
xcodebuild -scheme MSPDemoApp-SPM build          # 直接成功
```

不需要任何手动操作。

### 2.6 Core Binary Modules 的 Wrapper 设计目标

由于 SPM 的 `binaryTarget` 无法声明依赖，我们需要 Wrapper 模块：

```swift
// MSPCoreWrapper.swift
import Foundation
@_exported import MSPCore      // 导出 MSPCore 的所有符号
import SwiftProtobuf            // 强制链接 SwiftProtobuf

private let _forceLink: Any.Type = SwiftProtobuf.Message.self
```

**设计目标**：
- 透明包装：使用 `@_exported import` 让 Wrapper 对用户透明
- 强制链接：通过引用符号确保依赖被链接
- 最小侵入：Wrapper 文件只有几行代码

---

## 3. 新架构设计

### 3.1 Pods → XCFramework → SPM 单向同步链路

```
┌────────────────────────────────────────────────────────────────────┐
│                           UPSTREAM                                  │
│                                                                     │
│   Podfile ──────────────────────────────────────────────────────┐  │
│      │                                                          │  │
│      ▼                                                          │  │
│   Podfile.lock (版本锁定)                                        │  │
│      │                                                          │  │
│      ▼                                                          │  │
│   Pods/ (下载的源码和框架)                                        │  │
│      │                                                          │  │
└──────┼──────────────────────────────────────────────────────────┘  │
       │                                                              │
       │ extract_from_pods.sh                                         │
       │                                                              │
       ▼                                                              │
┌────────────────────────────────────────────────────────────────────┐
│                         THIRDPARTY                                  │
│                                                                     │
│   ThirdParty/                                                       │
│   ├── FBAudienceNetwork/FBAudienceNetwork.xcframework              │
│   ├── IronSourceSDK/IronSourceSDK.xcframework                      │
│   ├── InMobiSDK/InMobiSDK.xcframework                              │
│   ├── MobileFuseSDK/MobileFuseSDK.xcframework                      │
│   ├── MintegralAdSDK/                                              │
│   │   ├── MTGSDK.xcframework                                       │
│   │   ├── MTGSDKBidding.xcframework                                │
│   │   ├── MTGSDKBanner.xcframework                                 │
│   │   ├── MTGSDKNewInterstitial.xcframework                        │
│   │   └── MTGSDKInterstitialVideo.xcframework                      │
│   ├── OpenWrapSDK/OpenWrapSDK.xcframework                          │
│   ├── AmazonPublisherServicesSDK/AmazonPublisherServicesSDK.xcf... │
│   ├── PrebidMobile/PrebidMobile.xcframework                        │
│   └── Shimmer/ (源码，非 XCFramework)                              │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
       │                                                              
       │ Package.swift 引用                                           
       │                                                              
       ▼                                                              
┌────────────────────────────────────────────────────────────────────┐
│                           SPM MODE                                  │
│                                                                     │
│   Package.swift                                                     │
│   ├── binaryTarget: ThirdParty/*/....xcframework                   │
│   ├── binaryTarget: Build/XCFrameworks/*.xcframework               │
│   ├── target: MSPCoreLinker (Wrapper)                              │
│   ├── target: NovaCoreLinker (Wrapper)                             │
│   └── target: Sources/Adapters/*                                   │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 ThirdParty/* 目录设计

```
ThirdParty/
├── FBAudienceNetwork/
│   └── FBAudienceNetwork.xcframework/
├── IronSourceSDK/
│   └── IronSourceSDK.xcframework/
├── InMobiSDK/
│   └── InMobiSDK.xcframework/
├── MobileFuseSDK/
│   └── MobileFuseSDK.xcframework/
├── MintegralAdSDK/                          # 多模块 SDK
│   ├── MTGSDK.xcframework/
│   ├── MTGSDKBidding.xcframework/
│   ├── MTGSDKBanner.xcframework/
│   ├── MTGSDKNewInterstitial.xcframework/
│   └── MTGSDKInterstitialVideo.xcframework/
├── OpenWrapSDK/
│   └── OpenWrapSDK.xcframework/
├── AmazonPublisherServicesSDK/
│   └── AmazonPublisherServicesSDK.xcframework/
├── PrebidMobile/
│   └── PrebidMobile.xcframework/
├── MSPKingfisher/                           # 本地 Pod 源码
│   └── ...
└── Shimmer/                                 # ObjC 源码（非 XCFramework）
    ├── LICENSE
    └── Shimmer/
        ├── include/
        │   ├── module.modulemap
        │   ├── Shimmer.h
        │   ├── FBShimmering.h
        │   ├── FBShimmeringView.h
        │   └── FBShimmeringLayer.h
        ├── FBShimmeringView.m
        └── FBShimmeringLayer.m
```

**设计原则**：
- 每个 SDK 一个独立目录
- 目录名 = SDK 名
- XCFramework 名 = SDK 名.xcframework
- 多模块 SDK（如 Mintegral）放在同一目录下

### 3.3 Build/XCFrameworks/* 目录设计

```
Build/XCFrameworks/
├── MSPSharedLibraries.xcframework/   # 核心共享库
├── MSPiOSCore.xcframework/           # iOS 核心
├── NovaCore.xcframework/             # Nova 广告核心
├── MSPCore.xcframework/              # MSP 核心（依赖 SwiftProtobuf）
└── MSPOMSDK.xcframework/             # Open Measurement SDK
```

这些是**内部构建**的 XCFramework，由 `Scripts/xcframeworks/build-core.sh` 生成。

### 3.4 Wrapper Modules 设计

#### MSPCoreWrapper (MSPCoreLinker)

```swift
// Sources/Common/MSPCoreWrapper/MSPCoreWrapper.swift
import Foundation
@_exported import MSPCore
import SwiftProtobuf

// 强制 SwiftProtobuf 被链接
private let _forceSwiftProtobufLink: Any.Type = SwiftProtobuf.Message.self
```

**为什么需要**：
- `MSPCore.xcframework` 内部使用了 SwiftProtobuf
- XCFramework 编译时，SwiftProtobuf 符号是未定义的（undefined symbols）
- SPM 的 binaryTarget 无法声明依赖
- Wrapper 强制链接 SwiftProtobuf，解决符号缺失问题

#### NovaCoreWrapper (NovaCoreLinker)

```swift
// Sources/Common/NovaCoreWrapper/NovaCoreWrapper.swift
import Foundation
@_exported import NovaCore
import Lottie
import Shimmer

private let _forceLottieLink: Any.Type = LottieAnimationView.self
private let _forceShimmerLink: AnyClass? = FBShimmeringView.self
```

**为什么需要**：
- `NovaCore.xcframework` 内部使用了 Lottie 和 Shimmer
- 需要 Wrapper 来确保这两个依赖被正确链接

### 3.5 为什么 Shimmer 使用源码而不是 XCFramework

**历史原因**：
- Facebook Shimmer 是一个纯 Objective-C 库
- 官方仓库已归档，没有 SPM 支持
- 没有官方 XCFramework 分发

**技术原因**：
- Shimmer 只有 4 个文件（2 个 .h，2 个 .m）
- 构建 XCFramework 的成本高于直接包含源码
- 源码方式更容易调试和维护

**实现方式**：
```swift
// Package.swift
.target(
    name: "Shimmer",
    dependencies: [],
    path: "ThirdParty/Shimmer/Shimmer",
    publicHeadersPath: "include"
)
```

### 3.6 为什么 GoogleMobileAds 是唯一直接用 SPM 的第三方库

**原因**：
1. **Google 提供官方 SPM 支持**：
   ```swift
   .package(
       url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
       from: "11.0.0"
   )
   ```

2. **XCFramework 难以获取**：
   - Google 不单独分发 XCFramework
   - 从 Pods 提取后结构不标准

3. **版本更新频繁**：
   - Google Ads SDK 频繁更新
   - 使用 SPM 可以自动获取最新版本

**特殊处理**：
- 创建了 `MSPGoogleAdsTypes` 模块来抽象 API 差异
- CocoaPods 和 SPM 使用不同的类型名（如 `GADBannerView` vs `BannerView`）

### 3.7 为什么 SwiftProtobuf / Lottie 必须 Version Pinning

**问题**：
```swift
// ❌ 错误：使用 from 允许版本漂移
.package(url: "...", from: "1.25.0")
// 可能解析到 1.26.0, 1.27.0, 1.28.0...
```

**后果**：
- Pods 锁定在 1.28.2
- SPM 可能解析到 1.29.0
- 两边行为不一致，可能导致：
  - ABI 不兼容
  - 运行时崩溃
  - 链接错误

**解决方案**：
```swift
// ✅ 正确：使用 exact 严格锁定
.package(url: "...", exact: "1.28.2")
```

**同步机制**：
- `validate_xcframeworks.sh` 会检查 Pods 和 SPM 版本是否一致
- 版本不一致时会报错并阻止构建

---

## 4. 所有新脚本的设计说明

### 4.1 spm_sync_all.sh

**位置**：`Scripts/spm-sync/spm_sync_all.sh`

**作用**：一键完成 Pods → SPM 同步

**执行流程**：
```bash
#!/bin/bash
# 1. 运行 pod install
pod install

# 2. 从 Pods/ 提取 XCFramework 到 ThirdParty/
./Scripts/spm-sync/extract_from_pods.sh

# 3. 生成/更新 Package.swift
./Scripts/spm-sync/generate_package_swift.sh
```

**运行时机**：
- 第三方 SDK 版本变更后
- Fresh clone 后第一次切换到 SPM
- CI 流程中

### 4.2 extract_from_pods.sh

**位置**：`Scripts/spm-sync/extract_from_pods.sh`

**作用**：从 `Pods/` 目录提取 7 大第三方 XCFramework

**提取配置**：
```bash
SDK_CONFIGS=(
  "FBAudienceNetwork:FBAudienceNetwork:FBAudienceNetwork"
  "IronSourceSDK:IronSourceSDK:IronSource"
  "InMobiSDK:InMobiSDK:InMobiSDK"
  "MobileFuseSDK:MobileFuseSDK:MobileFuseSDK"
  "OpenWrapSDK:OpenWrapSDK:OpenWrapSDK"
  "AmazonPublisherServicesSDK:AmazonPublisherServicesSDK:DTBiOSSDK"
)

MINTEGRAL_MODULES=(
  "MTGSDK"
  "MTGSDKBidding"
  "MTGSDKBanner"
  "MTGSDKNewInterstitial"
  "MTGSDKInterstitialVideo"
)
```

**跳过的 SDK**：
- `PrebidMobile`：使用 `ThirdParty/PrebidMobile/` 的规范路径
- `GoogleMobileAds`：使用 SPM 原生支持

**提取逻辑**：
1. 在 `Pods/<PodName>/` 中查找 `.xcframework`
2. 复制到 `ThirdParty/<SDKName>/<SDKName>.xcframework`
3. 验证 `Info.plist` 存在

### 4.3 generate_package_swift.sh

**位置**：`Scripts/spm-sync/generate_package_swift.sh`

**作用**：自动生成本地开发用的 `Package.swift`

**生成内容**：
- 16 个产品定义
- 5 个 Core binaryTarget
- 8+ 个 ThirdParty binaryTarget
- 10 个 Adapter source target
- 3 个 Wrapper target

**版本同步**：
```swift
// 从 Podfile 读取版本，生成 exact 约束
.package(url: "...swift-protobuf...", exact: "1.28.2"),
.package(url: "...lottie-ios...", exact: "4.5.2"),
```

### 4.4 switch-target.sh

**位置**：`Scripts/target-switching/switch-target.sh`

**作用**：在 Pods 和 SPM 模式之间切换

**切换到 SPM 模式**：
```bash
./Scripts/target-switching/switch-target.sh spm
```

流程：
1. 清理 Pods 环境
2. 清理 SPM 缓存
3. 验证 XCFrameworks（失败则自动运行 `spm_sync_all.sh`）
4. 生成 YAML 配置
5. 运行 xcodegen
6. 打开 Xcode

**切换到 Pods 模式**：
```bash
./Scripts/target-switching/switch-target.sh pods
```

流程：
1. 清理 SPM 环境
2. 运行 `pod install`
3. 生成 YAML 配置
4. 运行 xcodegen
5. 打开 Xcode

### 4.5 round-trip-test.sh

**位置**：`Scripts/target-switching/round-trip-test.sh`

**作用**：验证 Pods ↔ SPM 切换的稳定性

**基础用法**：
```bash
./Scripts/target-switching/round-trip-test.sh
# 执行: Pods → SPM → Pods
```

**压力测试**：
```bash
./Scripts/target-switching/round-trip-test.sh --stress=3
# 执行: Pods → SPM → Pods → SPM → Pods → SPM
```

**测试内容**（每个阶段）：
1. 模式切换
2. 环境验证
3. 构建验证

### 4.6 ci_validate.sh

**位置**：`Scripts/ci/ci_validate.sh`

**作用**：完整的 CI 验证流程

**执行步骤**：
```bash
# Step 1: 清理环境
./Scripts/target-switching/cleanup_pods.sh --force
./Scripts/target-switching/cleanup_spm.sh --force

# Step 2: 同步依赖
pod install
./Scripts/spm-sync/spm_sync_all.sh

# Step 3: 验证 XCFramework 和版本
./Scripts/target-switching/validate_xcframeworks.sh

# Step 4: Pods 构建
./Scripts/target-switching/switch-target.sh pods
xcodebuild -workspace ... -scheme MSPDemoApp build

# Step 5: SPM 构建
./Scripts/target-switching/switch-target.sh spm
xcodebuild -project ... -scheme MSPDemoApp-SPM build

# Step 6: Round-trip 压力测试
./Scripts/target-switching/round-trip-test.sh --stress=2
```

### 4.7 validate_xcframeworks.sh

**位置**：`Scripts/target-switching/validate_xcframeworks.sh`

**作用**：验证所有 XCFramework 和依赖版本

**验证内容**：
1. **Core XCFrameworks 存在性**：
   - `Build/XCFrameworks/MSPSharedLibraries.xcframework`
   - `Build/XCFrameworks/MSPiOSCore.xcframework`
   - `Build/XCFrameworks/NovaCore.xcframework`
   - `Build/XCFrameworks/MSPCore.xcframework`
   - `Build/XCFrameworks/MSPOMSDK.xcframework`

2. **ThirdParty XCFrameworks 存在性**：
   - `ThirdParty/PrebidMobile/PrebidMobile.xcframework`
   - `ThirdParty/FBAudienceNetwork/FBAudienceNetwork.xcframework`
   - 等等...

3. **版本一致性检查**：
   ```
   ✓ SwiftProtobuf: Pods=1.28.2, SPM=1.28.2 (match)
   ✓ Lottie: Pods=4.5.2, SPM=4.5.2 (match)
   ```

---

## 5. 新的 Package.swift 说明

### 5.1 产品定义（16 个）

```swift
products: [
    // 顶层产品
    .library(name: "MSPAds", targets: ["MSPCoreLinker", "MSPSharedLibraries", "MSPiOSCore"]),
    
    // Core 模块 (5+1)
    .library(name: "MSPSharedLibraries", targets: ["MSPSharedLibraries"]),
    .library(name: "MSPiOSCore", targets: ["MSPiOSCore"]),
    .library(name: "NovaCore", targets: ["NovaCore"]),
    .library(name: "MSPCore", targets: ["MSPCore"]),
    .library(name: "MSPCoreLinker", targets: ["MSPCoreLinker"]),
    .library(name: "MSPOMSDK", targets: ["MSPOMSDK"]),
    
    // Adapter 模块 (10)
    .library(name: "MSPPrebidAdapter", targets: ["MSPPrebidAdapter"]),
    .library(name: "MSPGoogleAdapter", targets: ["MSPGoogleAdapter"]),
    .library(name: "MSPFacebookAdapter", targets: ["MSPFacebookAdapter"]),
    .library(name: "NovaAdapter", targets: ["NovaAdapter"]),
    .library(name: "AmazonAdapter", targets: ["AmazonAdapter"]),
    .library(name: "UnityAdapter", targets: ["UnityAdapter"]),
    .library(name: "InmobiAdapter", targets: ["InmobiAdapter"]),
    .library(name: "MobilefuseAdapter", targets: ["MobilefuseAdapter"]),
    .library(name: "MintegralAdapter", targets: ["MintegralAdapter"]),
    .library(name: "PubmaticAdapter", targets: ["PubmaticAdapter"]),
]
```

### 5.2 binaryTarget 定义

**来自 Build/XCFrameworks/（内部构建）**：
```swift
.binaryTarget(name: "MSPSharedLibraries", path: "Build/XCFrameworks/MSPSharedLibraries.xcframework"),
.binaryTarget(name: "MSPiOSCore", path: "Build/XCFrameworks/MSPiOSCore.xcframework"),
.binaryTarget(name: "NovaCore", path: "Build/XCFrameworks/NovaCore.xcframework"),
.binaryTarget(name: "MSPCore", path: "Build/XCFrameworks/MSPCore.xcframework"),
.binaryTarget(name: "MSPOMSDK", path: "Build/XCFrameworks/MSPOMSDK.xcframework"),
```

**来自 ThirdParty/（外部提取）**：
```swift
.binaryTarget(name: "PrebidMobile", path: "ThirdParty/PrebidMobile/PrebidMobile.xcframework"),
.binaryTarget(name: "FBAudienceNetwork", path: "ThirdParty/FBAudienceNetwork/FBAudienceNetwork.xcframework"),
.binaryTarget(name: "IronSourceSDK", path: "ThirdParty/IronSourceSDK/IronSourceSDK.xcframework"),
.binaryTarget(name: "InMobiSDK", path: "ThirdParty/InMobiSDK/InMobiSDK.xcframework"),
.binaryTarget(name: "MobileFuseSDK", path: "ThirdParty/MobileFuseSDK/MobileFuseSDK.xcframework"),
.binaryTarget(name: "OpenWrapSDK", path: "ThirdParty/OpenWrapSDK/OpenWrapSDK.xcframework"),
.binaryTarget(name: "AmazonPublisherServicesSDK", path: "ThirdParty/AmazonPublisherServicesSDK/AmazonPublisherServicesSDK.xcframework"),
```

### 5.3 Wrapper Target 设计

```swift
// MSPCore 的 Wrapper - 解决 SwiftProtobuf 链接问题
.target(
    name: "MSPCoreLinker",
    dependencies: [
        "MSPCore",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
    ],
    path: "Sources/Common/MSPCoreWrapper"
),

// NovaCore 的 Wrapper - 解决 Lottie + Shimmer 链接问题
.target(
    name: "NovaCoreLinker",
    dependencies: [
        "NovaCore",
        "Shimmer",
        .product(name: "Lottie", package: "lottie-ios"),
    ],
    path: "Sources/Common/NovaCoreWrapper"
),
```

### 5.4 Mintegral 多 Subspec 处理

Mintegral SDK 由多个模块组成：

```swift
// binaryTarget 定义
.binaryTarget(name: "MTGSDK", path: "ThirdParty/MintegralAdSDK/MTGSDK.xcframework"),
.binaryTarget(name: "MTGSDKBidding", path: "ThirdParty/MintegralAdSDK/MTGSDKBidding.xcframework"),
.binaryTarget(name: "MTGSDKBanner", path: "ThirdParty/MintegralAdSDK/MTGSDKBanner.xcframework"),
.binaryTarget(name: "MTGSDKNewInterstitial", path: "ThirdParty/MintegralAdSDK/MTGSDKNewInterstitial.xcframework"),
.binaryTarget(name: "MTGSDKInterstitialVideo", path: "ThirdParty/MintegralAdSDK/MTGSDKInterstitialVideo.xcframework"),

// Adapter 依赖所有子模块
.target(
    name: "MintegralAdapter",
    dependencies: [
        "MSPSharedLibraries",
        "MSPiOSCore",
        "MTGSDK",
        "MTGSDKBidding",
        "MTGSDKBanner",
        "MTGSDKNewInterstitial",
        "MTGSDKInterstitialVideo",
    ],
    path: "Sources/Adapters/MintegralAdapter/MintegralAdapter"
),
```

---

## 6. 迁移步骤（开发者如何迁移项目）

### 步骤 1：更新 Podfile

确保 Podfile 中的版本是最新的：

```ruby
# 核心依赖（必须与 Package.swift 同步）
pod 'SwiftProtobuf', '~> 1.28.2'
pod 'lottie-ios', '4.5.2'
pod 'Shimmer', '~> 1.0.2'

# 第三方广告 SDK
pod 'Google-Mobile-Ads-SDK', '~> 12.14.0'
pod 'FBAudienceNetwork', '~> 6.14.0'
pod 'IronSourceSDK', '~> 8.6.0'
pod 'InMobiSDK', '~> 10.7.8'
pod 'MobileFuseSDK', '~> 1.9.0'
pod 'MintegralAdSDK', '~> 7.7.0'
pod 'OpenWrapSDK', '~> 4.3.0'
pod 'AmazonPublisherServicesSDK', '~> 4.7.0'
```

### 步骤 2：运行 pod install

```bash
cd /path/to/msp-ios-sdk
pod install
```

验证 `Podfile.lock` 已更新。

### 步骤 3：运行 spm_sync_all.sh

```bash
./Scripts/spm-sync/spm_sync_all.sh
```

这会：
- 重新运行 `pod install`（确保依赖最新）
- 从 `Pods/` 提取 XCFramework 到 `ThirdParty/`
- 更新 `Package.swift`

### 步骤 4：切换到 Pods 模式验证

```bash
./Scripts/target-switching/switch-target.sh pods
```

在 Xcode 中构建 `MSPDemoApp`：
```bash
xcodebuild -workspace msp-ios-sdk.xcworkspace \
  -scheme MSPDemoApp \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### 步骤 5：切换到 SPM 模式验证

```bash
./Scripts/target-switching/switch-target.sh spm
```

在 Xcode 中构建 `MSPDemoApp-SPM`：
```bash
xcodebuild -project Examples/MSPDemoApp/MSPDemoApp.xcodeproj \
  -scheme MSPDemoApp-SPM \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### 步骤 6：运行 Round-Trip 测试

```bash
./Scripts/target-switching/round-trip-test.sh --stress=2
```

期望输出：
```
Round-trip test PASSED! (2 cycle(s))
```

### 步骤 7：通过 CI

```bash
./Scripts/ci/ci_validate.sh
```

期望输出：
```
✓ ALL VALIDATIONS PASSED
```

### 步骤 8：提交代码

```bash
git add -A
git commit -m "chore: Update dependencies and sync SPM"
git push
```

---

## 7. 如何升级第三方 SDK

### 7.1 标准升级流程 (SOP)

```
┌─────────────────────────────────────────────────────────────────┐
│  ❌ 禁止操作                                                     │
│  - 直接修改 ThirdParty/ 目录                                     │
│  - 手动编辑 Package.swift 的 binaryTarget 路径                   │
│  - 从其他来源下载 XCFramework                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ✅ 正确流程                                                     │
│                                                                  │
│  1. 修改 Podfile 中的版本号                                      │
│     pod 'IronSourceSDK', '~> 8.7.0'  # 从 8.6.0 升级             │
│                                                                  │
│  2. 运行 pod install                                             │
│     pod install                                                  │
│                                                                  │
│  3. 运行同步脚本                                                  │
│     ./Scripts/spm-sync/spm_sync_all.sh                          │
│                                                                  │
│  4. 验证 Pods 构建                                               │
│     ./Scripts/target-switching/switch-target.sh pods            │
│     xcodebuild ... -scheme MSPDemoApp build                     │
│                                                                  │
│  5. 验证 SPM 构建                                                │
│     ./Scripts/target-switching/switch-target.sh spm             │
│     xcodebuild ... -scheme MSPDemoApp-SPM build                 │
│                                                                  │
│  6. 运行 Round-Trip 测试                                         │
│     ./Scripts/target-switching/round-trip-test.sh --stress=2    │
│                                                                  │
│  7. 运行 CI 验证                                                 │
│     ./Scripts/ci/ci_validate.sh                                 │
│                                                                  │
│  8. 提交所有变更                                                 │
│     git add Podfile Podfile.lock ThirdParty/ Package.swift      │
│     git commit -m "chore: Upgrade IronSourceSDK to 8.7.0"       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 特殊情况处理

#### 升级 SwiftProtobuf 或 Lottie

这两个库在 Pods 和 SPM 中都使用，需要**同时更新两边**：

1. 修改 `Podfile`：
   ```ruby
   pod 'SwiftProtobuf', '~> 1.29.0'
   ```

2. 修改 `Package.swift`：
   ```swift
   .package(url: "...swift-protobuf...", exact: "1.29.0"),
   ```

3. 运行验证：
   ```bash
   ./Scripts/spm-sync/spm_sync_all.sh
   ./Scripts/target-switching/validate_xcframeworks.sh
   ```

#### 升级 Mintegral（多模块 SDK）

Mintegral 升级后，所有子模块都会更新：

```bash
# Podfile
pod 'MintegralAdSDK', '~> 7.8.0'

# 运行后检查
ls ThirdParty/MintegralAdSDK/
# 应该看到所有子模块都已更新
```

---

## 8. 最终目录结构

```
msp-ios-sdk/
├── Build/
│   └── XCFrameworks/                    # 内部构建的核心 XCFramework
│       ├── MSPSharedLibraries.xcframework/
│       ├── MSPiOSCore.xcframework/
│       ├── NovaCore.xcframework/
│       ├── MSPCore.xcframework/
│       └── MSPOMSDK.xcframework/
│
├── ThirdParty/                          # 第三方依赖（从 Pods 提取）
│   ├── FBAudienceNetwork/
│   │   └── FBAudienceNetwork.xcframework/
│   ├── IronSourceSDK/
│   │   └── IronSourceSDK.xcframework/
│   ├── InMobiSDK/
│   │   └── InMobiSDK.xcframework/
│   ├── MobileFuseSDK/
│   │   └── MobileFuseSDK.xcframework/
│   ├── MintegralAdSDK/
│   │   ├── MTGSDK.xcframework/
│   │   ├── MTGSDKBidding.xcframework/
│   │   ├── MTGSDKBanner.xcframework/
│   │   ├── MTGSDKNewInterstitial.xcframework/
│   │   └── MTGSDKInterstitialVideo.xcframework/
│   ├── OpenWrapSDK/
│   │   └── OpenWrapSDK.xcframework/
│   ├── AmazonPublisherServicesSDK/
│   │   └── AmazonPublisherServicesSDK.xcframework/
│   ├── PrebidMobile/
│   │   └── PrebidMobile.xcframework/
│   ├── MSPKingfisher/                   # 本地 Kingfisher Pod
│   │   └── ...
│   └── Shimmer/                         # ObjC 源码
│       ├── LICENSE
│       └── Shimmer/
│           ├── include/
│           │   ├── module.modulemap
│           │   ├── Shimmer.h
│           │   ├── FBShimmering.h
│           │   ├── FBShimmeringView.h
│           │   └── FBShimmeringLayer.h
│           ├── FBShimmeringView.m
│           └── FBShimmeringLayer.m
│
├── Scripts/
│   ├── spm-sync/                        # SPM 同步脚本
│   │   ├── spm_sync_all.sh              # 一键同步
│   │   ├── extract_from_pods.sh         # 提取 XCFramework
│   │   └── generate_package_swift.sh    # 生成 Package.swift
│   ├── target-switching/                # 模式切换脚本
│   │   ├── switch-target.sh             # 主切换脚本
│   │   ├── round-trip-test.sh           # Round-Trip 测试
│   │   ├── validate_xcframeworks.sh     # 验证脚本
│   │   ├── cleanup_pods.sh              # Pods 清理
│   │   ├── cleanup_spm.sh               # SPM 清理
│   │   └── common.sh                    # 共享函数
│   ├── ci/                              # CI 脚本
│   │   └── ci_validate.sh               # CI 验证流程
│   └── xcframeworks/                    # XCFramework 构建脚本
│       └── build-core.sh                # 构建核心模块
│
├── Sources/
│   ├── Core/                            # 核心模块源码
│   │   ├── MSPSharedLibraries/
│   │   ├── MSPiOSCore/
│   │   ├── NovaCore/
│   │   ├── MSPCore/
│   │   └── MSPOMSDK/
│   ├── Adapters/                        # Adapter 源码（10 个）
│   │   ├── MSPPrebidAdapter/
│   │   ├── MSPGoogleAdapter/
│   │   ├── MSPFacebookAdapter/
│   │   ├── NovaAdapter/
│   │   ├── AmazonAdapter/
│   │   ├── UnityAdapter/
│   │   ├── InmobiAdapter/
│   │   ├── MobilefuseAdapter/
│   │   ├── MintegralAdapter/
│   │   └── PubmaticAdapter/
│   └── Common/                          # 共享模块
│       ├── MSPCoreWrapper/              # MSPCore Wrapper
│       │   └── MSPCoreWrapper.swift
│       ├── NovaCoreWrapper/             # NovaCore Wrapper
│       │   └── NovaCoreWrapper.swift
│       └── MSPGoogleAdsTypes/           # Google Ads 类型抽象
│           └── MSPGoogleAdsTypes.swift
│
├── Examples/
│   └── MSPDemoApp/                      # Demo 应用
│       └── MSPDemoApp.xcodeproj/
│
├── Docs/
│   └── DEPENDENCY_MIGRATION_GUIDE_ZH.md  # 本文档
│
├── Package.swift                        # SPM 包定义
├── Podfile                              # CocoaPods 依赖定义
└── Podfile.lock                         # CocoaPods 版本锁定
```

---

## 9. 常见问题（FAQ）

### Q1: 为什么不能先切到 SPM？

**问题**：
```bash
git clone <repo>
./Scripts/target-switching/switch-target.sh spm
# 报错：binary target does not contain a binary artifact
```

**原因**：
- SPM 需要 `ThirdParty/` 中的 XCFramework
- Fresh clone 后 `ThirdParty/` 是空的（除了 PrebidMobile）
- 这些 XCFramework 不在 Git 中，必须从 Pods 提取

**解决方案**：
新版 `switch-target.sh` 已自动处理：
1. 检测到 XCFramework 缺失
2. 自动运行 `spm_sync_all.sh`
3. 重新验证后继续切换

**手动方式**：
```bash
pod install
./Scripts/spm-sync/spm_sync_all.sh
./Scripts/target-switching/switch-target.sh spm
```

### Q2: 为什么 Shimmer 是一堆 .h/.m 文件？

**原因**：
1. Facebook Shimmer 是纯 Objective-C 库
2. 官方仓库已归档，无 SPM 支持
3. 只有 4 个源文件，直接包含比构建 XCFramework 更简单

**结构**：
```
ThirdParty/Shimmer/
├── LICENSE
└── Shimmer/
    ├── include/
    │   ├── module.modulemap    # 模块映射
    │   ├── Shimmer.h           # Umbrella header
    │   ├── FBShimmering.h
    │   ├── FBShimmeringView.h
    │   └── FBShimmeringLayer.h
    ├── FBShimmeringView.m
    └── FBShimmeringLayer.m
```

**Package.swift 定义**：
```swift
.target(
    name: "Shimmer",
    dependencies: [],
    path: "ThirdParty/Shimmer/Shimmer",
    publicHeadersPath: "include"
)
```

### Q3: 为什么 GoogleMobileAds 是唯一不用 extract 的？

**原因**：
1. Google 提供官方 SPM 支持
2. Google 的 XCFramework 结构不标准，提取后难以使用
3. CocoaPods 和 SPM 的 API 有差异，需要抽象层

**处理方式**：
- SPM：使用官方 SPM 包
  ```swift
  .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "11.0.0")
  ```
- CocoaPods：使用 `Google-Mobile-Ads-SDK`
- 通过 `MSPGoogleAdsTypes` 模块抽象两者的差异

### Q4: Wrapper 为什么不可删除？

**原因**：
SPM 的 `binaryTarget` 无法声明 dependencies。

**示例**：
```swift
// ❌ 无效 - binaryTarget 不支持 dependencies
.binaryTarget(
    name: "MSPCore",
    dependencies: ["SwiftProtobuf"],  // 报错！
    path: "Build/XCFrameworks/MSPCore.xcframework"
)
```

**后果**：
如果删除 `MSPCoreWrapper`：
```
Undefined symbols for architecture arm64:
  "protocol witness table for Foundation.Data : SwiftProtobuf..."
  Referenced from: MSPCore
```

**必须保留的 Wrapper**：
| Wrapper | 依赖 | 原因 |
|---------|------|------|
| MSPCoreLinker | SwiftProtobuf | MSPCore 使用 Protobuf 序列化 |
| NovaCoreLinker | Lottie, Shimmer | NovaCore 使用动画和加载效果 |

### Q5: Pod 版本变更导致 SPM build 失败的根因

**场景**：
```bash
# 修改了 Podfile
pod 'SwiftProtobuf', '~> 1.29.0'

# 只运行了 pod install
pod install

# 切换到 SPM
./Scripts/target-switching/switch-target.sh spm

# 报错
error: SwiftProtobuf version mismatch: Pods=1.29.0, SPM=1.28.2
```

**根因**：
- Pods 更新了，但 Package.swift 没更新
- SPM 还在用旧版本（exact: "1.28.2"）

**解决方案**：
```bash
# 必须运行完整同步
./Scripts/spm-sync/spm_sync_all.sh

# 或手动同步版本
# 1. 查看 Podfile.lock 中的版本
grep SwiftProtobuf Podfile.lock

# 2. 更新 Package.swift
.package(url: "...swift-protobuf...", exact: "1.29.0"),
```

### Q6: 为什么 Adapter 不再有 `#if SWIFT_PACKAGE`？

**旧代码**：
```swift
#if SWIFT_PACKAGE
import IronSourceSDKWrapper
#else
import IronSource
#endif
```

**新代码**：
```swift
import IronSource
```

**原因**：
- Wrapper 已被删除
- SPM 和 Pods 现在使用相同的模块名
- XCFramework 中的模块名就是 `IronSource`

### Q7: 如何添加新的第三方 SDK？

**步骤**：

1. 在 Podfile 中添加：
   ```ruby
   pod 'NewSDK', '~> 1.0.0'
   ```

2. 在 `extract_from_pods.sh` 中添加配置：
   ```bash
   SDK_CONFIGS=(
     ...
     "NewSDK:NewSDK:NewSDK"  # SDK_NAME:POD_NAME:FRAMEWORK_NAME
   )
   ```

3. 运行同步：
   ```bash
   ./Scripts/spm-sync/spm_sync_all.sh
   ```

4. 在 Package.swift 中添加（如果 generate 脚本未自动添加）：
   ```swift
   .binaryTarget(
       name: "NewSDK",
       path: "ThirdParty/NewSDK/NewSDK.xcframework"
   )
   ```

5. 创建 Adapter 使用新 SDK

### Q8: CI 失败时如何排查？

**常见失败原因**：

1. **XCFramework 缺失**：
   ```
   ❌ MISSING: ThirdParty/FBAudienceNetwork/FBAudienceNetwork.xcframework
   ```
   解决：运行 `./Scripts/spm-sync/spm_sync_all.sh`

2. **版本不匹配**：
   ```
   ❌ SwiftProtobuf version mismatch: Pods=1.28.2, SPM=1.25.0
   ```
   解决：更新 Package.swift 中的版本

3. **构建失败**：
   ```
   error: no such module 'MSPCore'
   ```
   解决：检查 `Build/XCFrameworks/` 是否存在，可能需要重新构建

**调试命令**：
```bash
# 检查 XCFramework 状态
./Scripts/target-switching/validate_xcframeworks.sh

# 检查 Pods 版本
grep -E "SwiftProtobuf|lottie-ios" Podfile.lock

# 清理后重试
./Scripts/target-switching/cleanup_pods.sh --force
./Scripts/target-switching/cleanup_spm.sh --force
./Scripts/spm-sync/spm_sync_all.sh
```

---

## 结语

本次迁移实现了 MSP iOS SDK 的依赖体系统一，关键成就：

1. **单一真相来源**：Podfile 是所有版本的唯一定义点
2. **自动化同步**：一条命令完成 Pods → SPM 同步
3. **可验证性**：Round-Trip 测试确保两个平台行为一致
4. **零手工操作**：Fresh clone 后可直接切换到任意模式
5. **清晰的升级路径**：标准 SOP 确保升级不出错

遵循本文档的规范，可以确保 MSP iOS SDK 在 CocoaPods 和 SPM 两个生态系统中都能稳定运行。

