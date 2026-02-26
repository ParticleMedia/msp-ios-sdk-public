# Feature Specification: Release System Refactor

**Feature Branch**: `002-release-system-refactor`
**Created**: 2026-02-03
**Status**: Implemented v1.0 — P3 cleanup ongoing
**v1.0 Completed**: 2026-02-05
**Input**: 发布系统优化重构

### Implementation Summary

| Metric | Value |
|--------|-------|
| Tasks Completed | 147/168 (87.5%) |
| User Stories | 6/6 (100%) |
| Pending (P3) | 12 (DRY refactor: zip, notifications, JSON utils, path init, logging audit) |
| Deferred | 9 (modularization: T102/T104/T109-T113, performance: T071-T072) |

**Key Deliverables**:
- ✅ Simple/Full release modes with `--full` flag
- ✅ Pods-only and SPM-only release commands
- ✅ Config-driven architecture with profiles (local-dev, quick-test, production)
- ✅ 4-phase logging system with timing
- ✅ Resume support with state tracking
- ✅ Cross-platform lock mechanism (flock/mkdir)
- ✅ Verification sandbox system
- ✅ TDD infrastructure with 90% core coverage target

**Deferred to Next Major Release**:
- Script modularization (T102, T104, T109-T113): modular.sh phase extraction, publish.sh entry point refactor
- Performance optimization (T071-T072): pod spec update strategy, redundant availability checks

## Overview

对 MSP iOS SDK 发布系统进行全面重构，解决代码重复、日志混乱、流程耦合、环境变量过多等问题，建立 config-driven 架构和 TDD 测试框架。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Simple Release (Priority: P1)

开发者执行日常发布，使用默认的 simple 模式快速完成 CocoaPods 和 SPM 发布。

**Why this priority**: 这是最常见的使用场景，必须简单、快速、可靠。

**Independent Test**: 运行 `msp-release.sh run <VERSION>` 完成一次完整发布。

**Acceptance Scenarios**:

1. **Given** 代码已准备好发布, **When** 执行 `msp-release.sh run 1.0.0`, **Then** 系统自动完成 XCFramework 构建、CocoaPods 发布、SPM 发布，无需手动干预
2. **Given** simple 模式（默认）, **When** 发布完成, **Then** 跳过 post-release verification，总耗时减少
3. **Given** 发布过程中断, **When** 执行 `msp-release.sh resume`, **Then** 从上次中断点继续（simple 模式），不重复已完成的步骤
4. **Given** 发布过程中断且需要完整验证, **When** 执行 `msp-release.sh resume --full`, **Then** 从上次中断点继续并在完成后执行完整 verification

---

### User Story 2 - Full Release with Verification (Priority: P1)

开发者执行正式发布，使用 full 模式进行完整验证。

**Why this priority**: 正式发布需要完整验证，确保发布质量。

**Independent Test**: 运行 `msp-release.sh run --full <VERSION>` 完成带验证的发布。

**Acceptance Scenarios**:

1. **Given** full 模式, **When** 发布完成, **Then** 自动执行 local verification（sandbox 环境）、remote CocoaPods verification、remote SPM verification、sample app build、device test
2. **Given** local verification, **When** 执行验证, **Then** 在隔离的 sandbox 目录中测试，不影响主 repo
3. **Given** 任一验证失败, **When** 查看日志, **Then** 能清晰看到失败原因和建议的修复步骤

---

### User Story 3 - CocoaPods Only Release (Priority: P2)

开发者只需要发布 CocoaPods，不需要 SPM。

**Why this priority**: 有时只需要更新 CocoaPods 版本。

**Independent Test**: 运行 `msp-release.sh pods <VERSION>` 只发布 CocoaPods。

**Acceptance Scenarios**:

1. **Given** 只发布 CocoaPods, **When** 执行 `msp-release.sh pods 1.0.0`, **Then** 系统切换到 pods-release 环境，构建并发布所有 pods
2. **Given** pods 发布完成, **When** 查看 CocoaPods trunk, **Then** 所有 pods 版本正确，依赖关系正确

---

### User Story 4 - SPM Only Release (Priority: P2)

