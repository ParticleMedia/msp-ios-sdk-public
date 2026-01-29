# Feature Specification: AI 上下文系统

**Feature Branch**: `001-ai-context-system`
**Created**: 2026-01-29
**Status**: Draft
**Input**: User description: "建立 AI 上下文系统，沉淀发布系统经验，让 AI 自动提示沉淀上下文，创建 context skill 和 command"

## 背景与动机

### 问题陈述

当前开发过程中存在以下痛点：
1. **边际成本恒定**：每次处理发布相关问题时，AI 需要从零开始理解上下文，导致相同类型的问题每次都需要 45 分钟左右
2. **经验流失**：修复发布问题后的宝贵经验（如编译失败、启动 crash 的根因和解决方案）停留在 commit 历史中，无法自动复用
3. **上下文腐蚀**：随着会话变长，关键信息被淹没在大量对话中，AI 决策质量下降
4. **手动提供上下文**：开发者每次都需要手动告诉 AI 相关背景知识

### 预期价值

基于参考文章的"复利效应"概念：
- 第 2 次处理同类问题：从 45 分钟 → 15 分钟（节省 30 分钟）
- 第 10 次处理同类问题：从 45 分钟 → 3 分钟（累计节省 315 分钟）

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 初始化发布系统上下文 (Priority: P1)

作为 SDK 维护者，我希望系统能从现有 commit 历史中提取发布系统相关的经验教训，这样新加入的 AI 或团队成员能立即获得这些知识。

**Why this priority**: 这是整个系统的数据基础，没有初始上下文，后续功能无法发挥作用

**Independent Test**: 可以通过执行上下文初始化命令，验证是否在指定目录下生成了结构化的上下文文件，且内容覆盖了主要的发布问题类型

**Acceptance Scenarios**:

1. **Given** commit 历史中包含大量 `fix(release)` 和 `fix(ci)` 类型的提交, **When** 用户运行初始化命令, **Then** 系统提取并分类这些经验到结构化的上下文文件中
2. **Given** 提取出的原始经验数据, **When** 系统处理完成, **Then** 每条经验都包含：问题描述、根因分析、解决方案、适用场景
3. **Given** 初始化完成, **When** 用户查看上下文目录, **Then** 可以看到按领域分类的上下文文件（如 release/、ci/、integration/）

---

### User Story 2 - AI 自动提示沉淀上下文 (Priority: P1)

作为开发者，当 AI 帮我解决了一个棘手问题后，我希望 AI 能主动提示"这个经验值得沉淀"，这样我可以一键确认保存。

**Why this priority**: 这是实现"经验复利"的核心机制，确保新知识能持续积累而非流失

**Independent Test**: 可以通过模拟一个问题解决场景，验证 AI 是否在适当时机给出沉淀提示，且提示内容符合预期格式

**Acceptance Scenarios**:

1. **Given** AI 刚帮助解决了一个发布相关问题, **When** 问题涉及调试、修复或新发现, **Then** AI 提示用户："这个经验可能值得沉淀，建议保存为上下文"
2. **Given** AI 给出沉淀提示, **When** 用户确认沉淀, **Then** 系统自动将经验格式化并追加到对应领域的上下文文件中
3. **Given** AI 给出沉淀提示, **When** 用户选择忽略, **Then** 系统不做任何操作，不再重复提示同一问题

---

### User Story 3 - 手动记录上下文 (Priority: P2)

作为开发者，我希望能随时通过命令手动记录一条上下文，这样即使 AI 没有自动提示，我也能主动沉淀重要经验。

**Why this priority**: 提供手动兜底能力，确保不遗漏 AI 未自动识别的重要经验

**Independent Test**: 可以通过运行记录命令并提供必要参数，验证上下文是否正确写入对应文件

**Acceptance Scenarios**:

1. **Given** 用户发现一个值得记录的经验, **When** 用户运行 `/context.add` 命令并提供描述, **Then** 系统引导用户填写问题、根因、方案、标签
2. **Given** 用户完成经验输入, **When** 系统保存上下文, **Then** 新上下文追加到对应领域文件，并更新索引

---

### User Story 4 - 自动加载相关上下文 (Priority: P2)

作为开发者，当我开始处理发布相关任务时，我希望 AI 能自动加载相关的上下文，而不需要我手动指定。

**Why this priority**: 减少手动操作，让上下文系统真正实现"无感使用"

**Independent Test**: 可以通过发起一个发布相关的对话，验证 AI 是否自动引用了相关上下文知识

**Acceptance Scenarios**:

1. **Given** 上下文库中有发布相关经验, **When** 用户询问 AI 关于发布问题, **Then** AI 自动检索并在回答中引用相关上下文
2. **Given** 用户的问题涉及多个领域, **When** AI 检索上下文, **Then** 按相关性排序返回，优先显示高度相关的经验

---

### User Story 5 - 查看和管理上下文 (Priority: P3)

作为开发者，我希望能查看、搜索和管理已沉淀的上下文，以便维护知识库的质量。

**Why this priority**: 提供可视化管理能力，确保知识库不会变成"只写不读"的垃圾堆

**Independent Test**: 可以通过运行查看命令，验证是否能列出所有上下文并支持筛选

