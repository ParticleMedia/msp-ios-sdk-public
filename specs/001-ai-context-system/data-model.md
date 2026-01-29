# Data Model: AI 上下文系统

**Feature**: 001-ai-context-system
**Date**: 2026-01-29
**Status**: Complete

## Entities

### 1. Context Entry (上下文条目)

单条经验记录，是系统的核心数据单元。

**Storage**: `.context/{domain}/{id}.md`

**Schema** (YAML Front Matter):

```yaml
---
id: string          # 唯一标识符，格式: ctx-{domain}-{sequence}
                    # 例: ctx-release-001, ctx-ci-003
title: string       # 条目标题，简洁描述问题
layer: enum         # 层级分类: business | experience | tech（正交于领域）
domain: string      # 所属领域，可扩展（初期: release | ci | integration | compatibility，后续: sources | architecture | testing 等）
tags: string[]      # 标签列表，用于细粒度分类
created: date       # 创建日期，格式: YYYY-MM-DD
updated: date       # 最后更新日期 (可选)
source: string      # 来源，格式: commit:{hash} | manual | conversation:{id}
status: enum        # 状态: active | archived | deprecated
confidence: enum    # 置信度: high | medium | low (AI 生成时标注)
---
```

**Body Sections** (Markdown):

```markdown
# {title}

## 问题描述
简洁描述遇到的问题，包括症状和触发条件。

## 根因分析
深入分析问题的根本原因，解释"为什么"会发生。

## 解决方案
具体的解决步骤或修复方法。

## 适用场景
描述什么情况下这个上下文是相关的，包括关键词和条件。

## 相关资源 (可选)
- 相关 commit: {hash}
- 相关文件: {path}
- 相关文档: {link}
```

**Validation Rules**:
- `id` 必须唯一，且符合 `ctx-{domain}-{seq}` 格式
- `domain` 必须是已配置的领域（存在对应的 `_domain.md` 文件）
- `created` 必须是有效日期
- Body 必须包含"问题描述"、"根因分析"、"解决方案"三个必需节
- `source` 为 `commit:` 时，hash 必须存在于 git 历史中

---

### 2. Context Layer (上下文层级)

三层分类体系，与领域分类正交，用于区分知识类型。

**层级定义**:

| Layer | Name | Description | 适用内容 |
|-------|------|-------------|----------|
| `business` | 业务知识 | 产品需求、业务规则、用户场景 | "为什么要这样做"、产品决策、业务约束 |
| `experience` | 经验教训 | 调试过程、踩坑记录、解决方案 | "我们踩过的坑"、调试技巧、最佳实践 |
| `tech` | 技术知识 | API 用法、架构设计、设计模式 | "如何实现"、技术细节、代码示例 |

**层级选择指南**:

- 如果内容回答 "为什么产品/业务要这样" → `business`
- 如果内容回答 "我们以前遇到过什么问题，怎么解决的" → `experience`
- 如果内容回答 "技术上应该怎么做" → `tech`

**注意**: 层级分类在目录结构中不体现（仍按 domain 组织），而是作为 YAML front matter 中的字段存储。

---

### 3. Context Domain (上下文领域)

领域分类，用于组织和检索上下文。

**Storage**: `.context/{domain}/_domain.md`

**Schema**:

```yaml
---
name: string        # 领域名称，用于显示
id: string          # 领域 ID，可扩展（例: release, ci, integration, compatibility, sources, architecture）
description: string # 领域描述
keywords: string[]  # 触发关键词列表，用于自动加载
---
```

**Body**:

```markdown
# {name}

## 描述
{description}

## 适用范围
描述什么类型的问题属于这个领域。

## 触发关键词
以下关键词出现在用户问题中时，应自动检索此领域的上下文:
- keyword1
- keyword2
- ...
```

**Domain Registry** (可扩展):

**Phase 1 领域** (初期实现):

| ID | Name | Keywords (初始) |
|----|------|-----------------|
| `release` | 发布系统 | release, pod, podspec, xcframework, 发布, 版本 |
| `ci` | CI/CD | ci, cd, build, 构建, github actions, workflow |
| `integration` | 集成兼容 | integration, 集成, crash, 编译, compile, linker |
| `compatibility` | 版本兼容 | compatibility, 兼容, migration, 升级, deprecate |

**Phase 2+ 领域** (后续扩展):

| ID | Name | Keywords (计划) |
|----|------|-----------------|
| `sources` | 业务逻辑 | MVVM, ViewModel, Repository, 网络层, BidLoader, AdAdapter |
| `architecture` | 架构决策 | 架构, 设计模式, protocol, 解耦, 模块化 |
| `testing` | 测试策略 | Quick, Nimble, 单元测试, mock, stub |

**添加新领域**: 在 `.context/{new-domain}/` 目录下创建 `_domain.md` 配置文件即可，无需修改代码。

---

### 3. Context Index (上下文索引)

全局索引文件，用于快速检索。

**Storage**: `.context/index.md`

**Schema** (Markdown Table):

```markdown
# Context Index

> **Last Updated**: {date}
> **Total Entries**: {count}

## By Domain

### Release ({count})
| ID | Title | Tags | Created | Status |
|----|-------|------|---------|--------|
| ctx-release-001 | ... | ... | ... | active |

### CI ({count})
| ID | Title | Tags | Created | Status |
|----|-------|------|---------|--------|
| ctx-ci-001 | ... | ... | ... | active |

[... other domains ...]

## Recent Updates

| ID | Title | Updated | Change |
|----|-------|---------|--------|
| ctx-release-001 | ... | 2026-01-29 | created |
```