开发者只需要发布 SPM，不需要 CocoaPods。

**Why this priority**: 有时只需要更新 SPM 版本。

**Independent Test**: 运行 `msp-release.sh spm <VERSION>` 只发布 SPM。

**Acceptance Scenarios**:

1. **Given** 只发布 SPM, **When** 执行 `msp-release.sh spm 1.0.0`, **Then** 系统切换到 spm-release 环境，构建并发布所有 SPM packages
2. **Given** SPM 发布完成, **When** 在新项目中添加 SPM 依赖, **Then** 能正确 resolve 新版本

---

### User Story 5 - Parameterized Release (Priority: P2)

开发者通过参数指定 release note 和 version，无需手动编辑。

**Why this priority**: 减少手动操作，支持自动化。

**Independent Test**: 运行 `msp-release.sh run --version 1.0.0 --release-notes "Bug fixes"` 完成发布。

**Acceptance Scenarios**:

1. **Given** 指定了 release notes, **When** 发布完成, **Then** GitHub Release 包含指定的 release notes
2. **Given** 指定了 version, **When** 发布完成, **Then** 所有 artifacts 使用指定的版本号

---

### User Story 6 - Debugging Release Issues (Priority: P3)

开发者遇到发布问题时，能快速定位和修复。

**Why this priority**: 提高问题排查效率。

**Independent Test**: 模拟发布失败，查看日志输出。

**Acceptance Scenarios**:

1. **Given** 发布失败, **When** 查看日志, **Then** 日志清晰显示 phase/step 编号、错误级别（ERROR/WARN/INFO）、具体错误信息
2. **Given** pod availability timeout, **When** 查看日志, **Then** 显示为 WARNING 而非 ERROR（因为可能只是 CDN 延迟）
3. **Given** 需要查看环境变量, **When** 运行 `msp-release.sh env`, **Then** 显示所有当前生效的环境变量及其含义

---

### Edge Cases

- 网络中断时：自动重试，超时后给出明确错误信息
- 并发发布时：锁机制防止冲突，macOS 和 Linux 都能正常工作
- CocoaPods CDN 延迟时：智能等待，共享等待状态，避免重复更新 specs repo
- 部分 adapter 发布失败：fail-fast 模式，停止其他并行任务，状态文件记录进度
- Slack 发送失败时：不阻塞发布流程，记录警告日志

## Requirements *(mandatory)*

### Functional Requirements

#### 架构重构

- **FR-001**: 系统 MUST 采用 config-driven 架构，所有配置通过 YAML 文件定义，脚本逻辑与配置分离
- **FR-002**: 系统 MUST 支持从配置文件读取 pod 发布顺序、依赖关系、分发方式（binary/source）
- **FR-003**: 系统 MUST 清理所有 legacy 代码和无用代码（含 FR-068 范围）

#### 日志系统

- **FR-004**: 日志系统 MUST 统一使用 phase/step 层级结构，数字对齐（如 `[Phase 1/4] [Step 01/12]`）
- **FR-005**: 日志系统 MUST 正确区分日志级别：ERROR（阻断性错误）、WARN（可继续但需注意）、INFO（正常信息）、DEBUG（调试信息）
- **FR-006**: Pod availability timeout MUST 记录为 WARN 而非 ERROR
- **FR-007**: 系统 MUST 清理所有 legacy 日志和 confused 日志
- **FR-066**: 所有脚本 MUST 迁移到新的 logging API（`log::info`, `log::warn`, `log::error`），移除对旧函数（`log_info`, `log_warn`, `log_error`）的依赖
- **FR-067**: 迁移完成后 SHOULD 删除 logger.sh 中的 Backward Compatibility Layer（降级：~4150 legacy 调用点，渐进式迁移）
- **FR-062**: 发布流程 MUST 划分为 4 个 Phase，每个 Phase 有明确的 Step：
  ```
  Phase 1/4: Preflight（预检）
    - Step 01: Git status check
    - Step 02: Branch validation
    - Step 03: Version validation
    - Step 04: Dependencies check
    - Step 05: Environment setup

  Phase 2/4: Build（构建）
    - Step 01: Clean build artifacts
    - Step 02: Build XCFrameworks (Core)
    - Step 03: Build XCFrameworks (Adapters)
    - Step 04: Create release archives
    - Step 05: Upload to GitHub Release

  Phase 3/4: Publish（发布）
    - Step 01: Switch to pods-release environment
    - Step 02: Publish MSPiOSCore
    - Step 03: Publish MSPSharedLibraries
    - Step 04-10: Publish Adapters (parallel where possible)
    - Step 11: Publish MSPCore
    - Step 12: Switch to spm-release environment
    - Step 13: Update Package.swift
    - Step 14: Push SPM changes

  Phase 4/4: Verify（验证）[仅 --full 模式]
    - Step 01: Local CocoaPods verification
    - Step 02: Local SPM verification
    - Step 03: Remote CocoaPods verification
    - Step 04: Remote SPM verification
    - Step 05: Sample app build
    - Step 06: Device test (optional)
  ```
