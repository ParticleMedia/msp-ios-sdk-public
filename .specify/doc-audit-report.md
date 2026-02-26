# Documentation Audit Report - feature/002-release-system-refactor

> **Generated**: 2026-02-16
> **Branch**: feature/002-release-system-refactor
> **Scope**: Complete documentation review and update proposal

---

## Executive Summary

经过对比分析，feature/002 分支对 release system 进行了**大规模重构**（110+ scripts，88+ commits since 2026年）。当前文档存在以下问题：

### 关键发现
1. **✅ 新增内容丰富** - 大量新增 Scripts/、Docs/、.context/ 文档
2. **⚠️  结构性滞后** - 部分文档未反映新架构（cli/、orchestrator/、utils/）
3. **⚠️  命令不完整** - 缺少最新命令文档（如 `create-github-releases`）
4. **⚠️  层次待优化** - 某些文档信息重复或层级不清

---

## 1. 文档现状分析

### 1.1 文档统计

| 类型 | 数量 | 位置 | 状态 |
|------|------|------|------|
| **顶层文档** | 5 | Docs/ | 部分过时 |
| **Release 文档** | 1 | Docs/RELEASE.md | 需更新 |
| **Scripts 文档** | 3 | Scripts/README.md, Scripts/constitution.md | 部分过时 |
| **Context 条目** | 3 | .context/release/experience/ | ✅ 良好 |
| **AI Agent 文档** | 3 | AGENTS.md, AI_AGENTS.md, .claude/ | ✅ 良好 |

### 1.2 Release System 架构变化

**旧结构** (推测 main 分支):
```
Scripts/
├── msp-release.sh          # 单体脚本
├── publish-pods.sh
└── verify-release.sh
```

**新结构** (feature/002):
```
Scripts/release/
├── cli/                    # ✨ 新增：命令行接口模块化
│   ├── dispatch.sh         # 命令分发
│   ├── commands.sh         # 工具命令
│   ├── create_github_releases.sh  # ✨ 最新：GitHub Release 补偿命令
│   ├── help.sh
│   ├── resume.sh
│   └── ...
├── orchestrator/           # ✨ 新增：发布编排层
│   └── modular.sh
├── publish/
│   ├── pods/
│   │   ├── publish.sh
│   │   └── lib/            # ✨ 新增：模块化库
│   │       ├── github_release_ext.sh
│   │       ├── github_release_verify.sh  # ✨ 最新
│   │       ├── release_orchestration.sh
│   │       └── ...
│   └── spm/
├── utils/                  # ✨ 新增：共享工具
│   ├── state.sh            # 状态管理（刚更新）
│   ├── git.sh
│   └── ...
├── config/                 # ✨ 新增：配置管理
│   └── release.yaml
└── verify*/                # 验证系统
```

**架构提升**:
- ✅ **模块化** - 从单体脚本拆分为功能模块
- ✅ **关注点分离** - cli/, orchestrator/, publish/, utils/ 各司其职
- ✅ **状态管理** - `.msp-release-state.json` + resume 机制
- ✅ **可测试性** - 模块化后支持单元测试
- ✅ **GitHub Release 追踪** - 刚新增的 per-pod 状态管理

---

## 2. 需要更新的文档

### 2.1 ⚠️  HIGH PRIORITY - 架构文档

#### **Docs/RELEASE.md**

**当前问题**:
- ❌ 第 76-89 行：Commands 部分**不完整**，缺少最新命令
- ❌ 第 139-149 行：State Management 示例**不完整**，缺少新增字段
- ⚠️  未反映 cli/ 模块化架构

