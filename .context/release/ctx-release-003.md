---
id: ctx-release-003
title: Pod 发布后使用方 crash - Kingfisher 静态链接重复
layer: experience
domain: release
tags: [kingfisher, static-linking, xcframework, crash, objc_retain, NovaCore, duplicate-symbol]
created: 2026-02-03
source: commit:a0af08995
status: active
confidence: high
---

# Pod 发布后使用方 crash - Kingfisher 静态链接重复

## 问题描述

发布 MSPNovaAdapter 后，使用方（NewsBreak）在运行时出现 crash：

**症状**：
- App 运行时随机 crash
- 错误类型：`objc_retain` 级别崩溃
- 本地源码集成不 crash，仅 pod 集成时 crash

**触发条件**：
1. MSPNovaAdapter 以 XCFramework 形式发布
2. NovaCore 内部静态链接了 Kingfisher
3. MSPNovaAdapter podspec 声明了 `Kingfisher` 依赖
4. 使用方通过 CocoaPods 拉取了外部 Kingfisher

## 根因分析

问题的本质是**两份 Kingfisher 代码同时存在**导致的运行时冲突：

### 1. NovaCore 静态链接了 Kingfisher

```yaml
# Sources/Core/NovaCore/project.yml.template
OTHER_LDFLAGS:
  - -lMSPKingfisher  # Kingfisher 被编入 NovaCore binary
```

验证方式：
```bash
nm NovaCore.framework/NovaCore | grep -i kingfisher
# 输出大量 Kingfisher 符号，证明已静态链接
```

### 2. NovaAdapter 直接 import 了 Kingfisher

```swift
// NovaAdapter.swift (修复前)
@_implementationOnly import Kingfisher

// 第 186 行
iconView.kf.setImage(with: iconURL)
```

### 3. 发布脚本自动添加了 Kingfisher 依赖

`generate_podspec.sh` 扫描 swiftinterface 时检测到 Kingfisher 引用，自动添加：
```ruby
spec.dependency 'Kingfisher', '7.12.0'
```

### 4. 结果：运行时两份 Kingfisher

```
NovaCore.xcframework
  └─ 内嵌 Kingfisher 代码（静态链接）

CocoaPods Kingfisher pod
  └─ 外部 Kingfisher 代码

→ 两份 Kingfisher class/metadata 并存
→ objc_retain 级别 crash
```

## 解决方案

**核心思路**：让 NovaAdapter 不再直接依赖 Kingfisher，改用 NovaCore 提供的 API。

### 1. 在 NovaCore 添加图片加载包装 API

```swift
// Sources/Core/NovaCore/NovaCore/UIUtils/NovaImageLoader.swift
import UIKit
@_implementationOnly import Kingfisher

public enum NovaImageLoader {
    public static func setImage(
        for imageView: UIImageView,
        with url: URL?,
        placeholder: UIImage? = nil
    ) {
        imageView.kf.setImage(with: url, placeholder: placeholder)
    }
}
```

### 2. NovaAdapter 移除 Kingfisher 依赖

```swift
// NovaAdapter.swift (修复后)
import Foundation
@_implementationOnly import MSPSnapKit
import MSPiOSCore
import NovaCore  // 通过 NovaCore 间接使用 Kingfisher
import PrebidMobile
import UIKit

// 修改调用方式
NovaImageLoader.setImage(for: iconView, with: iconURL)
```

### 3. 发布脚本配置跳过 Kingfisher 依赖

```bash
# Scripts/release/generate_podspec.sh
KINGFISHER_EMBEDDED_PODS=("MSPNovaAdapter")

# 脚本检测到 Kingfisher 时，会跳过添加依赖
```

### 结果

- NovaAdapter swiftinterface 不再有 Kingfisher 引用
- podspec 不声明 Kingfisher 依赖
- 运行时只有 NovaCore 内嵌的一份 Kingfisher
- 不再 crash

## 与 ctx-release-001 的对比

| 维度 | ctx-release-001 (FB SDK) | ctx-release-003 (Kingfisher) |
|------|--------------------------|------------------------------|
| 问题类型 | 静态链接重复 | 静态链接重复 |
| SDK 位置 | Adapter 直接链接 | Core 内部链接 |
| 解决方案 | Shim Framework | 包装 API + 移除直接依赖 |
| 复杂度 | 高（需创建 shim） | 中（添加包装 API） |

**关键区别**：
- FB SDK 方案需要 shim 因为 Adapter 必须调用 FB SDK API
- Kingfisher 方案更简单因为可以让 NovaCore 暴露包装 API

## 适用场景

1. **内部模块静态链接了第三方库**
   - Core 模块为了性能静态链接了某库
   - Adapter 也需要使用该库的功能

2. **@_implementationOnly import 不够**
   - 该修饰符只隐藏 swiftinterface 的 import
   - 编译后的 binary 仍有符号引用
   - 发布脚本仍可能检测并添加依赖

3. **希望避免创建 shim**
   - 如果被依赖的库已经在 Core 中，可以用包装 API

**关键词**：Kingfisher, static linking, duplicate symbol, NovaCore, @_implementationOnly, wrapper API, objc_retain crash

## 相关资源

- 相关 commit: a0af08995
- 相关文件:
  - `Sources/Core/NovaCore/NovaCore/UIUtils/NovaImageLoader.swift` (新增)
  - `Sources/Adapters/NovaAdapter/NovaAdapter/NovaAdapter.swift` (修改)
  - `Scripts/release/generate_podspec.sh` (KINGFISHER_EMBEDDED_PODS)
- 关联上下文: ctx-release-001 (类似的静态链接问题)
