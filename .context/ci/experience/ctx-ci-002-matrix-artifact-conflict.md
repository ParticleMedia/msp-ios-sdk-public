---
id: ctx-ci-002
title: "GitHub Actions Matrix 构建中 Artifact 名称冲突"
domain: ci
layer: experience
tags:
  - github-actions
  - matrix-build
  - artifact-conflict
  - upload-artifact-v4
triggers:
  - "matrix build artifact overwrite conflict"
  - "only last matrix job artifact preserved"
  - "upload-artifact v4 same name conflict"
  - "GitHub Actions matrix artifact naming"
summary: "GitHub Actions v4 matrix builds overwrite same-name artifacts; use unique names with matrix variable"
version: "1.0"
status: active
created: "2026-01-29"
updated: "2026-02-22"
---

# GitHub Actions Matrix 构建中 Artifact 名称冲突

## 问题描述

使用 matrix 策略构建多个模块时，上传 artifact 失败或只有最后一个模块的产物被保留。

**症状**:
- 使用 `overwrite: true`: 只有最后一个 matrix job 的 artifact 存在
- 不使用 `overwrite`: 第二个及后续上传失败，提示 artifact 已存在
- 依赖这些 artifact 的后续 job 找不到所有模块

**触发条件**:
- 使用 GitHub Actions matrix 策略
- 多个 matrix job 上传到相同的 artifact 名称
- `actions/upload-artifact@v4`

## 根因分析

**v4 的行为变更**:
- 默认情况下，同名 artifact 不允许覆盖，第二次上传会失败
- 使用 `overwrite: true` 时，完全替换之前的 artifact（而非合并）

**v3 vs v4 差异**:
- **v3**: 多次上传到同名 artifact 会自动合并内容
- **v4**: 不再支持自动合并，必须使用唯一名称或显式覆盖

**Matrix 场景下的问题**:
```yaml
strategy:
  matrix:
    module: [ModuleA, ModuleB, ModuleC]

- name: Upload
  with:
    name: modules  # ❌ 所有 job 用同一个名字
```

结果：
- 无 `overwrite`: ModuleB 和 ModuleC 上传失败
- 有 `overwrite`: 只保留 ModuleC（最后执行的）

## 解决方案

### 方案 1: 使用唯一的 Artifact 名称（推荐）

为每个 matrix job 生成唯一的 artifact 名称：

```yaml
- name: Upload XCFramework
  uses: actions/upload-artifact@v4
  with:
    name: core-stage3-xcframeworks-${{ matrix.module }}  # 加上 matrix 变量
    path: Build/Staging/core-stage3/
    retention-days: 7
```

**下载方式 A - 使用 gh CLI 模式匹配**（适合模块数量多）:
```yaml
- name: Download All Stage 3 XCFrameworks
  run: |
    mkdir -p Build/ReleaseArtifacts/XCFrameworks
    gh run download ${{ github.run_id }} \
      --pattern "core-stage3-xcframeworks-*" \
      --dir Build/ReleaseArtifacts/XCFrameworks
  env:
    GH_TOKEN: ${{ github.token }}
```

**下载方式 B - 显式下载每个**（适合模块数量少）:
```yaml
- name: Download Stage 3 XCFrameworks (NovaCore)
  uses: actions/download-artifact@v4
  with:
    name: core-stage3-xcframeworks-NovaCore
    path: Build/ReleaseArtifacts/XCFrameworks

- name: Download Stage 3 XCFrameworks (MSPGoogleAdsTypes)
  uses: actions/download-artifact@v4
  with:
    name: core-stage3-xcframeworks-MSPGoogleAdsTypes
    path: Build/ReleaseArtifacts/XCFrameworks
```

### 方案 2: 分别上传，统一打包（不推荐）

在独立的 job 中收集所有 artifact 并重新打包，增加复杂度。

## 适用场景

- GitHub Actions matrix 构建策略
- 多个独立构建产物需要在后续 job 中使用
- 需要所有 matrix job 的产物都可用

**关键词**: `matrix`, `artifact`, `overwrite`, `upload conflict`, `github actions v4`

## 相关资源

- 相关 commit: 9c0a7dbf (fix(ci): use unique artifact names for matrix builds)
- 相关文件: `.github/workflows/ci-pull-request.yml`
- GitHub Actions 文档: https://github.com/actions/upload-artifact#breaking-changes

## 关联 Playbooks

| Playbook | 关系 |
|----------|------|
| [ctx-ci-001](./ctx-ci-001-artifact-structure-loss.md) | 互补 — Artifact 目录结构保持策略 |
| [ctx-sources-004](../../sources/tech/ctx-sources-004-script-best-practices.md) | 上游 — config-driven 和 POSIX 脚本规则 |
