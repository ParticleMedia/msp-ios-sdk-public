# Data Model: AI 基础设施重组

**Date**: 2026-01-20
**Feature**: [spec.md](./spec.md)

## Overview

本功能不涉及数据库或运行时数据结构，"数据模型"指配置文件层次结构和依赖关系。

---

## Configuration File Hierarchy

### Entity: Constitution File

配置系统的最高权威文档，定义不可变规则。

```text
Constitution
├── Federal (root/constitution.md)
│   ├── Article I: Automation & Determinism
│   ├── Article II: Validation-Driven Imperative
│   └── Article III: Modularity
│
├── State: Sources (Sources/constitution.md)
│   ├── Article IV: Swift Practices
│   ├── Article IV.4: Logging Standards [NEW]
│   ├── Article IV.5: Error Handling [NEW]
│   ├── Article IV.6: XCodeGen Workflow [NEW]
│   └── Article V: Test-First Imperative
│
├── State: Scripts (Scripts/constitution.md)
│   └── Article VI: Scripting Integrity
│
└── State: Tests (Tests/constitution.md)
    └── Article VIII-IX: Test Quality
```

**Relationships**:
- Federal → State: State augments but cannot override Federal
- All AI tools must check all applicable Constitution files

---

### Entity: Agent Configuration File

定义特定 AI 工具的行为规则。

```text
Agent Configuration
├── Claude (.claude/CLAUDE.md)
│   ├── @../constitution.md
│   ├── @../AGENTS.md
│   ├── @../Sources/AGENTS-SOURCES.md [NEW]
│   └── @../Scripts/AGENTS-SCRIPTS.md [NEW]
│
├── Codex (.codex/CODEX.md)
│   ├── @../constitution.md
│   ├── @../AGENTS.md
│   ├── @../Sources/AGENTS-SOURCES.md [NEW]
│   └── @../Scripts/AGENTS-SCRIPTS.md [NEW]
│
└── Cursor (.cursor/CURSOR.md)
    ├── @../constitution.md
    ├── @../AGENTS.md
    ├── @../Sources/AGENTS-SOURCES.md [NEW]
    └── @../Scripts/AGENTS-SCRIPTS.md [NEW]
```

**Relationships**:
- All agents import same shared files via @../ syntax
- Imports are conditional based on working directory (Sources/ vs Scripts/)

---

### Entity: Shared Domain Rules

领域特定规则，被所有 AI 工具共享。

```text
Shared Domain Rules
├── Sources/AGENTS-SOURCES.md [NEW]
│   ├── MVVM-Repository Architecture
│   │   ├── View → ViewModel → Repository → DataSource
│   │   └── Testing Strategy
│   ├── API Design Principles
│   └── Performance Guidelines
│
├── Scripts/AGENTS-SCRIPTS.md [NEW]
│   ├── Config-Driven Development
│   ├── POSIX Compliance
│   ├── Error Handling (set -euo pipefail)
│   └── Idempotency Requirements
│
└── AGENTS.md (Global)
    ├── Project Technical Context
    │   ├── Swift 5.0, iOS 15.0+
    │   └── Quick/Nimble Testing
    ├── Pre-Task Checklist
    ├── Shared Resources Locations
    ├── Basic Workflow (branching, commits)
    ├── Read-Only Zones
    └── Recent Changes [MOVED from CLAUDE.md]
```

**Relationships**:
- AGENTS-SOURCES.md: Imported when working in Sources/
- AGENTS-SCRIPTS.md: Imported when working in Scripts/
- AGENTS.md: Always imported (global context)

---

### Entity: Spec Directory

功能规范目录，从数字前缀改为语义化命名。

```text
Spec Directory Structure
├── specs/
│   ├── unit-test-setup/          [RENAMED from 001-unit-test-setup]
│   │   ├── spec.md
│   │   ├── plan.md
│   │   ├── tasks.md
│   │   └── checklists/
│   │
│   ├── ai-infra-refactor/        [RENAMED from 002-ai-infra-refactor]
│   │   └── ...
│   │
│   └── ai-infra-reorg/           [RENAMED from 003-ai-infra-reorg]
│       └── ...
```

**Attributes**:
- `name`: 语义化短名称 (2-4 词, 小写, 连字符分隔)
- `branch`: 同名 git 分支
- `status`: Draft | In Progress | Implemented

**Validation Rules**:
- 名称不能与现有 spec 或分支重复
- 名称必须由 `generate_branch_name()` 生成或用户指定

---

## File Dependency Graph

```text
                    ┌─────────────────────┐
                    │ constitution.md     │
                    │ (Federal)           │
                    └─────────┬───────────┘
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Sources/         │ │ Scripts/         │ │ Tests/           │
│ constitution.md  │ │ constitution.md  │ │ constitution.md  │
│ (State)          │ │ (State)          │ │ (State)          │
└────────┬─────────┘ └────────┬─────────┘ └──────────────────┘
         │                    │
         ▼                    ▼
┌──────────────────┐ ┌──────────────────┐
│ Sources/         │ │ Scripts/         │
│ AGENTS-SOURCES   │ │ AGENTS-SCRIPTS   │
│ .md [NEW]        │ │ .md [NEW]        │
└────────┬─────────┘ └────────┬─────────┘
         │                    │
         └─────────┬──────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │     AGENTS.md       │
         │  (Global Context)   │
         └─────────┬───────────┘
                   │
    ┌──────────────┼──────────────┐
    │              │              │
    ▼              ▼              ▼
┌────────┐   ┌────────┐   ┌────────┐
│.claude/│   │.codex/ │   │.cursor/│
│CLAUDE  │   │CODEX   │   │CURSOR  │
│.md     │   │.md     │   │.md     │
└────────┘   └────────┘   └────────┘
```

---

## State Transitions

### Spec Lifecycle

```text
[Non-existent]
    │
    │ /speckit.specify
    ▼
[Draft] ─────────────────────────────────────────┐
    │                                            │
    │ /speckit.clarify                           │
    ▼                                            │
[Clarified]                                      │
    │                                            │
    │ /speckit.plan                              │
    ▼                                            │
[Planned]                                        │
    │                                            │
    │ /speckit.tasks                             │
    ▼                                            │
[Ready for Implementation]                       │
    │                                            │
    │ Implementation                             │
    ▼                                            │
[Implemented] ◄──────────────────────────────────┘
                 (can skip steps if simple)
```

---

## Migration Mapping

| Old Name | New Name | Git Branch |
|----------|----------|------------|
| `001-unit-test-setup` | `unit-test-setup` | `unit-test-setup` |
| `002-ai-infra-refactor` | `ai-infra-refactor` | `ai-infra-refactor` |
| `003-ai-infra-reorg` | `ai-infra-reorg` | `ai-infra-reorg` |

---

## Summary

| Entity | Count | Status |
|--------|-------|--------|
| Constitution Files | 4 (1 Federal + 3 State) | 1 修改 (Sources) |
| Agent Config Files | 3 | 全部修改 |
| Shared Domain Rules | 2 | 新建 |
| Global AGENTS.md | 1 | 修改 |
| Root CLAUDE.md | 1 | 删除 |
| Spec Directories | 3 | 全部重命名 |
| Scripts | 2 | 修改 |