- **FR-063**: 每条日志 MUST 显示当前位置，格式：`[Phase X/4] [Step YY/ZZ] [LEVEL] message`
- **FR-064**: Phase 开始和结束 MUST 有明显的分隔线和摘要信息
- **FR-065**: 发布完成后 MUST 输出总结，包含各 Phase 耗时和成功/失败状态

#### 环境隔离

- **FR-008**: 系统 MUST 在 CocoaPods 发布前自动切换到 pods-release 环境
- **FR-009**: 系统 MUST 在 SPM 发布前自动切换到 spm-release 环境
- **FR-010**: 双发布模式 MUST 共享同一个 release branch，但各自的构建环境独立
- **FR-011**: Local verification MUST 在隔离的 sandbox 目录中执行，不影响主 repo

#### 发布流程

- **FR-012**: Simple 模式（默认）MUST 包含：XCFramework 构建、基本 preflight、pod/spm 发布
- **FR-013**: Full 模式（`--full`）MUST 额外包含：完整 preflight、post-release verification
- **FR-014**: Simple 模式 MUST NOT 跳过 XCFramework 构建（避免使用旧的 artifacts）
- **FR-015**: 系统 MUST 支持全自动发布，无需手动干预
- **FR-016**: 系统 MUST 支持通过参数指定 version 和 release notes

#### Resume 模式

- **FR-040**: Resume 命令 MUST 支持 `--full` 参数，与 run 命令行为一致
- **FR-041**: `msp-release.sh resume` （默认）MUST 使用 simple 模式恢复
- **FR-042**: `msp-release.sh resume --full` MUST 恢复发布并在完成后执行完整 verification
- **FR-043**: Resume 模式 MUST 继承原发布的 version 和配置，无需重复指定

#### Profile 系统

- **FR-044**: 系统 MUST 保留 `--profile` 参数支持（local-dev、production、ci、test、resume）
- **FR-045**: Profile 与 `--full` 参数 MUST 可以组合使用（如 `--profile=production --full`）
- **FR-046**: `--profile=production` MUST 等同于 `--full` 的效果（完整 verification）
- **FR-047**: Profile 配置 MUST 从 `Scripts/config/release.yaml` 读取
- **FR-048**: 环境变量 MUST 能覆盖 profile 配置中的设置

#### Commit 规范

- **FR-017**: 系统 MUST 采用 per-pod commit 策略
- **FR-018**: Commit message MUST 遵循格式：`release(<scope>): <module>@<version>`

#### 环境变量

- **FR-019**: 系统 MUST 审计并精简环境变量，移除无用和重复的变量
- **FR-020**: 系统 MUST 提供命令查看所有生效的环境变量及其含义
- **FR-021**: Resume 模式 MUST NOT 依赖 `MSP_ALLOW_EXISTING_TAG` 来判断是否重新打 tag

#### 代码清理（Tech Debt）

- **FR-068**: ~~重构过程中 SHOULD 删除不再需要的 legacy 代码、废弃函数、死代码~~ → 合并至 FR-003
- **FR-069**: 重构过程中 SHOULD 删除重复的配置文件和脚本（如旧的 `release.yaml.template`）
- **FR-070**: 向后兼容层（backward compatibility wrappers）在确认无外部依赖后 SHOULD 删除
- **FR-071**: 代码清理 SHOULD 与功能开发同步进行（边写边删），而非集中在最后

