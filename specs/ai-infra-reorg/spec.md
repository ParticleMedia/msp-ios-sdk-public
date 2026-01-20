# Feature Specification: AI 基础设施重组

**Feature Branch**: `ai-infra-reorg``
**Created**: 2026-01-20
**Status**: Draft
**Input**: User description: "修复 spec 编号冲突、MVVM-Repo 位置调整、添加分层配置、删除冗余 CLAUDE.md、补充 TDD/logging/error handling、明确 XCodeGen 限制"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 改用语义化 Spec 命名 (Priority: P1)

作为一个使用多种 AI 工具（Claude、Codex、Cursor）的开发者，我希望 spec 采用纯语义化命名（如 `user-auth`、`ai-infra-reorg`），去掉数字前缀，避免不同工具间的编号冲突问题。

**Why this priority**: 数字编号在多工具环境下容易冲突（如已有 001、002 但新工具又从 001 开始），语义化命名从根本上消除这个问题。

**Independent Test**: 可以通过在不同 AI 工具中分别运行 `/speckit.specify` 并验证生成的目录和分支名称是纯语义化格式来测试。

**Acceptance Scenarios**:

1. **Given** 用户描述一个功能 "user authentication"，**When** 任意 AI 工具运行 `create-new-feature.sh`，**Then** 创建 `specs/user-auth/` 目录和 `user-auth` 分支（无数字前缀）
2. **Given** specs 目录已有 `user-auth` 和 `payment-flow`，**When** 创建新 spec "dashboard analytics"，**Then** 创建 `specs/dashboard-analytics/`（基于语义，不依赖数字递增）
3. **Given** 用户在 Codex 中创建 `api-refactor` spec 后切换到 Claude，**When** Claude 创建 `ui-redesign` spec，**Then** 两者独立，无冲突风险

---

### User Story 2 - 架构模式分域配置 (Priority: P1)

作为一个开发者，我希望 MVVM-Repo 模式仅适用于 Swift 源码开发（Sources/），而 Scripts 目录使用 config-driven 开发模式，避免全局 AGENTS.md 包含领域特定内容。

**Why this priority**: MVVM-Repo 是 Swift 特有的模式，放在全局配置中会误导 Scripts 开发，造成架构混乱。

**Independent Test**: 可以通过检查 AGENTS.md 不再包含 MVVM-Repo 内容，且 `Sources/AGENTS-SOURCES.md` 包含该内容来验证。

**Acceptance Scenarios**:

1. **Given** 开发者在 Sources/ 下工作，**When** AI 工具加载上下文，**Then** 看到 MVVM-Repo 架构指导
2. **Given** 开发者在 Scripts/ 下工作，**When** AI 工具加载上下文，**Then** 看到 config-driven 开发模式指导，不看到 MVVM-Repo
3. **Given** AGENTS.md 被任意 AI 工具加载，**When** 查看内容，**Then** 不包含特定架构模式（MVVM-Repo 或 config-driven），只包含通用项目信息

---

### User Story 3 - 统一分层配置结构 (Priority: P1)

作为一个开发者，我希望所有 AI 工具（Claude、Codex、Cursor）都能加载领域特定配置（Sources/ 和 Scripts/ 规则），使不同工具在相同领域有一致的行为。

**Why this priority**: Claude 已有分层配置，Codex 和 Cursor 缺乏这个，导致工具间行为不一致。通过 @import 引用共享规则文件可实现统一。

**Independent Test**: 可以通过验证各工具主配置引用了 `Sources/AGENTS-SOURCES.md` 和 `Scripts/AGENTS-SCRIPTS.md`，且内容被正确加载来测试。

**Acceptance Scenarios**:

1. **Given** Codex 在 Sources/ 下工作，**When** 加载配置，**Then** 通过 `.codex/CODEX.md` 中的 @import 引用加载 `Sources/AGENTS-SOURCES.md` 中的 MVVM-Repo 规则
2. **Given** Cursor 在 Scripts/ 下工作，**When** 加载配置，**Then** 通过 `.cursor/CURSOR.md` 中的 @import 引用加载 `Scripts/AGENTS-SCRIPTS.md` 中的 config-driven 规则
3. **Given** 三个 AI 工具在 Sources/ 下工作，**When** 比较行为，**Then** 都遵循 MVVM-Repo 架构指导（因为都引用同一共享文件）

---

### User Story 4 - 消除 CLAUDE.md 歧义 (Priority: P2)

作为一个开发者，我希望删除根目录的 `/CLAUDE.md` 文件（自动生成的 recent changes），把内容移到 `AGENTS.md`，只保留 `/.claude/CLAUDE.md` 作为 Claude 的配置入口，消除两个同名文件的混淆。

**Why this priority**: 根目录的 `CLAUDE.md` 和 `.claude/CLAUDE.md` 容易混淆，且根目录版本只有 recent changes，功能重复。

**Independent Test**: 可以通过确认根目录不存在 `CLAUDE.md`，且 `AGENTS.md` 包含 Recent Changes 部分来验证。

**Acceptance Scenarios**:

1. **Given** 项目根目录，**When** 列出文件，**Then** 不存在 `/CLAUDE.md` 文件
2. **Given** `AGENTS.md` 文件，**When** 查看内容，**Then** 包含 "Recent Changes" 或 "Active Technologies" 部分
3. **Given** `.specify/scripts/bash/update-agent-context.sh` 脚本，**When** 运行，**Then** 更新 `AGENTS.md` 而非根目录 `CLAUDE.md`

---

### User Story 5 - 补充 Constitution 最佳实践 (Priority: P2)

作为一个 Swift 开发者，我希望 `Sources/constitution.md` 包含 TDD 要求（已有但需确认）、Swift 日志规范、和错误处理最佳实践，使代码质量有明确标准。

**Why this priority**: 当前 constitution 缺少日志和错误处理的具体指导，导致代码风格不一致。

**Independent Test**: 可以通过检查 `Sources/constitution.md` 包含 TDD、Logging、Error Handling 三个主题的具体规则来验证。

**Acceptance Scenarios**:

1. **Given** `Sources/constitution.md`，**When** 查找 TDD 相关内容，**Then** 存在 Red-Green-Refactor 流程要求
2. **Given** `Sources/constitution.md`，**When** 查找 Logging 相关内容，**Then** 存在 Swift 日志规范（os_log/Logger API 使用指导）
3. **Given** `Sources/constitution.md`，**When** 查找 Error Handling 相关内容，**Then** 存在错误处理最佳实践（Result 类型、throws、do-catch 使用指导）

---

### User Story 6 - 明确 XCodeGen 限制并修复分层 Constitution 检查 (Priority: P2)

作为一个开发者，我希望 XCodeGen 相关限制在 `Sources/constitution.md` 中明确说明（不直接修改 .xcodeproj），且 speckit 工具能检查所有层级的 constitution 而非只检查根目录。

**Why this priority**: XCodeGen 限制目前只在根 constitution，speckit 只检查根 constitution 会遗漏子目录规则。

**Independent Test**: 可以通过检查 `Sources/constitution.md` 包含 XCodeGen 规则，且运行 speckit constitutional review 时显示检查了所有 constitution 文件来验证。

**Acceptance Scenarios**:

1. **Given** `Sources/constitution.md` Article IV.6，**When** 查找内容，**Then** 存在精简的强制规则（引用 Federal I.2 + Rationale），不含详细步骤
2. **Given** `AGENTS.md`，**When** 查找 "Project Configuration Workflow"，**Then** 存在详细的 XCodeGen 操作流程、常见场景、故障排查
3. **Given** speckit 运行 constitutional review，**When** 执行检查，**Then** 输出显示检查了根 constitution 和所有子目录 constitution
4. **Given** 一个 plan 违反了 `Scripts/constitution.md` 的规则，**When** speckit 验证，**Then** 报告违规（不因为只检查根 constitution 而遗漏）

---

### Edge Cases

- 如果不同 AI 工具同时创建同名 spec 会怎样？→ 语义化命名大幅降低此风险（不同功能自然有不同名称）；若确实同名，先创建者成功，后者提示已存在
- 如果子目录 constitution 与根 constitution 冲突会怎样？→ 根据 Governance 规则，Federal Constitution 优先
- 如果删除根 `CLAUDE.md` 后某些工具依赖它会怎样？→ 确认 Claude Code CLI 只加载 `.claude/CLAUDE.md`
- 如果某工具不支持 @import 语法会怎样？→ 直接将共享规则文件内容内联到主配置中（作为 fallback）
- 如果迁移 spec 时远程分支已被其他人使用会怎样？→ 通知相关人员，协调分支重命名时机，或创建新分支并标记旧分支为 deprecated

## Requirements *(mandatory)*

### Functional Requirements

**Spec 语义化命名**:
- **FR-001**: `create-new-feature.sh` 必须从功能描述生成语义化短名称（2-4 词，如 `user-auth`、`ai-infra-reorg`），不再使用数字前缀
- **FR-002**: 创建前必须检查是否已存在同名 spec 目录或分支，若存在则提示用户更换名称
- **FR-002.1**: 必须迁移现有 spec：`001-unit-test-setup` → `unit-test-setup`、`002-ai-infra-refactor` → `ai-infra-refactor`、`003-ai-infra-reorg` → `ai-infra-reorg`
- **FR-002.2**: 迁移包括：重命名 specs 目录、更新 spec.md 内的 Feature Branch 字段、更新关联的 git 分支名称

**架构模式分域**:
- **FR-003**: `AGENTS.md` 必须移除 MVVM-Repo 相关内容
- **FR-004**: `Sources/AGENTS-SOURCES.md` 必须包含 MVVM-Repo 架构指导（含 View→ViewModel→Repository→DataSource 分层、测试策略等）
- **FR-005**: `Scripts/AGENTS-SCRIPTS.md` 必须包含 config-driven 开发模式指导（含配置文件驱动、POSIX 兼容等）

**分层配置统一**:
- **FR-006**: 必须创建共享规则文件 `Sources/AGENTS-SOURCES.md`（含 MVVM-Repo）和 `Scripts/AGENTS-SCRIPTS.md`（含 config-driven）
- **FR-007**: `.codex/CODEX.md` 和 `.cursor/CURSOR.md` 必须通过 @import 或等效语法引用上述共享规则文件
- **FR-008**: `.claude/CLAUDE.md` 也必须更新为引用共享规则文件（统一引用方式，避免内容重复）

**CLAUDE.md 清理**:
- **FR-009**: 必须删除根目录 `/CLAUDE.md` 文件
- **FR-010**: 必须将 Recent Changes/Active Technologies 内容移至 `AGENTS.md`
- **FR-011**: `update-agent-context.sh` 必须更新 `AGENTS.md` 而非 `/CLAUDE.md`

**Constitution 补充**:
- **FR-012**: `Sources/constitution.md` 必须包含 Swift 日志规范（推荐使用 os_log/Logger API）
- **FR-013**: `Sources/constitution.md` 必须包含错误处理最佳实践（Result、throws、do-catch 指导）
- **FR-014**: 确认 TDD 要求（Red-Green-Refactor）在 `Sources/constitution.md` 中存在且清晰

**XCodeGen 和 Speckit 修复**:
- **FR-015**: `Sources/constitution.md` Article IV.6 必须精简为：引用 Federal I.2 + Rationale（.xcodeproj 在 .gitignore）
- **FR-015.1**: `AGENTS.md` 必须添加 "Project Configuration Workflow" 章节，包含详细 XCodeGen 步骤、常见场景、故障排查
- **FR-016**: Speckit 的 constitutional review 必须检查所有 constitution 文件（根目录 + 所有子目录）
- **FR-017**: Constitutional review 输出必须列出所有被检查的 constitution 文件路径

### Key Entities

- **Constitution 文件**: 定义不可变规则的 markdown 文件，分联邦（根目录）和州（子目录）两级
- **Agent 配置文件**: 定义特定 AI 工具行为的 markdown 文件（CLAUDE.md、CODEX.md、CURSOR.md）
- **Spec 名称**: 语义化短名称（如 `user-auth`、`ai-infra-reorg`），用于 spec 目录和分支命名，无数字前缀
- **分层配置**: 子目录级别的 agent 配置，覆盖或补充根目录配置

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 在三个 AI 工具（Claude、Codex、Cursor）中创建 5 个 spec，全部使用语义化命名（无数字前缀），且无命名冲突
- **SC-002**: `AGENTS.md` 行数减少 30%（移除 MVVM-Repo 等领域特定内容）
- **SC-003**: 开发者在 Sources/ 和 Scripts/ 工作时，AI 工具提供的架构指导 100% 匹配对应领域
- **SC-004**: 根目录不存在 `CLAUDE.md` 文件
- **SC-005**: `Sources/constitution.md` 包含 TDD、Logging、Error Handling 三个主题的明确规则
- **SC-006**: Speckit constitutional review 检查并报告所有 constitution 文件（至少 4 个：根、Sources、Scripts、Tests）

## Clarifications

### Session 2026-01-20

- Q: Spec 命名策略采用哪种格式？ → A: 纯语义化名称（如 `user-auth`、`ai-infra-reorg`），去掉数字前缀
- Q: Codex/Cursor 如何实现分层配置？ → A: 在主配置中用 @import 引用共享规则文件（如 `Sources/AGENTS-SOURCES.md`）
- Q: 架构模式（MVVM-Repo、config-driven）放在哪里？ → A: 放在共享 Agents 文件（`Sources/AGENTS-SOURCES.md`、`Scripts/AGENTS-SCRIPTS.md`），不放在 constitution
- Q: 现有带数字前缀的 spec 如何处理？ → A: 全部迁移，重命名去掉数字前缀（如 `001-unit-test-setup` → `unit-test-setup`）
- Q: XCodeGen 相关内容放在 Constitution 还是 AGENTS.md？ → A: 分层策略 - Constitution (Sources IV.6) 精简版（引用 Federal I.2 + Rationale），AGENTS.md 提供详细工作流程

## Assumptions

- Claude Code CLI 加载配置的入口是 `.claude/CLAUDE.md`，根目录的 `/CLAUDE.md` 只是自动生成的辅助文件
- Codex 和 Cursor 支持通过 @import 或类似机制引用子目录配置
- 当前 speckit 的 constitutional review 功能可以被扩展以支持多文件检查
- 用户不会同时在多个终端并行创建 spec（如需支持，需额外实现文件锁）
- 分层 constitution 的设计是正确的，问题在于工具支持不完整而非架构设计
