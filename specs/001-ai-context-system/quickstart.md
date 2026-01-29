# Quickstart: AI 上下文系统

**Feature**: 001-ai-context-system
**Date**: 2026-01-29

## 概述

AI 上下文系统让你的开发经验可以被沉淀和复用。当你解决了一个棘手的发布问题后，可以将经验保存为"上下文"，下次遇到类似问题时，AI 会自动引用这些经验来更快地帮你解决问题。

## 快速开始

### 1. 初始化上下文库

首次使用时，从现有的 commit 历史中提取发布相关的经验：

```bash
./Scripts/context/init-context.sh
```

这会分析 commit 历史中的 `fix(release)`, `fix(ci)` 等提交，生成候选上下文供你确认。

### 2. 手动添加上下文

当你解决了一个值得记录的问题后：

```
/context.add
```

AI 会引导你填写以下信息：
- **领域 (Domain)**: release / ci / integration / compatibility
- **层级 (Layer)**: business / experience / tech
- **问题描述**: 症状和触发条件
- **根因分析**: 为什么会发生
- **解决方案**: 如何修复
- **相关标签**: 便于检索

### 3. 查看现有上下文

```
/context.list
```

可选参数：
- `--domain release` - 只显示发布相关
- `--tag pod` - 按标签筛选
- `--search "编译失败"` - 关键词搜索

### 4. 让 AI 自动引用上下文

当你询问 AI 关于发布问题时，系统会自动检索相关上下文：

```
用户: Pod 发布后使用方编译失败，提示 duplicate symbol

AI: 根据 [ctx-release-001] 的经验，这个问题通常是由于静态链接冲突导致的...
```

## 层级分类 (Layer)

上下文系统采用**双维度分类**：

### 领域 (Domain) - 业务范围
- `release` - 发布系统: Pod 发布、版本管理
- `ci` - CI/CD: 构建流程、自动化
- `integration` - 集成兼容: 编译链接、crash
- `compatibility` - 版本兼容: 迁移升级

### 层级 (Layer) - 知识类型
- `business` - 业务知识: 产品需求、业务规则
- `experience` - 经验教训: 调试过程、解决方案 (最常用)
- `tech` - 技术知识: API 用法、架构设计

**示例**:
- `domain=release` + `layer=experience` → "Pod 发布失败的调试经验"
- `domain=ci` + `layer=tech` → "GitHub Actions 配置最佳实践"

## 目录结构

```
.context/
├── index.md            # 全局索引（包含 By Layer 和 By Domain 视图）
├── release/            # 发布系统上下文
│   ├── _domain.md      # 领域配置
│   └── ctx-release-001.md  # 包含 layer 字段
├── ci/                 # CI/CD 上下文
├── integration/        # 集成兼容上下文
├── compatibility/      # 版本兼容上下文
└── templates/
    └── entry-template.md  # 模板包含 layer 字段
```

## 常用命令

### 上下文管理
| 命令 | 说明 |
|------|------|
| `/context.add` | 手动添加新上下文（交互式引导） |
| `/context.init` 或 `./Scripts/context/init-context.sh` | 从 commit 历史初始化上下文 |
| `/context.list` 或 `./Scripts/context/list-context.sh` | 列出所有上下文 |
| `./Scripts/context/search-context.sh <keywords>` | 搜索相关上下文 |
| `./Scripts/context/archive-context.sh <id>` | 归档（软删除）上下文 |
| `./Scripts/context/validate-context.sh` | 验证上下文文件完整性 |

### 过滤和搜索示例
| 命令 | 说明 |
|------|------|
| `./Scripts/context/list-context.sh --domain release` | 只显示 release 领域 |
| `./Scripts/context/list-context.sh --layer experience` | 只显示经验教训类 |
| `./Scripts/context/list-context.sh --tag pod` | 按标签筛选 |
| `./Scripts/context/list-context.sh --search crash` | 关键词搜索 |
| `./Scripts/context/list-context.sh --rebuild` | 重建索引 |
| `./Scripts/context/search-context.sh pod release` | 搜索包含 pod 和 release 的上下文 |
| `./Scripts/context/search-context.sh --format ids pod` | 只返回上下文 ID |

## 最佳实践

1. **及时沉淀**: 解决问题后立即记录，细节还清晰时记录最准确
2. **写清根因**: 根因分析是最有价值的部分，要解释"为什么"
3. **标注适用场景**: 帮助后续检索时判断是否相关
4. **保持更新**: 如果解决方案过时了，更新状态为 `deprecated`

## 下一步

- 运行 `/context.list` 查看初始化后的上下文库
- 阅读 [data-model.md](./data-model.md) 了解完整数据结构
- 在 AGENTS.md 中查看触发规则配置