**原则**: 保持代码库整洁。新代码不应依赖 legacy 实现，发现可删除的代码应及时清理。

#### 脚本模块化（Script Modularization）

- **FR-072**: 超过 2000 行的脚本文件 SHOULD 按功能拆分为多个模块
- **FR-073**: 拆分后的模块 MUST 有明确的单一职责（Single Responsibility）
- **FR-074**: 模块间 MUST 通过显式 source 导入，避免隐式依赖
- **FR-075**: 每个模块 SHOULD 有独立的入口函数和清晰的 API 边界
- **FR-076**: 拆分 SHOULD 渐进式进行，每次触碰文件时提取一个模块，而非一次性大重构

**目标文件**:
- `Scripts/release/publish/pods/publish.sh` (6700+ 行) → 部分完成：已提取 github_release.sh、pod_trunk.sh、tag_management.sh；lint 和入口重构延期（T102, T104）
- `Scripts/msp-release.sh` (2300+ 行) → ✅ 已完成：234 行入口 + 10 个 CLI 模块（85% 缩减）
- `Scripts/release/orchestrator/modular.sh` (2200+ 行) → 延期：Phase 拆分待下一迭代（T109-T113）

**原则**: 每个模块做一件事，文件大小控制在 500-800 行为宜。

#### 并发与性能

- **FR-022**: 系统 MUST 修复 macOS 上的并发锁机制（当前 flock 不可用时跳过锁）
- **FR-023**: 系统 SHOULD 优化 pod spec 更新策略，集中更新、共享等待状态（降级：延期至下一迭代）
- **FR-024**: 系统 SHOULD 去除冗余的 availability check（已确认可用的 pod 不再重复检查）（降级：延期至下一迭代）

#### Verification

- **FR-025**: Local verification MUST 验证新版本能在本地项目中正确集成
- **FR-026**: Remote CocoaPods verification MUST 验证 pod 在 trunk 上可用
- **FR-027**: Remote SPM verification MUST 验证 SPM package 可被 resolve
- **FR-028**: Sample App build verification MUST 验证示例项目能正确构建
- **FR-029**: Device test verification MUST 验证在真机上能正常运行

#### CI 兼容性

- **FR-030**: 重构 MUST 保证现有 `ci-pull-request.yml` workflow 全部通过
- **FR-031**: 重构 MUST NOT 修改现有 CI workflow 的 job 结构
- **FR-032**: CI workflow MUST 新增 bash 测试运行步骤，验证 `Scripts/tests/` 全部通过
- **FR-057**: 每个 PR 合并前 MUST 通过以下 CI 检查：
  - 现有检查（lint、build、podspec validation 等）
  - 新增：bash 单元测试（`Scripts/tests/unit/run_all.sh`）
  - 新增：bash 集成测试（`Scripts/tests/release_state/run_all.sh`）
- **FR-058**: CI 发布流程暂不实现（保持本地发布），未来 Jenkins 就绪后再启用

#### 通知系统

- **FR-033**: 系统 MUST 修复 Slack 消息发送失败的问题
- **FR-034**: Slack 发送失败 MUST NOT 阻塞发布流程

#### 测试框架（TDD）

- **FR-035**: 系统 MUST 扩展现有 `Scripts/tests/release_state/` 框架，保留其 mock 系统、assertion helpers 和 sandbox 隔离能力
- **FR-036**: 系统 MUST 新增 `Scripts/tests/unit/` 目录用于函数级单元测试，与现有集成测试分层
- **FR-037**: 测试 MUST 覆盖关键发布逻辑（state management、parallel release、notification、config loading、logging）
- **FR-049**: 单元测试 MUST 可独立运行，不依赖外部服务（git、pod、gh 等通过 mock 隔离）
- **FR-050**: 测试框架 MUST 支持 TDD 开发模式：先写测试、再写实现、测试驱动重构
- **FR-051**: 每个新增或修改的 utility function MUST 有对应的单元测试
- **FR-052**: 测试运行器 MUST 提供清晰的 pass/fail 输出和失败原因
- **FR-053**: TDD 优先覆盖以下核心模块（按优先级）：
  1. `state.sh` - 状态管理（状态读写、状态转换、resume 逻辑）
  2. `config.sh` / `config_loader.sh` - 配置加载（YAML 解析、profile 切换、环境变量覆盖）
  3. `logger.sh` - 日志系统（phase/step 格式化、日志级别过滤）