**Auto-Generation**: 索引由 `list-context.sh --rebuild` 自动生成，不应手动编辑。

---

### 4. Context Trigger Rule (触发规则)

定义 AI 何时应主动提示沉淀或自动加载上下文。

**Storage**: 直接写入 `AGENTS.md` (非独立文件)

**Schema** (Markdown Section in AGENTS.md):

```markdown
## 7. Context System Rules

### 7.1 自动加载触发

当用户问题涉及以下关键词时，AI 应自动检索相关上下文:
- 检索 `.context/{domain}/` 下匹配的条目
- 在回答开头引用相关上下文: "根据 [ctx-xxx] 的经验..."

**触发关键词映射**:
| 关键词 | 检索领域 |
|--------|----------|
| release, pod, podspec | release |
| ci, build, workflow | ci |
| crash, compile, link | integration |

### 7.2 沉淀提示触发

当满足以下条件时，AI 应主动提示用户考虑沉淀上下文:

1. **调试完成**: 经过 3+ 轮对话才解决的技术问题
2. **根因发现**: 对话中出现"原来是因为"、"问题出在"等模式
3. **领域匹配**: 问题涉及 release/ci/integration 领域
4. **非重复**: 检索现有上下文未找到高度相似的条目

**提示格式**:
```
💡 这个经验可能值得沉淀！
建议保存为上下文，以便下次遇到类似问题时快速引用。
运行 `/context.add` 开始记录。
```
```

---

## Relationships

```
┌─────────────────┐
│  Context Index  │ ←── 自动生成
│   (index.md)    │
└────────┬────────┘
         │ references
         ▼
┌─────────────────┐      belongs to      ┌─────────────────┐
│  Context Entry  │ ──────────────────► │  Context Domain │
│  (*.md files)   │                      │  (_domain.md)   │
└─────────────────┘                      └─────────────────┘
         │
         │ governed by
         ▼
┌─────────────────┐
│  Trigger Rules  │
│  (in AGENTS.md) │
└─────────────────┘
```

---

## State Transitions

### Context Entry States

```
       ┌─────────┐
       │ (none)  │
       └────┬────┘
            │ create
            ▼
       ┌─────────┐
       │ active  │ ◄──────────────────┐
       └────┬────┘                    │
            │                         │
      ┌─────┴─────┐           restore │
      │           │                   │
archive│     deprecate                │
      │           │                   │
      ▼           ▼                   │
┌──────────┐ ┌────────────┐           │
│ archived │ │ deprecated │───────────┘
└──────────┘ └────────────┘
```

- **active**: 正常可用状态
- **archived**: 归档状态，不在检索结果中显示，但保留文件
- **deprecated**: 已过时，可能有更新的替代条目

---

## File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Context Entry | `.context/{domain}/ctx-{domain}-{seq}.md` | `.context/release/ctx-release-001.md` |
| Domain Config | `.context/{domain}/_domain.md` | `.context/release/_domain.md` |
| Index | `.context/index.md` | `.context/index.md` |
| Entry Template | `.context/templates/entry-template.md` | - |

**Sequence Numbers**:
- 3 位数字，从 001 开始
- 按创建顺序递增
- 删除条目后编号不回收

---

## Sample Data

### Sample Context Entry

**File**: `.context/release/ctx-release-001.md`

```markdown
---
id: ctx-release-001
title: Pod 发布后使用方编译失败 - FB SDK 静态链接冲突
domain: release
tags: [pod, facebook, static-linking, xcframework]
created: 2026-01-15
source: commit:ea820b5a
status: active
confidence: high
---

# Pod 发布后使用方编译失败 - FB SDK 静态链接冲突

## 问题描述

发布新版本的 MSPFacebookAdapter pod 后，使用方在集成时出现编译错误：
- duplicate symbol `_OBJC_CLASS_$_FBSDKSomething`
- 原因是 FB SDK 被静态链接了两次

## 根因分析

Facebook SDK 在某些版本默认以静态库形式提供。当我们的 adapter 和使用方的项目都引用了 FB SDK 时，
会导致符号重复。问题的核心是我们的 podspec 没有正确处理这种情况。

## 解决方案

1. 创建 shim framework 避免直接链接 FB SDK 静态库
2. 修改 podspec 使用 `dependency` 而非 `vendored_frameworks`
3. 确保 FB SDK 只在使用方项目中链接一次

具体实现见 commit ea820b5a。

## 适用场景

- 发布包含第三方 SDK adapter 的 pod 时
- 第三方 SDK 提供静态库形式
- 使用方项目也引用了相同的第三方 SDK

## 相关资源

- 相关 commit: ea820b5a
- 相关文件: Sources/Adapters/FacebookAdapter/
```

### Sample Domain Config

**File**: `.context/release/_domain.md`

```markdown
---
name: 发布系统
id: release
description: 与 SDK 发布流程相关的经验，包括 Pod 发布、版本管理、发布后集成问题
keywords: [release, pod, podspec, xcframework, 发布, 版本, publish, trunk]
---

# 发布系统

## 描述

本领域涵盖所有与 MSP SDK 发布流程相关的经验教训，包括但不限于：
- CocoaPods 发布 (pod trunk push)
- XCFramework 构建和打包
- 版本号管理
- 发布后使用方集成问题

## 适用范围

以下类型的问题属于此领域：
- Pod 发布失败
- 发布后使用方编译/链接错误
- 发布后使用方启动 crash
- 版本兼容性问题
- podspec 配置问题

## 触发关键词

以下关键词出现在用户问题中时，应自动检索此领域的上下文：
- release
- pod
- podspec
- publish
- trunk
- xcframework
- 发布
- 版本
```
