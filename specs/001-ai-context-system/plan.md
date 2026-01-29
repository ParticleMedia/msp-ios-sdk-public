# Implementation Plan: AI 上下文系统

**Branch**: `001-ai-context-system` | **Date**: 2026-01-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ai-context-system/spec.md`

## Summary

建立一套 AI 上下文管理系统，实现经验知识的自动沉淀、检索和复用。核心目标是通过分层上下文存储和触发规则，让 AI 在处理重复问题时能够"越做越快"——实现知识复利效应。

技术方案采用 Markdown 文件作为上下文存储格式，通过 Bash 脚本实现初始化和管理命令，通过修改 AGENTS.md 添加 AI 行为规则，通过新增 skill 文件实现用户交互命令。

## Technical Context

**Language/Version**: Bash (POSIX-compliant), Markdown
**Primary Dependencies**: Git (commit 历史分析), Grep/Sed (文本处理)
**Storage**: Markdown 文件 (`.context/` 目录)
**Testing**: Manual validation + shell script tests
**Target Platform**: macOS/Linux (CLI 环境)
**Project Type**: Configuration/Documentation (非代码编译项目)
**Performance Goals**: 上下文检索 <2s (500 条记录规模)
**Constraints**: 必须与现有 speckit 工作流兼容，必须遵循 POSIX shell 标准
**Scale/Scope**: 初期 ~50 条上下文记录，目标支持 500+ 条

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Gate Check

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| **Federal I.1** (Automation First) | 重复操作必须脚本化 | ✅ PASS | 上下文初始化和管理都通过脚本实现 |
| **Federal I.2** (Deterministic Builds) | 不直接修改 .xcodeproj | ✅ N/A | 本特性不涉及 Xcode 项目 |
| **Federal I.3** (SSOT) | 单一数据源 | ✅ PASS | `.context/` 目录是上下文数据的 SSOT |
| **Federal I.4** (Sanctity of Automation) | 禁止临时手动变通 | ✅ PASS | 所有操作通过脚本完成 |
| **Federal II.1** (Validation Loop) | 变更必须通过验证 | ✅ PASS | 脚本需通过 shellcheck 验证 |
| **Federal II.2** (Local Verification) | 提交前本地验证 | ⚠️ ATTENTION | 需要创建 context 系统的验证脚本 |
| **Federal III.1** (Module Cohesion) | 模块职责单一 | ✅ PASS | context 系统独立于其他模块 |
| **Scripts VI.1** (Error Handling) | 脚本必须 fail fast | ✅ PLANNED | 所有脚本使用 `set -euo pipefail` |
| **Scripts VI.3** (POSIX Compliance) | POSIX 兼容 | ✅ PLANNED | 脚本遵循 POSIX 标准 |

### Gate Result: ✅ PASS

所有关键条款通过或已计划满足。Federal II.2 需要在实现阶段创建验证脚本。

### Post-Design Gate Check

| Article | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| **Federal I.1** (Automation First) | 重复操作必须脚本化 | ✅ PASS | init/add/list/validate 脚本覆盖所有操作 |
| **Federal I.3** (SSOT) | 单一数据源 | ✅ PASS | `.context/` 是唯一上下文存储位置 |
| **Federal II.1** (Validation Loop) | 变更必须通过验证 | ✅ PASS | validate-context.sh 验证文件完整性 |
| **Federal III.1** (Module Cohesion) | 模块职责单一 | ✅ PASS | context 系统职责明确，与其他模块解耦 |
| **Scripts VI.1** (Error Handling) | 脚本必须 fail fast | ✅ DESIGNED | 所有脚本设计使用 `set -euo pipefail` |
| **Scripts VI.3** (POSIX Compliance) | POSIX 兼容 | ✅ DESIGNED | 脚本设计遵循 POSIX 标准 |

### Post-Design Gate Result: ✅ PASS

## Project Structure

### Documentation (this feature)

```text
specs/001-ai-context-system/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no APIs)
├── checklists/          # Validation checklists
│   └── requirements.md
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
.context/                      # 上下文存储目录 (新建，可扩展架构)
├── index.md                   # 全局索引文件 (支持 By Layer 和 By Domain 两种视图)
├── templates/                 # 上下文条目模板
│   └── entry-template.md      # 模板包含 layer 字段 (business|experience|tech)
│
│ # Phase 1 领域 (初期实现)
├── release/                   # 发布系统相关上下文
│   ├── _domain.md             # 领域描述和触发关键词
│   └── ctx-release-*.md       # 各条上下文条目 (包含 layer 字段)
├── ci/                        # CI/CD 相关上下文
│   ├── _domain.md
│   └── ctx-ci-*.md            # 各条上下文条目 (包含 layer 字段)
├── integration/               # 集成/兼容性相关上下文
│   ├── _domain.md
│   └── ctx-integration-*.md   # 各条上下文条目 (包含 layer 字段)
├── compatibility/             # 版本兼容相关上下文
│   ├── _domain.md
│   └── ctx-compatibility-*.md # 各条上下文条目 (包含 layer 字段)
│
│ # Phase 2+ 领域 (后续扩展，目录结构预留)
├── sources/                   # Sources 业务逻辑上下文 (Phase 2)
│   ├── _domain.md
│   └── ctx-sources-*.md       # 各条上下文条目 (包含 layer 字段)
├── architecture/              # 架构决策上下文 (Phase 2)
│   └── _domain.md
└── testing/                   # 测试策略上下文 (Phase 2)
    └── _domain.md