- **FR-054**: 核心模块的测试覆盖率 MUST 达到 90%，其他模块达到 60% 即可满足整体 70% 目标
- **FR-055**: TDD 工作流 MUST 遵循以下规则：
  - 新功能/新函数：严格 TDD（先写失败测试 → 实现 → 测试通过 → 重构）
  - 重构现有代码：先补充测试覆盖 → 确保测试通过 → 再进行重构 → 验证测试仍通过
- **FR-056**: 每个 PR MUST 包含对应的测试更新，CI MUST 验证测试通过

#### 注释规范

- **FR-038**: 注释 MUST 统一使用英文，聚焦于解释"做了什么"和"解决了什么问题"
- **FR-039**: 系统 MUST 清理所有 legacy 注释和开发时的临时注释
- **FR-077**: 函数头注释 MUST 使用以下格式：
  ```bash
  # @description Brief description of what the function does
  # @param $1 parameter_name - description
  # @param $2 parameter_name - description
  # @return description of return value or exit code
  # @example
  #   function_name "arg1" "arg2"
  ```
- **FR-078**: 内联注释 MUST 解释 WHY（为什么这样做），而非 WHAT（做了什么）
- **FR-079**: 复杂业务逻辑 MAY 使用块注释，格式：
  ```bash
  # ============================================================
  # Section: Brief title
  # ------------------------------------------------------------
  # Detailed explanation of complex logic or business rules.
  # ============================================================
  ```
- **FR-080**: 禁止以下类型的注释：
  - TODO/FIXME 未完成标记（除非有对应 issue）
  - 注释掉的代码（直接删除）
  - 过时的说明（如 "source distribution"）
  - 开发调试用的临时注释

#### 文档更新

- **FR-059**: 重构完成后 MUST 更新以下 README 文件：
  - `Scripts/README.md` - 新命令、profile 系统、环境变量、TDD 测试说明
  - `README.md`（根目录）- 发布相关说明（如有）
  - `Tests/README.md` - 新增 bash 测试框架说明
- **FR-060**: 文档 MUST 与代码实现保持同步，包含最新的命令用法和配置选项
- **FR-061**: 清理文档中的过时内容（如不存在的 adapter、过时的环境变量说明）

### Key Entities

- **ReleaseConfig**: 发布配置（pods、spm packages、依赖关系、分发方式）
- **ReleaseState**: 发布状态（已完成步骤、失败步骤、pod 可用性状态）
- **LogEntry**: 日志条目（phase、step、level、message、timestamp）
- **Environment**: 环境定义（pods-release、spm-release、sandbox）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Simple 模式跳过整个 Phase 4 (Verify)，显著减少发布耗时（测量方式：对比 simple vs full 模式的 Phase 4 耗时差，production profile 的 CDN wait 可达 120s+）
- **SC-002**: 日志输出 100% 遵循 phase/step 格式，无未对齐的数字
- **SC-003**: 环境变量数量从 30+ 减少到 15 个以内（必要的）
- **SC-004**: 所有发布脚本有对应的 unit test，覆盖率达到 70%（测量方式：核心模块公开函数的测试用例覆盖比例，核心模块 90%、其他 60%）
- **SC-005**: Resume 功能 100% 可靠，能从任意中断点恢复
- **SC-006**: Verification 在 sandbox 中执行，主 repo 0 改动
- **SC-007**: Full 模式的 verification 通过率达到 95%（之前是 0%，完全无法运行）
- **SC-008**: 并发锁在 macOS 和 Linux 上都能正常工作
- **SC-009**: Slack 通知成功率达到 99%
- **SC-010**: 关键入口文件大幅瘦身：msp-release.sh 1571→234 行（-85%），旧 config 文件已删除；整体通过 DRY 共享模块减少 ~1500 行重复代码