**Acceptance Scenarios**:

1. **Given** 上下文库中有多条记录, **When** 用户运行 `/context.list` 命令, **Then** 系统显示上下文列表，包含 ID、标题、领域、创建时间
2. **Given** 上下文列表, **When** 用户使用标签或关键词筛选, **Then** 系统只显示匹配的上下文
3. **Given** 某条上下文已过时, **When** 用户运行删除命令, **Then** 该上下文被标记为归档（非物理删除）

---

### Edge Cases

- 当 commit 历史中没有发布相关的提交时，初始化命令应提示"未找到相关经验"并正常退出
- 当上下文文件损坏或格式错误时，系统应提供修复建议而非崩溃
- 当两条上下文内容高度相似时，系统应在保存前提示可能重复
- 当上下文库过大（超过 500 条）时，检索性能不应明显下降

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统 MUST 提供初始化命令从 git commit 历史提取发布相关经验
- **FR-002**: 系统 MUST 将上下文按领域分类存储，支持可扩展的领域体系：
  - **初期领域（Phase 1）**: release、ci、integration、compatibility
  - **扩展领域（Phase 2+）**: sources（业务逻辑）、architecture（架构决策）、testing（测试策略）等
- **FR-002a**: 系统 MUST 支持动态添加新领域，无需修改核心代码，只需创建领域配置文件
- **FR-003**: 每条上下文 MUST 包含：问题描述、根因分析、解决方案、标签、创建时间、来源（commit hash 或手动）、层级（business/experience/tech）
- **FR-004**: AGENTS.md MUST 包含指导 AI 识别"可沉淀经验"的规则
- **FR-005**: AI MUST 在满足特定条件时主动提示用户沉淀上下文
- **FR-006**: 系统 MUST 提供 `/context.add` skill 供用户手动添加上下文
- **FR-007**: 系统 MUST 提供 `/context.list` skill 供用户查看和搜索上下文
- **FR-008**: 系统 MUST 提供上下文自动加载机制，基于当前任务关键词匹配相关上下文
- **FR-009**: 上下文文件 MUST 采用 Markdown 格式，便于人工阅读和版本控制
- **FR-010**: 系统 MUST 支持上下文的版本历史追踪（通过 git）

### Key Entities

- **Context Entry（上下文条目）**: 单条经验记录，包含问题、根因、方案、标签、元数据
- **Context Layer（上下文层级）**: 三层分类体系（正交于领域分类）
  - **business**: 业务知识（产品需求、业务规则、用户场景）
  - **experience**: 经验教训（调试过程、踩坑记录、解决方案）
  - **tech**: 技术知识（API 用法、架构设计、设计模式）
- **Context Domain（上下文领域）**: 经验的领域分类，采用可扩展设计
  - **初期领域**: release、ci、integration、compatibility
  - **计划领域**: sources（业务逻辑：MVVM、Repository、网络层等）、architecture、testing
- **Context Index（上下文索引）**: 所有上下文的汇总索引，支持快速检索
- **Context Trigger Rule（触发规则）**: 定义何时 AI 应提示沉淀或自动加载上下文的规则

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 第 2 次处理同类发布问题时，AI 响应时间减少 50% 以上（从完整分析到快速引用已有解决方案）
- **SC-002**: 初始化命令能从 100+ 条 commit 中提取至少 20 条结构化的发布经验
- **SC-003**: 用户确认沉淀操作的步骤不超过 3 次交互（提示 → 确认 → 完成）
- **SC-004**: 上下文检索在 500 条记录规模下，响应时间不超过 2 秒
- **SC-005**: 90% 的发布相关问题在 AI 回答时能引用至少 1 条相关上下文

## Assumptions

1. **Git 历史可用**: 假设 commit 历史完整且 commit message 遵循 Conventional Commits 格式，可通过正则匹配提取发布相关提交
2. **上下文目录结构**: 假设上下文文件存储在 `.context/` 目录下，与 `.agents-shared/` 同级
3. **AI 能力边界**: 假设当前 AI 具备 Glob、Grep、Read 等文件操作能力，可以读取和匹配上下文文件
4. **用户习惯**: 假设用户愿意在 AI 提示时花费 10-30 秒确认沉淀操作
5. **初始范围与扩展计划**:
   - **Phase 1**: 发布系统相关（release、ci、integration、compatibility）
   - **Phase 2+**: Sources 业务逻辑、架构决策、测试策略等
   - 系统架构设计为可扩展，添加新领域只需创建 `_domain.md` 配置文件

## Clarifications

### Session 2026-01-29

- Q: 系统是否只支持发布相关上下文？ → A: 否，系统设计为可扩展，支持 Sources 业务逻辑等多领域，初期只填充发布系统相关内容
- Q: 上下文分类是否需要区分 business/experience/tech 层级？ → A: 是，架构需支持三层分类（business/experience/tech），与领域分类正交，初期可留空后续填充

## Dependencies

- 依赖现有的 `.agents-shared/skills/` 目录结构来添加新 skill
- 依赖 AGENTS.md 的修改能力（需要人工批准，属于 Read-Only Zone）
- 依赖 speckit 工作流集成（新 skill 需注册到 speckit 命令系统）
