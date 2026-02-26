---
id: ctx-sources-006
title: "Protobuf 生成文件缺少 @_implementationOnly 导致 CI 构建失败"
domain: sources
layer: experience
tags: [protobuf, swift-protobuf, implementation-only, xcframework, swiftinterface, ci, build]
triggers:
  - "cannot load underlying module for 'SwiftProtobuf'"
  - "failed to build module 'MSPCore' for importation"
  - "import SwiftProtobuf"
  - "swiftinterface leak"
  - "protobuf 生成文件"
  - "pb.swift"
  - "protoc post-process"
summary: "protoc 生成的 .pb.swift 默认使用 import SwiftProtobuf，会泄漏到 .swiftinterface，导致消费方 CI 构建失败。需后处理为 @_implementationOnly import。"
version: "1.0"
status: active
created: "2026-02-26"
updated: "2026-02-26"
---

# Protobuf 生成文件缺少 @_implementationOnly 导致 CI 构建失败

## 问题描述

消费方集成 MSPCore.xcframework 后，本地可以正常编译，但 CI 打包机报错：

```
cannot load underlying module for 'SwiftProtobuf'
failed to build module 'MSPCore' for importation
```

## 根因分析

1. `protoc-gen-swift` 生成的 `.pb.swift` 文件默认使用 `import SwiftProtobuf`
2. MSPCore 使用 `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` 构建 XCFramework，会生成 `.swiftinterface`
3. 普通 `import` 会泄漏到 `.swiftinterface` 中，消费方必须也能找到 SwiftProtobuf 模块
4. `@_implementationOnly import` 会把依赖隐藏，不出现在 `.swiftinterface` 中
5. 之前已做过一次批量修复 (commit `874d4a6a6`)，但后续新增的 `ad_bid_lost.pb.swift` (PR #459) 忘记做后处理

**为什么本地没问题？**
- 本地开发用 CocoaPods workspace，SwiftProtobuf 在搜索路径中
- CI 消费方用预构建的 `.xcframework`，SwiftProtobuf 不在搜索路径中

## 解决方案

### 修复步骤

将 `.pb.swift` 文件中的：
```swift
import SwiftProtobuf
```
改为：
```swift
@_implementationOnly import SwiftProtobuf
```

### 自动化脚本

```bash
./Scripts/tools/post-process-protobuf.sh
```

每次用 `protoc` 重新生成 `.pb.swift` 文件后，必须运行此脚本。

### 验证

修复后重新构建 XCFramework，检查 `.swiftinterface` 中不再包含 `import SwiftProtobuf`：

```bash
grep "import SwiftProtobuf" Build/ReleaseArtifacts/XCFrameworks/MSPCore.xcframework/**/*.swiftinterface
# 期望：无输出
```

## 适用场景

- 新增 `.pb.swift` 文件后
- 升级 SwiftProtobuf 版本后重新生成 protobuf 文件
- 消费方报 `cannot load underlying module` 错误时排查

## 防范措施

1. **后处理脚本**: `Scripts/tools/post-process-protobuf.sh` — 每次 protoc 生成后运行
2. **Code Review**: 新增 `.pb.swift` 文件的 PR 必须检查是否有 `@_implementationOnly`
3. **CI 检查**: 可在 CI 中加入 `grep -r "^import SwiftProtobuf" Sources/Core/` 作为 gate

## 相关资源

- 批量修复 commit: `874d4a6a6` (refactor: Use @_implementationOnly import for adapter modules)
- 引入问题的 PR: #459 (Add notifyLoss API to MSP)
- 后处理脚本: `Scripts/tools/post-process-protobuf.sh`
- MSPCoreLinker (SPM workaround): `Sources/Common/MSPCoreWrapper/MSPCoreWrapper.swift`

## 关联 Playbooks

- [ctx-sources-001] Swift 最佳实践 — `@_implementationOnly` 属于 Swift 模块化知识
- [ctx-sources-004] 脚本最佳实践 — 后处理脚本遵循 HR 规则
