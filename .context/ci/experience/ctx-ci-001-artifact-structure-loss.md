---
id: ctx-ci-001
title: GitHub Actions Artifact 上传导致 XCFramework 结构丢失
layer: experience
domain: ci
tags: [github-actions, artifact, xcframework, info-plist, v4]
created: 2026-01-29
source: manual
status: active
confidence: high
---

# GitHub Actions Artifact 上传导致 XCFramework 结构丢失

## 问题描述

在 GitHub Actions CI 中，构建的 XCFramework 上传为 artifact 后，下载时出现 `Info.plist not found` 错误，导致后续构建失败。

**症状**:
- 单个 XCFramework 上传下载正常
- 多个 XCFramework 上传到同一 artifact 后，下载时结构混乱
- Info.plist 被后续下载覆盖或丢失
- Adapter 构建失败，提示找不到 Info.plist

**触发条件**:
- 使用 `actions/upload-artifact@v4`
- 上传包含 `.xcframework` 目录的构建产物
- 多次上传或 matrix 构建场景

## 根因分析

`actions/upload-artifact@v4` 的行为变更：
- **上传**: 上传的是目录的**内容**，而非目录本身
- **下载**: 直接解压到目标路径，不保留顶层目录名

**具体流程**:
1. 上传 `Build/ReleaseArtifacts/XCFrameworks/Module.xcframework/`
2. Artifact 中存储：`ios-arm64/`, `ios-arm64_x86_64-simulator/`, `Info.plist`（没有 `.xcframework` 包装）
3. 下载到 `Build/ReleaseArtifacts/XCFrameworks/` 时，文件直接解压到该目录
4. 多个 XCFramework 的平台目录混在一起，Info.plist 互相覆盖

**关键点**:
- XCFramework 需要保持 `Module.xcframework/` 这一层目录结构
- GitHub Actions v4 不会自动保留这个结构

## 解决方案

使用 **staging directory** 保留 `.xcframework` 目录结构：

```yaml
# 上传步骤
- name: Prepare XCFramework for Upload
  run: |
    mkdir -p Build/Staging/core-stage1
    cp -R "Build/ReleaseArtifacts/XCFrameworks/$MODULE.xcframework" Build/Staging/core-stage1/

- name: Upload XCFramework
  uses: actions/upload-artifact@v4
  with:
    name: core-stage1-xcframeworks
    path: Build/Staging/core-stage1/  # 上传整个 staging 目录
    retention-days: 7
```

**效果**:
- Artifact 中存储：`Module.xcframework/ios-arm64/`, `Module.xcframework/Info.plist`
- 下载时保留完整的 `.xcframework` 目录结构

**下载不需要特殊处理**:
```yaml
- name: Download XCFrameworks
  uses: actions/download-artifact@v4
  with:
    name: core-stage1-xcframeworks
    path: Build/ReleaseArtifacts/XCFrameworks/
```

## 适用场景

- GitHub Actions v4 上传包含特定目录结构的构建产物
- XCFramework、Framework、Bundle 等需要保持目录层级的产物
- 多个同类产物需要上传到同一 artifact

**关键词**: `artifact`, `upload-artifact`, `xcframework`, `Info.plist not found`, `directory structure`

## 相关资源

- 相关 commit: b399756c (fix(ci): preserve xcframework directory structure in artifact uploads)
- 相关文件: `.github/workflows/ci-pull-request.yml`
- GitHub Actions 文档: https://github.com/actions/upload-artifact/tree/v4