**需要新增**:
```markdown
### Commands (Updated)

| Command | Description |
|---------|-------------|
| `run <version>` | Execute full release |
| `resume [version]` | Resume from state file |
| `create-github-releases <version>` | ✨ 创建/验证所有 binary pods 的 GitHub Releases |
| `fix-public-tag <version>` | Fix public remote tag |
| `verify <version>` | Run verification |
| `verify-matrix` | Multi-target verification |
| `rollback` | Rollback release |
| `preflight` | Pre-release checks |
| `pods/spm <version>` | Package-specific release |
| `config` | Show effective config |
| `env [--show]` | Show environment |

### State Management (Updated Schema)

```json
{
  "schema_version": 3,
  "version": "1.0.4-rc.10",
  "release_mode": "full",
  "pods": {
    "MSPCore": {
      "status": "published",
      "trunk_verified": true,
      "trunk_verified_at": "2026-02-16T09:13:50Z",
      "github_release_created": true,      // ✨ 新增
      "github_release_url": "https://...", // ✨ 新增
      "github_release_verified_at": "..."  // ✨ 新增
    }
  },
  "git": {
    "tag_created": true,
    "github_release_created": true
  }
}
```
```

**建议新增章节**:
```markdown
### Release System Architecture

#### Modular Design

```
msp-release.sh (entrypoint)
    ↓
cli/dispatch.sh (command routing)
    ↓
orchestrator/modular.sh (workflow coordination)
    ↓
publish/pods/publish.sh (CocoaPods release)
    ↓
lib/*.sh (modular libraries)
```

#### Key Modules

| Module | Purpose | Key Files |
|--------|---------|-----------|
| **cli/** | Command-line interface | dispatch.sh, commands.sh, help.sh |
| **orchestrator/** | Release workflow coordination | modular.sh |
| **publish/** | Package publishing | pods/publish.sh, spm/publish.sh |
| **utils/** | Shared utilities | state.sh, git.sh, github.sh |
| **config/** | Configuration management | release.yaml |
| **verify*/** | Verification systems | verify.sh, verify-matrix/ |
```

---

#### **Scripts/README.md**

**当前问题**:
- ⚠️  第 8-42 行：Directory Structure **部分过时**
- ❌ 第 73-89 行：Subcommands **不完整**
- ⚠️  第 114-138 行：Release Flow 未反映新架构

**需要更新**:

1. **Directory Structure** (第 8-42 行)
   - ✅ 已包含 `release/cli/`, `release/orchestrator/`
   - ❌ 缺少 `release/utils/`、`release/config/` 说明
   - ⚠️  `release/publish/pods/lib/` 未详细说明

2. **Subcommands** (第 73-89 行)
   - 需要添加 `create-github-releases`
   - 需要添加 `config`, `env` 命令

3. **Release Flow** (第 114-138 行)
   - 更新为反映模块化架构：
   ```
   msp-release.sh run
       │
       ├── cli/dispatch.sh → parse command
       │
       ├── orchestrator/modular.sh → coordinate workflow
       │   │
       │   ├── Preflight (preflight/preflight.sh)
       │   ├── Build (xcframeworks/build-*.sh)
       │   ├── Git Ops (utils/git.sh)
       │   ├── GitHub Release (publish/pods/lib/github_release_ext.sh)
       │   │   └── 创建 + 验证 (github_release_verify.sh)  # ✨ 新增
       │   ├── CocoaPods (publish/pods/publish.sh)
       │   │   └── 每个 pod 独立 GitHub Release 追踪     # ✨ 新增
       │   └── Verification (verify/verify.sh)
       │
       └── State tracking (.msp-release-state.json)
           └── Per-pod GitHub Release status              # ✨ 新增
   ```

---

### 2.2 ⚠️  MEDIUM PRIORITY - 功能文档

#### **新增：Scripts/release/README.md**

**问题**: 不存在，建议新增

**建议内容**:
```markdown
# Release System

> **Version**: 3.0 (Post-002 Refactoring)
> **Last Updated**: 2026-02-16

## Architecture

### Design Principles

1. **Modularity** - 功能模块独立，职责明确
2. **Testability** - 每个模块可独立测试
3. **State Management** - 持久化状态支持 resume
4. **Idempotency** - 可安全重复执行
5. **Per-Pod Tracking** - 每个 pod 独立状态追踪

### Module Structure

