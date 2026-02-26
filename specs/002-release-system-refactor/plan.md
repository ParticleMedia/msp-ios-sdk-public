# Implementation Plan: Release System Refactor

**Branch**: `002-release-system-refactor` | **Date**: 2026-02-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-release-system-refactor/spec.md`

## Summary

Comprehensive refactoring of the MSP iOS SDK release system to establish a config-driven architecture with proper TDD testing framework. The refactor addresses code duplication, logging inconsistencies, flow coupling, and environment variable proliferation while maintaining backward compatibility with existing CI workflows.

**Primary Goals**:
1. Config-driven architecture (YAML configuration, script logic separation)
2. Unified logging system (phase/step hierarchy, proper log levels)
3. Environment isolation (pods-release, spm-release, sandbox)
4. Simple/Full release modes with resume support
5. TDD-based bash script testing framework

## Technical Context

**Language/Version**: Bash (POSIX-compliant), YAML configuration
**Primary Dependencies**: jq, yq, git, gh CLI, pod CLI, swift, xcodebuild, curl
**Storage**: JSON state files (`.msp-release-state.json`), YAML config files
**Testing**: Custom bash test framework (Scripts/tests/release_state/)
**Target Platform**: macOS (local development), Linux (GitHub Actions CI)
**Project Type**: CLI automation tooling
**Performance Goals**: Simple mode 30% faster than current, Full mode maintains quality
**Constraints**: macOS flock compatibility, CocoaPods CDN latency handling
**Scale/Scope**: 11 pods/packages, 4 verification tiers, 11 CLI subcommands

## Constitution Check

*GATE: Must pass before implementation. All items verified against Federal Constitution.*

| Article | Requirement | Status |
|---------|-------------|--------|
| I.1 (Automation First) | Scripts automate all release operations | ✅ Pass |
| I.2 (Deterministic Builds) | Config files drive behavior, no hardcoded values | ✅ Pass |
| I.3 (SSOT) | release.yaml is single source of truth for release config | ✅ Pass |
| I.4 (Sanctity of Process) | No manual workarounds, fix root causes | ✅ Pass |
| II.1 (Validation Loop) | Automated validation gates for all changes | ✅ Pass |
| III.1 (Module Cohesion) | Utils separated by responsibility | ✅ Pass |
| VI.1 (Scripts Constitution) | `set -euo pipefail` required | ✅ Pass |
| VI.2 (POSIX Compliance) | POSIX-compliant shell scripts | ✅ Pass |

## Project Structure

### Documentation (this feature)

```text
specs/002-release-system-refactor/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Architecture analysis (below)
├── data-model.md        # State and config schemas
├── quickstart.md        # Developer guide for new system
├── contracts/           # Interface contracts
│   ├── cli-interface.md
│   ├── config-schema.md
│   └── state-schema.md
└── tasks.md             # Implementation tasks (/speckit.tasks)
```

### Source Code (repository root)

```text
Scripts/
├── msp-release.sh                      # CLI entry point (234 lines, thin orchestration layer)
├── config/
│   ├── release.yaml                    # Release configuration (profiles, modules)
│   ├── cocoapods-config.yaml           # CocoaPods URLs, timeouts, retry settings
│   ├── build-config.yaml              # iOS target, Swift version, architectures
│   └── test-config.yaml               # Simulator device/OS settings
├── lib/                                # Shared libraries (33 modules)
│   ├── cocoapods.sh                    # CocoaPods utilities (1124 lines)
│   ├── config_loader.sh                # Config loading, profile switching
│   ├── config_loader_ext.sh            # Extended config for new YAML files
│   ├── lock.sh                         # Cross-platform lock (flock + mkdir fallback)
│   ├── logging.sh                      # Colors, UI utilities
│   ├── checksum.sh                     # Cross-platform SHA256
│   ├── spm.sh                          # SPM operations
│   ├── xcodegen.sh                     # XcodeGen wrapper
│   └── shared/                         # DRY shared modules
│       ├── cdn_verify.sh               # CDN verification (unified)
│       ├── github_release.sh           # GitHub Release operations (unified)
│       ├── input_validation.sh         # Version/branch validation
│       ├── step_lifecycle.sh           # Step state tracking
│       ├── time_utils.sh              # Duration calculation
│       ├── xcframework_build.sh        # XCF build operations
│       └── xcframework_validate.sh     # XCF validation
└── release/
    ├── cli/                            # CLI modules (10 modules, extracted from msp-release.sh)
    │   ├── dispatch.sh                 # do_* handlers and dispatch (500 lines)
    │   ├── commands.sh                 # fix-public-tag, verify, rollback (492 lines)
    │   ├── resume.sh                   # Resume sync and display (432 lines)
    │   ├── run_helpers.sh              # Shared run/resume session (267 lines)
    │   ├── config_helper.sh            # Config loading helpers (248 lines)
    │   ├── flags.sh                    # Flag parsing (238 lines)
    │   ├── wizard.sh                   # Interactive wizard (236 lines)
    │   ├── help.sh                     # Help text (200 lines)
    │   └── env.sh                      # Environment display (175 lines)
    ├── utils/                          # Release-specific utilities
    │   ├── config.sh                   # Config management
    │   ├── state.sh                    # State machine (17 states)
    │   ├── notify.sh                   # Notifications (soft-fail)
    │   ├── logger.sh                   # Structured logging (4-phase)
    │   ├── retry.sh                    # Retry with backoff
    │   └── safety.sh                   # Safety controls
    ├── orchestrator/
    │   └── modular.sh                  # Main orchestrator (2200+ lines, deferred split)
    ├── preflight/
    │   └── preflight.sh                # Pre-release validation
    ├── publish/
    │   ├── pods/
    │   │   ├── publish.sh              # CocoaPods publisher
    │   │   └── lib/                    # Extracted modules
    │   │       ├── github_release.sh   # GitHub release (delegates to shared)
    │   │       ├── pod_trunk.sh        # Trunk push, availability check
    │   │       ├── pod_publish.sh      # Publish with auto-retry
    │   │       ├── tag_management.sh   # Tag creation/push
    │   │       └── release_orchestration.sh  # Release orchestration
    │   └── spm/
    │       ├── publish.sh              # SPM publisher
    │       └── lib/                    # SPM-specific modules
    └── verify/                         # Verification system
        ├── verify.sh                   # Dispatcher (Phase 4)
        ├── sandbox.sh                  # Sandbox isolation
        ├── verify_local/               # Local verification
        ├── verify_local_device/        # Device testing
        └── verify_remote/              # Remote verification