.agents-shared/skills/         # 现有技能目录
├── context-add.skill.md       # 新增: 手动添加上下文 (需要收集 layer 字段)
├── context-list.skill.md      # 新增: 查看/搜索上下文 (支持按 layer 筛选)
└── context-init.skill.md      # 新增: 初始化上下文 (AI 分析 layer 归类)

Scripts/context/               # 上下文管理脚本 (新建)
├── common.sh                  # 公共函数 (包括 validate_layer() 和 layer 计数逻辑)
├── init-context.sh            # 从 commit 历史初始化上下文 (生成包含 layer 字段的条目)
├── add-context.sh             # 添加单条上下文 (引导用户选择 layer)
├── list-context.sh            # 列出/搜索上下文 (支持 --layer 筛选, --rebuild 重建 By Layer 统计)
└── validate-context.sh        # 验证上下文文件完整性 (验证 layer 字段有效性)

AGENTS.md                      # 需修改: 添加上下文沉淀规则 (Read-Only Zone)
```

**Structure Decision**:
- 采用 Markdown 文件存储 + Bash 脚本管理的架构
- 上下文按**领域**分目录存储（目录结构），每条上下文是独立的 Markdown 文件
- **层级**（business/experience/tech）存储在每条上下文的 YAML front matter 中（正交于领域分类）
- index.md 提供两种视图：By Layer（按层级分组）和 By Domain（按领域分组）
- 脚本放在 `Scripts/context/` 下，skill 文件放在 `.agents-shared/skills/` 下
- common.sh 提供 `validate_layer()` 函数验证层级有效性

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

本特性复杂度适中，不存在需要特别证明的违规项。

## Phase 0 Outputs

- [research.md](./research.md) - 技术研究和决策记录

## Phase 1 Outputs

- [data-model.md](./data-model.md) - 上下文数据模型定义
- [quickstart.md](./quickstart.md) - 快速开始指南
- contracts/ - N/A (本特性无 API 契约)

## Implementation Notes

### 关键设计决策

1. **存储格式**: Markdown 而非 JSON/YAML
   - 理由: 人类可读、Git 友好、与现有文档体系一致

2. **索引策略**: 单独的 index.md 文件
   - 理由: 避免每次检索都扫描所有文件
   - 支持两种视图: By Layer (business/experience/tech) 和 By Domain (release/ci/...)

3. **双维度分类**: 领域 (domain) + 层级 (layer)
   - **领域分类**: 采用目录结构（简单直观，便于人工浏览）
   - **层级分类**: 采用 YAML front matter 字段（正交于领域，避免目录爆炸）
   - 理由: 两个维度相互独立，层级区分知识类型，领域区分业务范围

4. **触发机制**: 通过 AGENTS.md 规则而非代码
   - 理由: 无需修改 AI agent 代码，配置即可生效

### 需要人工批准的修改

- AGENTS.md 属于 Read-Only Zone，修改需人工确认