## Assumptions

1. 当前的 pod 发布顺序（MSPiOSCore → MSPSharedLibraries → Adapters → MSPCore）保持不变
2. CocoaPods 和 SPM 发布共享同一个 release branch 和 version
3. XCFramework 构建时间在可接受范围内（不超过 30 分钟）
4. Sandbox 验证使用临时目录，验证完成后自动清理
5. 现有的 GitHub CI workflow 结构保持不变，只更新调用的脚本

## Out of Scope

1. 修改 pod 发布顺序或依赖关系
2. 新增 pod 或 SPM package
3. 修改 GitHub Actions workflow 的 job 结构
4. 支持其他包管理器（如 Carthage）
5. 自动化版本号递增（仍需手动指定）

## Dependencies

- Scripts/lib/cocoapods.sh - CocoaPods 工具函数
- Scripts/release/ - 发布脚本目录
- Scripts/config/ - 配置文件目录
- .github/workflows/release.yml - GitHub CI release workflow
- .github/workflows/ci-pull-request.yml - GitHub CI PR workflow

## Clarifications

### Session 2026-02-03

- Q: Profile 设计中 ci-test 是否需要？ → A: 不需要，CI 和 Local 暂时没有区别，都用 production profile
- Q: CI 和 Local 发布有什么区别？ → A: 暂时没有区别（日志格式、Slack channel 都一样），等 Jenkins 就绪后才限制 Local 权限
- Q: mode (simple/full) 在哪里控制？ → A: 由 `--full` 参数控制，不在 profile 中定义
- Q: 模块分发方式是什么？ → A: 所有模块都是 binary 发布（HTTP zip + vendored_frameworks），没有 source 发布
- Q: 实际发布的模块列表？ → A: 共 11 个模块：MSPiOSCore, MSPSharedLibraries, MSPGoogleAdsTypes, MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, MSPNovaAdapter, MSPAmazonAdapter, MSPMolocoAdapter, MSPLiftoffAdapter, MSPCore
- Q: 配置文件中的过时信息？ → A: release.yaml.template 中的 "source distribution" 注释和不存在的 adapter（InmobiAdapter, MintegralAdapter 等）需要清理
- Q: 环境变量精简策略？ → A: 从 30+ 减少到 15 个必要变量。详见 plan.md "Environment Variable Audit" 部分：移除重复变量（MSP_DRY_RUN 等）、迁移配置变量到 YAML（validation.* 等）、清理 legacy 验证标志（MSP_SKIP_* 系列），保留 15 个必要变量用于核心控制、会话管理、安全覆盖和通知
- Q: TDD 测试框架设计？ → A: 扩展现有 `Scripts/tests/release_state/` 框架（保留 mock、helpers、sandbox），新增 `Scripts/tests/unit/` 用于函数级单元测试，形成集成测试 + 单元测试两层结构
- Q: TDD 测试覆盖优先级？ → A: 优先覆盖核心模块：state.sh（状态管理）、config.sh/config_loader.sh（配置加载）、logger.sh（日志），核心模块 90% 覆盖率，其他模块 60%
- Q: TDD 开发工作流？ → A: 新功能严格 TDD（先写测试再实现），重构现有代码先补测试再修改，每个 PR 必须包含测试更新
- Q: CI 兼容性验证范围？ → A: 现有 CI 通过 + 新增 bash 测试运行步骤（单元测试 + 集成测试），不新增 CI 发布流程（保持本地发布）
- Q: 文档更新范围？ → A: 更新 `Scripts/README.md`（主文档）、`README.md`（根目录）、`Tests/README.md`（测试文档），清理过时内容
- Q: 日志 Phase/Step 层级定义？ → A: 4 Phase 结构：Preflight（预检）→ Build（构建 XCF）→ Publish（发布 Pods/SPM）→ Verify（验证），每个 Phase 有明确的 Step 列表
- Q: 注释规范详细要求？ → A: 英文注释，函数头用 `# @description`, `# @param`, `# @return` 格式，内联注释解释 WHY，禁止 TODO/注释代码/过时说明