Scripts/tests/
├── release_state/                      # Integration tests (12 cases + mocks)
│   ├── run_all.sh
│   ├── helpers.sh
│   ├── mock/                           # Mock external tools
│   └── cases/                          # Integration test cases
└── unit/                               # Unit tests (41 cases)
    ├── run_all.sh
    ├── helpers.sh                      # assert_*, info(), color system
    ├── mock_loader.sh                  # Mock utilities
    └── cases/                          # Unit test cases
```

**Structure Decision**: Refactor existing Scripts/ structure. No new top-level directories needed. Enhance existing test infrastructure in Scripts/tests/.

## Research Summary

### Current Architecture Analysis

The existing release system consists of:
- **2,100+ line CLI entry point** (`msp-release.sh`) - monolithic, needs modularization
- **12 utility scripts** in `release/utils/` - well-organized but some overlap
- **4-tier verification system** - exists but broken, needs rewrite
- **State machine** - 17 tracked states, functional but complex
- **Profile system** - exists in `Scripts/config/release.yaml`, needs integration

### Key Technical Findings

1. **Config System**
   - Single consolidated config: `Scripts/config/release.yaml` (profiles, modules, tier overrides, branch policy)
   - Old files (`release.yaml.template`, `release_config.yaml`) deleted after migration
   - Profile system maps old env vars to new config keys

2. **Test Infrastructure**
   - Existing test framework in `Scripts/tests/release_state/` with:
     - Mock system for external tools (curl, gh, git, pod, swift, xcodebuild)
     - Assertion helpers (assert_equals, assert_contains, etc.)
     - Sandbox isolation for each test
     - 12 existing test cases covering state management and Slack
   - Can extend this framework for new tests

3. **Logging Issues**
   - Multiple logging systems: `lib/logging.sh`, `release/utils/logger.sh`
   - Inconsistent phase/step numbering
   - Pod availability timeout logged as ERROR instead of WARN
   - Need to unify into single hierarchical system

4. **Environment Variables**
   - Currently 30+ variables documented in `Scripts/config/release.yaml`
   - Many already mapped to config keys
   - Goal: Reduce to 15 essential variables

5. **Concurrency Issues**
   - `flock` not available on macOS by default
   - Current code skips locking when flock unavailable
   - Need platform-agnostic locking mechanism

6. **Verification System**
   - Current implementation broken (cannot run successfully)
   - Sandbox approach needed for local verification
   - 5 verification types needed: Local, Remote CocoaPods, Remote SPM, Sample App, Device

### Dependencies Between Components

```
msp-release.sh
    ├── lib/config_loader.sh     → reads Scripts/config/release.yaml
    ├── lib/release-common.sh    → UI, logging, colors
    └── release/orchestrator/modular.sh
        ├── release/preflight/preflight.sh
        ├── release/publish/pods/publish.sh
        │   └── lib/cocoapods.sh (update_specs_repo with TTL)
        ├── release/publish/spm/publish.sh
        └── release/verify/verify.sh
            └── release/verify_remote/* (broken, needs rewrite)
```

## Data Model

### Release Configuration Schema (YAML)

```yaml
# Scripts/config/release.yaml - Consolidated config

# Version metadata
version: "1.0.0"                    # Required for actual releases
release_branch: ""                  # Auto-generated if empty
base_branch: "main"

# Default profile
default_profile: local-dev

# Profiles define behavior presets
# NOTE: mode (simple/full) is controlled by --full flag, NOT by profile
profiles:
  local-dev:
    dry_run: true                   # Preview without publishing
    validation:
      preflight: basic              # basic or full
    logging:
      level: info
      format: pretty
    notifications:
      slack:
        enabled: true
        env: prod                   # Same as production
    safety:
      allow_existing_tag: true
      allow_existing_release: true

  quick-test:
    dry_run: true
    validation:
      preflight: none               # Skip all validation
    logging:
      level: warn
      format: pretty
    notifications:
      slack:
        enabled: false
    safety:
      allow_existing_tag: true
      allow_existing_release: true

  production:
    dry_run: false                  # Real publishing
    validation:
      preflight: full
    logging:
      level: info
      format: pretty                # Same as local (not JSON)
    notifications:
      slack:
        enabled: true
        env: prod
    safety:
      allow_existing_tag: false
      allow_existing_release: false
      require_ci: false             # TODO: Set to true when Jenkins ready

# Module configuration
# NOTE: ALL modules use binary distribution (HTTP zip + vendored_frameworks)
# Total: 11 modules
pods:
  enabled: true
  modules:
    - MSPiOSCore
    - MSPSharedLibraries
    - MSPGoogleAdsTypes
    - MSPPrebidAdapter
    - MSPGoogleAdapter
    - MSPFacebookAdapter
    - MSPNovaAdapter
    - MSPAmazonAdapter
    - MSPMolocoAdapter
    - MSPLiftoffAdapter
    - MSPCore                       # Last (depends on MSPPrebidAdapter)

spm:
  enabled: true
  packages: [...]                   # Same as pods modules

# Verification configuration (controlled by --full flag)
verify:
  sandbox_dir: "/tmp/msp-verify-sandbox"
  cleanup_on_success: true
  types:
    local: true
    remote_pods: true
    remote_spm: true
    sample_app: true
    device: false                   # Optional
```

**Profile 设计说明**：
- **mode（simple/full）由 `--full` 参数控制**，不在 profile 中定义
- **CI 和 Local 没有区别**：日志格式、Slack channel 都一样
- **去掉 ci-test profile**：CI 发布用 production profile
- **未来 Jenkins 就绪后**：设置 `safety.require_ci: true` 限制 Local 不能执行 production

### Release State Schema (JSON)

```json
{
  "schema_version": 2,
  "run_id": "uuid",
  "mode": "run|resume",
  "release_mode": "simple|full",    // NEW
  "version": "1.0.0",
  "base_branch": "main",
  "release_branch": "release/1.0.0",
  "dry_run": false,
  "profile": "production",          // NEW

  "phases": {                       // NEW: Phase-level tracking
    "preflight": {
      "status": "success|failed|pending|skipped",
      "steps": {
        "static": {"status": "success", "attempt": 1},
        "build": {"status": "success", "attempt": 1}
      }
    },
    "publish_pods": {
      "status": "in_progress",
      "steps": {
        "MSPSharedLibraries": {"status": "success"},
        "MSPCore": {"status": "failed", "error": "..."}
      }
    },
    "publish_spm": {...},
    "verify": {
      "status": "pending",
      "steps": {
        "local": {"status": "skipped"},      // skipped in simple mode
        "remote_pods": {"status": "pending"},
        "remote_spm": {"status": "pending"}
      }
    }
  },

  "git": {
    "tag_created": true,
    "tag_name": "v1.0.0",
    "release_branch_pushed": true,
    "github_release_created": true
  },

  "timestamps": {
    "started_at": "ISO8601",
    "updated_at": "ISO8601",
    "completed_at": null
  },

  "last_error": {
    "phase": "publish_pods",
    "step": "MSPCore",
    "message": "pod trunk push failed",
    "exit_code": 1,
    "occurred_at": "ISO8601"
  }
}
```

## Quickstart Guide (Post-Implementation)

### Simple Release (Default)

```bash
# Quick release with minimal verification
./Scripts/msp-release.sh run 1.0.0

# Equivalent to:
./Scripts/msp-release.sh run 1.0.0 --profile=local-dev
```

### Full Release with Verification

```bash
# Production release with all verification
./Scripts/msp-release.sh run --full 1.0.0

# Or use production profile
./Scripts/msp-release.sh run --profile=production 1.0.0
```

### Resume from Failure

```bash
# Resume in simple mode (default)
./Scripts/msp-release.sh resume

# Resume with full verification
./Scripts/msp-release.sh resume --full
```

### CocoaPods or SPM Only

```bash
# CocoaPods only
./Scripts/msp-release.sh pods 1.0.0

# SPM only
./Scripts/msp-release.sh spm 1.0.0
```

### View Configuration

```bash
# Show effective configuration
./Scripts/msp-release.sh env
```

## Contracts

### CLI Interface Contract

```
msp-release.sh <command> [options] [VERSION]

Commands:
  run       Full release (pods + SPM)
  pods      CocoaPods release only
  spm       SPM release only
  resume    Resume failed release
  verify    Run verification only
  env       Show effective configuration
  help      Show help

Options:
  --full              Enable full mode (all verification)
  --profile=NAME      Use named profile
  --config=FILE       Load config file
  --dry-run           Show what would happen
  --verbose           Enable verbose output
  --skip-pods         Skip CocoaPods release
  --skip-spm          Skip SPM release
  --version=VER       Specify version (alternative to positional)
  --release-notes=MSG Specify release notes
```

### Logging Contract

```
Format: [Phase X/4] [Step NN/MM] [LEVEL] Message

Phases (4 total):
  Phase 1: Preflight  (5 steps)  - 预检：git、branch、version、deps、env
  Phase 2: Build      (5 steps)  - 构建：clean、XCF core、XCF adapters、archive、upload
  Phase 3: Publish    (14 steps) - 发布：pods env → 11 pods → spm env → Package.swift → push
  Phase 4: Verify     (6 steps)  - 验证：local pods/spm、remote pods/spm、sample app、device

Levels:
  ERROR - Blocking errors (release cannot continue)
  WARN  - Non-blocking issues (e.g., CDN timeout)
  INFO  - Normal progress information
  DEBUG - Detailed debugging (--verbose only)

Phase separators:
  ════════════════════════════════════════════════════
  ✓ Phase 1/4: Preflight completed (12.3s)
  ════════════════════════════════════════════════════

Examples:
  [Phase 1/4] [Step 01/05] [INFO] Git status check...
  [Phase 3/4] [Step 05/14] [INFO] Publishing MSPGoogleAdapter...
  [Phase 3/4] [Step 05/14] [WARN] Pod availability timeout (CDN delay possible)
  [Phase 3/4] [Step 05/14] [ERROR] pod trunk push failed: MSPCore

Final summary:
  ════════════════════════════════════════════════════
  Release Summary: v1.0.0
  ════════════════════════════════════════════════════
  Phase 1: Preflight  ✓  12.3s
  Phase 2: Build      ✓  8m 45s
  Phase 3: Publish    ✓  15m 32s
  Phase 4: Verify     ⊘  skipped (simple mode)
  ────────────────────────────────────────────────────
  Total: 24m 29s | Status: SUCCESS
  ════════════════════════════════════════════════════
```

### Commit Message Contract

```
release(<scope>): <module>@<version>

Scopes:
  pods   - CocoaPods release
  spm    - SPM release
  tag    - Git tag creation
  config - Configuration changes

Examples:
  release(pods): MSPCore@1.0.0
  release(pods): MSPGoogleAdapter@1.0.0
  release(spm): Package.swift@1.0.0
  release(tag): v1.0.0
```

## Implementation Phases

> **Phase Mapping** (plan.md → tasks.md):
> Plan Phase 0 → Tasks Phase 1-2 | Plan Phase 1 → Tasks Phase 3 |
> Plan Phase 2 → Tasks Phase 4 | Plan Phase 3 → Tasks Phase 5 |
> Plan Phase 4 → Tasks Phase 9 | Plan Phase 5 → Tasks Phase 10 |
> Plan Phase 6 → Tasks Phase 11 | Tasks Phase 6-8: US3-6 (inline) |
> Tasks Phase 12: DRY Refactor | Tasks Phase 13: Develop Fixes

### Phase 0: Foundation (Test Infrastructure & TDD)

**Goal**: 建立 TDD 基础设施，确保后续重构有测试保护

1. **扩展测试框架结构**
   - 保留 `Scripts/tests/release_state/` 现有基础设施（mock、helpers、sandbox）
   - 新增 `Scripts/tests/unit/` 目录用于函数级单元测试
   - 创建 `Scripts/tests/unit/run_all.sh` 测试运行器
   - 创建 `Scripts/tests/unit/helpers.sh` 单元测试断言工具

2. **为核心模块补充测试**（重构前先有测试保护）
   - `state.sh` 测试：状态读写、状态转换、resume 逻辑
   - `config_loader.sh` 测试：YAML 解析、profile 切换、环境变量覆盖
   - `logger.sh` 测试：phase/step 格式化、日志级别过滤

3. **建立 TDD 工作流**
   - 新功能：严格 TDD（红 → 绿 → 重构）
   - 重构：先补测试 → 测试通过 → 重构 → 验证通过
   - PR 规范：每个 PR 必须包含测试更新

4. **CI 集成**
   - 在 PR workflow 中添加 bash 测试运行
   - 设置覆盖率阈值：核心模块 90%，其他模块 60%

### Phase 1: Config Consolidation

1. Merge config files into single source (`Scripts/config/release.yaml`)
2. Mode (simple/full) controlled by `--full` flag, not profiles
3. Add resume mode profile settings
4. Implement `env` command to show effective config

### Phase 2: Logging Unification

**Goal**: 建立清晰的 4-Phase 日志结构，让用户能准确追踪发布进度

1. **定义 Phase/Step 结构**
   - Phase 1: Preflight（5 steps）- 预检
   - Phase 2: Build（5 steps）- 构建 XCF
   - Phase 3: Publish（14 steps）- 发布 Pods/SPM
   - Phase 4: Verify（6 steps）- 验证（仅 --full 模式）

2. **统一日志格式**
   ```
   [Phase 1/4] [Step 01/05] [INFO] Git status check...
   [Phase 1/4] [Step 02/05] [INFO] Branch validation...
   ════════════════════════════════════════════════════
   ✓ Phase 1/4: Preflight completed (12.3s)
   ════════════════════════════════════════════════════
   [Phase 2/4] [Step 01/05] [INFO] Clean build artifacts...
   ```

3. **日志级别规范**
   - ERROR: 阻断性错误，发布中止
   - WARN: 可继续但需注意（如 CDN timeout）
   - INFO: 正常进度信息
   - DEBUG: 详细调试信息（--verbose）

4. **清理工作**
   - 移除 `lib/logging.sh` 和 `release/utils/logger.sh` 重复函数
   - 统一到单一 logging 模块
   - 删除所有 legacy 日志输出

5. **完成摘要**
   - 发布结束显示各 Phase 耗时
   - 显示成功/失败/跳过状态

### Phase 3: Release Mode Implementation

1. Implement simple mode (skip verification)
2. Implement full mode (all verification)
3. Update resume command with --full support
4. Ensure profile and --full can combine

### Phase 4: Verification System Rewrite

1. Create sandbox isolation for local verification
2. Implement working remote CocoaPods verification
3. Implement working remote SPM verification
4. Add sample app build verification
5. Add optional device test verification

### Phase 5: Optimization & Cleanup

1. **优化 pod spec 更新策略**
   - 集中更新，共享等待状态
   - 去除冗余的 availability check

2. **修复 macOS flock 兼容性**
   - 实现跨平台锁机制（macOS + Linux）

3. **修复 Slack 通知失败问题**
   - 确保失败不阻塞发布流程

4. **注释规范化**（详细要求见 FR-066~069）
   - 统一使用英文注释
   - 函数头注释格式：
     ```bash
     # @description Brief description
     # @param $1 name - description
     # @return description
     ```
   - 清理禁止的注释类型：
     - TODO/FIXME（除非有 issue）
     - 注释掉的代码
     - 过时说明（如 "source distribution"）
     - 开发调试临时注释

5. **Legacy 代码清理**
   - 移除无用代码和函数
   - 统一代码风格

6. **环境变量精简**
   - 从 30+ 减少到 15 个（详见 Environment Variable Audit）

7. **脚本模块化拆分**（FR-072~076）

   **目标**: 将超长脚本拆分为可维护的模块

   **publish.sh 拆分策略** (6700+ 行 → 多个 ~500 行模块):
   ```
   Scripts/release/publish/pods/
   ├── publish.sh              # 入口点，调度逻辑 (~300 行)
   ├── lib/
   │   ├── github_release.sh   # create_or_verify_github_release, generate_release_notes
   │   ├── pod_trunk.sh        # trunk push, availability check
   │   ├── pod_lint.sh         # podspec lint, validation
   │   ├── tag_management.sh   # tag creation, push to remotes
   │   └── notify.sh           # Slack/email notifications
   └── config/
       └── constants.sh        # 配置常量、默认值
   ```

   **msp-release.sh 拆分策略** (2300+ 行):
   ```
   Scripts/
   ├── msp-release.sh          # CLI 入口，flag 解析 (~500 行)
   └── release/
       └── cli/
           ├── commands.sh     # do_run, do_pods, do_spm 等
           ├── wizard.sh       # 交互式向导
           └── resume.sh       # resume 逻辑
   ```

   **modular.sh 拆分策略** (2200+ 行):
   ```
   Scripts/release/orchestrator/
   ├── modular.sh              # 主调度器 (~400 行)
   └── phases/
       ├── phase1_preflight.sh
       ├── phase2_build.sh
       ├── phase3_publish.sh
       └── phase4_verify.sh
   ```

   **拆分原则**:
   - 渐进式拆分：每次触碰文件时提取一个模块
   - 保持向后兼容：旧的函数调用方式暂时保留
   - 先提取最独立的功能（如 github_release.sh）
   - 每个模块有 `_init()` 函数检查依赖

### Phase 6: Documentation & CI Compatibility

1. **文档更新**
   - `Scripts/README.md`：新命令、profile 系统、环境变量、TDD 测试说明
   - `README.md`（根目录）：发布相关说明（如有）
   - `Tests/README.md`：新增 bash 测试框架说明
   - `specs/002-release-system-refactor/quickstart.md`：使用示例
   - 清理文档中的过时内容（不存在的 adapter、过时的环境变量）

2. **CI 兼容性保证**
   - 验证现有 `ci-pull-request.yml` 所有 job 通过
   - 在 CI workflow 中新增 bash 测试步骤：
     ```yaml
     - name: Run Bash Unit Tests
       run: ./Scripts/tests/unit/run_all.sh
     - name: Run Bash Integration Tests
       run: ./Scripts/tests/release_state/run_all.sh
     ```
   - 不修改现有 CI job 结构，只新增测试步骤

3. **最终验证**
   - 完整 PR 流程测试（提交 → CI 通过 → 合并）
   - 本地发布端到端测试（dry-run 模式）
   - Performance benchmarking：验证 SC-001（simple 模式耗时减少 30%）

## Complexity Tracking

| Aspect | Complexity | Justification |
|--------|------------|---------------|
| Two config files → One | Medium | Need careful migration path |
| Verification rewrite | High | Currently non-functional, full rewrite needed |
| macOS flock workaround | Medium | Platform-specific behavior |
| Test coverage 70% | High | Large codebase, many edge cases |

## Risk Mitigation

1. **Breaking existing workflows**: Run in parallel with old system initially, feature flag for new behavior
2. **CI compatibility**: Test against actual GitHub Actions environment
3. **Pod publish failures**: Maintain current retry logic, enhance error recovery
4. **State migration**: Support both old and new state schema during transition

## Success Metrics Mapping

| Spec SC | Metric | Target | Measurement |
|---------|--------|--------|-------------|
| SC-001 | Simple mode speed | -30% | Time comparison before/after |
| SC-002 | Log format compliance | 100% | Grep for non-compliant patterns |
| SC-003 | Environment variables | ≤15 | Count in config documentation |
| SC-004 | Test coverage | 70% | Line coverage of core modules |
| SC-005 | Resume reliability | 100% | Test suite pass rate |
| SC-006 | Sandbox isolation | 0 repo changes | Git status after verification |
| SC-007 | Verification pass rate | 95% | Full mode success rate |
| SC-008 | Cross-platform locks | Works on both | CI + local testing |
| SC-009 | Slack success rate | 99% | Notification audit |
| SC-010 | Code reduction | -20% | LOC comparison |

## Environment Variable Audit

**Goal**: Reduce from 30+ variables to ≤15 essential variables (SC-003)

### Current Variables (30+)

Based on analysis of `Scripts/` directory:

#### Release Control (7 variables)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `DRY_RUN` | ✅ Keep | Essential | `profiles.{}.dry_run` |
| `MSP_DRY_RUN` | ❌ Remove | Duplicate | Use `DRY_RUN` only |
| `MSP_RELEASE_TIER` | ❌ Remove | Deprecated | Use `DRY_RUN` |
| `MSP_ALLOW_LOCAL_RELEASE` | ❌ Remove | Legacy | Use `DRY_RUN` |
| `MSP_ALLOW_TRUNK_PUSH` | ❌ Remove | Legacy | Use `DRY_RUN` |
| `MSP_RELEASE_MODE` | ✅ Keep | CLI vs CI | Internal use |
| `MSP_RESUME_MODE` | ✅ Keep | Resume flag | Internal use |

#### Validation Control (12 variables → 4)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_PODS_ENABLED` | ⚠️ Migrate | To config | `validation.pods` |
| `MSP_SPM_ENABLED` | ⚠️ Migrate | To config | `validation.spm` |
| `MSP_XCFRAMEWORK_VALIDATION` | ⚠️ Migrate | To config | `validation.xcframework` |
| `MSP_SKIP_LOCAL_VALIDATION` | ❌ Remove | Inverted | `validation.local` |
| `MSP_SKIP_REMOTE_VALIDATION` | ❌ Remove | Inverted | `validation.remote` |
| `MSP_SKIP_DEVICE_VALIDATION` | ❌ Remove | Inverted | `validation.device` |
| `MSP_SKIP_PODSPEC_VALIDATION` | ❌ Remove | Inverted | `validation.pods` |
| `MSP_VERIFY_LOCAL` | ❌ Remove | Duplicate | Use config |
| `MSP_VERIFY_REMOTE` | ❌ Remove | Duplicate | Use config |
| `MSP_VERIFY_DEVICE` | ❌ Remove | Duplicate | Use config |
| `MSP_VERIFY_PODS` | ❌ Remove | Duplicate | Use config |
| `MSP_VERIFY_SPM` | ❌ Remove | Duplicate | Use config |

#### Verification Disable Flags (10 variables → 1)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_DISABLE_POST_VERIFICATION` | ⚠️ Migrate | To `--full` | Controlled by `--full` flag |
| `MSP_SKIP_LOCAL_VERIFY` | ❌ Remove | Legacy | Use `--full` |
| `MSP_SKIP_DEVICE_VERIFY` | ❌ Remove | Legacy | Use `--full` |
| `MSP_SKIP_PODS_VERIFY` | ❌ Remove | Legacy | Use `--full` |
| `MSP_SKIP_SPM_LOCAL_BUILD` | ❌ Remove | Legacy | Use `--full` |
| `MSP_SKIP_XCF_VERIFY` | ❌ Remove | Legacy | Use `--full` |
| `MSP_REMOTE_VERIFY_ENABLED` | ❌ Remove | Legacy | Use `--full` |
| `MSP_DEVICE_VERIFY_ENABLED` | ❌ Remove | Legacy | Use `--full` |
| `MSP_XCF_VERIFY_ENABLED` | ❌ Remove | Legacy | Use `--full` |
| `MSP_XCF_VERIFY` | ❌ Remove | Duplicate | Use config |

#### Notifications (4 variables)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_SLACK_ALERT_ENV` | ✅ Keep | Env override | `notifications.slack.env` |
| `MSP_SLACK_DM_OVERRIDE` | ✅ Keep | DM routing | N/A (special) |
| `MSP_SLACK_TEST_WEBHOOK` | ✅ Keep | Test webhook | N/A (secret) |
| `MSP_EMAIL_DISABLED` | ⚠️ Migrate | To config | `notifications.email.enabled` |

#### Logging & Session (5 variables)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_LOG_LEVEL` | ✅ Keep | Env override | `logging.level` |
| `MSP_SESSION_ID` | ✅ Keep | Session tracking | Internal use |
| `MSP_LOG_FILE` | ✅ Keep | Log path | Internal use |
| `MSP_METRICS_FILE` | ✅ Keep | Metrics path | Internal use |
| `MSP_LOG_FORMAT` | ⚠️ Migrate | To config | `logging.format` |

#### Safety Controls (3 variables)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_ALLOW_EXISTING_TAG` | ✅ Keep | Env override | `safety.allow_existing_tag` |
| `MSP_ALLOW_EXISTING_RELEASE` | ✅ Keep | Env override | `safety.allow_existing_release` |
| `MSP_KEEP_SANDBOX` | ⚠️ Migrate | To config | `safety.keep_sandbox` |

#### Performance (4 variables)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_PARALLEL_BUILDS` | ⚠️ Migrate | To config | `performance.parallel_builds` |
| `MSP_MAX_WORKERS` | ⚠️ Migrate | To config | `performance.max_workers` |
| `MSP_CDN_WAIT_TIME` | ⚠️ Migrate | To config | `performance.cdn_wait_time` |
| `MSP_SLACK_BLOCK_MODE` | ❌ Remove | Internal | Hardcode in script |

#### Mode Switching (3 variables)
| Variable | Status | Action | Replacement |
|----------|--------|--------|-------------|
| `MSP_RELEASE` | ✅ Keep | Pod mode | 0=source, 1=binary |
| `MSP_MODE` | ✅ Keep | Target mode | pods-dev/pods-release/spm-release |
| `MSP_ROLLBACK_FORCE` | ✅ Keep | Rollback flag | Internal use |

#### External/Secrets (3 variables - not counted)
| Variable | Status | Notes |
|----------|--------|-------|
| `SLACK_BOT_TOKEN` | ✅ Keep | External secret |
| `SLACK_WEBHOOK_URL` | ✅ Keep | External secret |
| `CI` / `GITHUB_ACTIONS` | ✅ Keep | CI environment detection |

### Target Variables (15)

After cleanup, the following 15 essential variables remain:

```
# Release Control (3)
DRY_RUN              # Core: true/false for dry-run mode
MSP_RELEASE_MODE     # Internal: cli/ci
MSP_RESUME_MODE      # Internal: resume flag

# Mode Switching (2)
MSP_RELEASE          # Pod mode: 0=source, 1=binary
MSP_MODE             # Target: pods-dev/pods-release/spm-release

# Session & Logging (4)
MSP_SESSION_ID       # Session tracking
MSP_LOG_FILE         # Log output path
MSP_METRICS_FILE     # Metrics output path
MSP_LOG_LEVEL        # Override: debug/info/warn/error

# Safety Overrides (2)
MSP_ALLOW_EXISTING_TAG      # Override: allow tag reuse
MSP_ALLOW_EXISTING_RELEASE  # Override: allow release reuse

# Notifications (3)
MSP_SLACK_ALERT_ENV      # Override: test/prod
MSP_SLACK_DM_OVERRIDE    # DM routing override
MSP_SLACK_TEST_WEBHOOK   # Test webhook URL

# Internal (1)
MSP_ROLLBACK_FORCE   # Rollback force flag
```

**Total: 15 variables** (not counting external secrets like `SLACK_BOT_TOKEN`)

### Migration Strategy

1. **Phase 1**: Add deprecation warnings for legacy variables
2. **Phase 2**: Migrate config-driven variables to YAML
3. **Phase 3**: Remove deprecated variables from codebase
4. **Phase 4**: Update documentation

### Validation Command

After refactor, `msp-release.sh env` will show:

```
MSP Release Environment
═══════════════════════════════════════════════════════════════

Profile: production
Mode: simple (use --full for verification)

Essential Variables:
  DRY_RUN                    = false
  MSP_RELEASE_MODE           = cli
  MSP_SESSION_ID             = 20260203-143052-12345
  MSP_LOG_LEVEL              = info
  MSP_ALLOW_EXISTING_TAG     = false
  MSP_ALLOW_EXISTING_RELEASE = false
  MSP_SLACK_ALERT_ENV        = prod

Config-Driven (from release.yaml):
  validation.pods            = true
  validation.spm             = true
  validation.xcframework     = true
  performance.parallel_builds = true
  performance.max_workers    = 6

Deprecated (will be removed):
  (none detected)
```