```
cli/                 # 命令行接口层
├── dispatch.sh      # 命令分发器
├── commands.sh      # 工具命令实现
├── create_github_releases.sh  # GitHub Release 补偿命令
├── help.sh          # 帮助系统
└── resume.sh        # Resume 逻辑

orchestrator/        # 编排层
└── modular.sh       # 工作流编排器

publish/             # 发布层
├── pods/
│   ├── publish.sh           # CocoaPods 发布主脚本
│   └── lib/                 # 模块化库
│       ├── github_release_ext.sh       # GitHub Release 创建
│       ├── github_release_verify.sh    # GitHub Release 验证
│       ├── release_orchestration.sh    # 发布编排
│       ├── distribution_utils.sh       # 分发工具
│       └── ...
└── spm/

utils/               # 工具层
├── state.sh         # 状态管理（支持 per-pod GitHub Release 追踪）
├── git.sh           # Git 操作
└── github.sh        # GitHub 操作

config/              # 配置层
└── release.yaml     # 发布配置

verify*/             # 验证层
├── verify.sh
└── verify-matrix/
```

### State Management

#### Schema v3

```json
{
  "schema_version": 3,
  "pods": {
    "<pod_name>": {
      "status": "published|failed|pending",
      "trunk_verified": true|false,
      "trunk_verified_at": "ISO8601",
      "github_release_created": true|false,      // v3 新增
      "github_release_url": "URL",               // v3 新增
      "github_release_verified_at": "ISO8601"    // v3 新增
    }
  }
}
```

#### State Functions

| Function | Purpose |
|----------|---------|
| `msp_state_set_pod_github_release_created` | 标记 pod 的 GitHub Release 已创建 |
| `msp_state_get_pod_github_release_created` | 获取创建状态 |
| `msp_state_set_pod_github_release_url` | 保存 Release URL |

### Resume Mechanism

Resume 时智能重试：
- ✅ **Trunk verification** - 如果 trunk_verified=false，重新验证
- ✅ **GitHub Release creation** - 如果 github_release_created=false，重新创建
- ✅ **Idempotent** - 如果已成功，跳过

### GitHub Release Workflow

#### 自动创建流程

```
1. Build XCFramework
2. Create ZIP
3. create_github_release_for_pod()
   ├─ create_or_verify_github_release()
   ├─ upload_zip_to_github()
   ├─ wait_for_cdn_propagation()
   ├─ verify_cdn_availability()
   └─ ✨ msp_state_set_pod_github_release_created(pod, true)
4. Unified verification (after all pods)
   └─ verify_all_github_releases()
```

#### 补偿命令

如果自动创建失败：
```bash
./Scripts/msp-release.sh create-github-releases <version>
```

功能：
- 遍历所有 binary distribution pods
- 检查 state.json 中的 github_release_created 状态
- 跳过已创建的，创建缺失的
- 更新 state 文件
```

---

### 2.3 ✅ LOW PRIORITY - 小幅更新

#### **Docs/INDEX.md**
- ✅ 结构良好，仅需微调链接

#### **Docs/AI_AGENTS.md**
- ✅ 架构图完善，无需大改

#### **.context/release/_domain.md**
- 建议添加对 feature-002 refactoring 的引用

---

## 3. 文档层次建议

### 3.1 当前层次问题

**重复内容**:
- `Docs/RELEASE.md` 和 `Scripts/README.md` 都描述 Release Flow
- Commands 在多处重复

**层次不清**:
- 用户文档 vs 开发者文档未明确区分
- 高层概览 vs 详细参考混杂

### 3.2 建议的文档层次

```
📁 Documentation Hierarchy

├── 📄 README.md                     # 项目入口 (User-facing)
│   └── Quick Start, Key Links
│
├── 📄 Docs/INDEX.md                 # 文档导航中心 (User-facing)
│   └── 所有文档的索引
│
├── 📄 Docs/RELEASE.md               # 发布用户指南 (User-facing)
│   ├── How to run a release
│   ├── Available commands
│   ├── Profiles and configurations
│   └── Troubleshooting release issues
│
├── 📄 Scripts/README.md             # Scripts 总览 (Developer-facing)
│   ├── Directory structure
│   ├── Common patterns
│   └── Link to release system docs
│
├── 📄 Scripts/release/README.md     # 发布系统架构 (Developer-facing)
│   ├── Modular architecture深度解析
│   ├── State management internals
│   ├── Module responsibilities
│   └── Extension guide
│
├── 📁 .context/release/             # 经验知识库 (Developer-facing)
│   ├── experience/                  # 问题排查经验
│   └── tech/                        # 技术设计文档
│
└── 📄 Docs/AI_AGENTS.md             # AI 协作架构 (Developer-facing)
    └── Multi-agent collaboration
```

### 3.3 内容分配原则

| 文档 | 受众 | 内容焦点 |
|------|------|----------|
| **Docs/RELEASE.md** | Release Manager | 如何发布、命令用法、配置选项 |
| **Scripts/README.md** | Developer | Scripts 目录总览、通用模式 |
| **Scripts/release/README.md** | Release System Developer | 架构深度、模块设计、扩展指南 |
| **.context/release/** | All | 经验教训、问题排查、设计决策 |

---

## 4. 优先级建议

### Phase 1: 关键修复 (本周)
1. ✅ **更新 Docs/RELEASE.md**
   - 添加 `create-github-releases` 命令
   - 更新 State Management 示例
   - 添加 Architecture 小节

2. ✅ **更新 Scripts/README.md**
   - 更新 Subcommands 列表
   - 修正 Release Flow 架构图

### Phase 2: 架构文档 (下周)
3. ✨ **新增 Scripts/release/README.md**
   - 完整架构文档
   - 模块职责说明
   - 扩展指南

### Phase 3: 优化层次 (长期)
4. 📝 **重组内容分布**
   - 避免重复
   - 明确受众定位
   - 统一术语

---

## 5. 术语统一建议

| 当前术语 | 建议统一为 | 说明 |
|----------|-----------|------|
| "release script" / "publish script" | "release system" | 强调系统性 |
| "pod release" / "cocoapods publishing" | "CocoaPods publishing" | 标准化 |
| "GitHub release" / "GH release" | "GitHub Release" (大写) | 与 GitHub 官方一致 |
| "state file" / ".msp-release-state.json" | "state file (.msp-release-state.json)" | 首次使用时完整 |

---

## 6. 下一步行动

### 建议工作流

1. **Review 本报告** - 讨论是否同意优先级和层次建议
2. **Phase 1 实施** - 更新 RELEASE.md 和 Scripts/README.md
3. **Phase 2 实施** - 新增 Scripts/release/README.md
4. **Phase 3 讨论** - 长期文档重组计划

### 需要讨论的问题

1. **文档层次** - 是否同意 User-facing vs Developer-facing 的划分？
2. **新文档位置** - `Scripts/release/README.md` 是否合适？
3. **Context 条目** - 是否需要为 feature-002 refactoring 创建一个 ctx-release-004？
4. **术语统一** - 是否有其他术语需要统一？

---

## 附录 A：检测到的过时内容

| 文件 | 行数 | 过时内容 | 建议更新 |
|------|------|----------|----------|
| Docs/RELEASE.md | 76-89 | Commands 不完整 | 添加 create-github-releases |
| Docs/RELEASE.md | 139-149 | State 示例缺少新字段 | 添加 github_release_* 字段 |
| Scripts/README.md | 73-89 | Subcommands 不完整 | 添加新命令 |
| Scripts/README.md | 114-138 | Release Flow 未反映模块化 | 更新架构图 |

---

## 附录 B：新增功能未文档化

| 功能 | 实现 | 文档状态 |
|------|------|----------|
| Per-pod GitHub Release tracking | ✅ Implemented | ❌ Not documented |
| create-github-releases command | ✅ Implemented | ❌ Not documented |
| github_release_verify.sh | ✅ Implemented | ❌ Not documented |
| Unified verification step | ✅ Implemented | ⚠️  Partially documented |
| Resume retry logic | ✅ Implemented | ⚠️  Partially documented |

---

**End of Report**
