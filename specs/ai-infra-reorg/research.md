# Research: AI 基础设施重组

**Date**: 2026-01-20
**Feature**: [spec.md](./spec.md)

## Research Summary

本文档记录了实施 AI 基础设施重组所需的技术调研结果。

---

## R1: AI 工具配置引用机制

### Decision
使用 `@../path/to/file.md` 语法在主配置文件中引用共享规则文件。

### Rationale
- **Claude**: `.claude/CLAUDE.md` 已使用 `@../constitution.md` 语法
- **Codex**: `.codex/CODEX.md` 已使用 `@../constitution.md` 和 `@../AGENTS.md` 语法
- **Cursor**: `.cursor/CURSOR.md` 已使用相同语法

三个工具都支持 `@../<path>` 引用语法，无需额外适配。

### Alternatives Considered
1. **内联内容**: 在每个配置文件中复制内容 → 维护成本高，易不同步
2. **符号链接**: 使用文件系统链接 → 跨平台兼容性问题
3. **环境变量**: 运行时注入 → 过于复杂，工具支持不一致

### Implementation Notes
```markdown
# 在 .claude/CLAUDE.md, .codex/CODEX.md, .cursor/CURSOR.md 中添加:
@../Sources/AGENTS-SOURCES.md (when working in Sources/)
@../Scripts/AGENTS-SCRIPTS.md (when working in Scripts/)
```

---

## R2: 语义化命名脚本修改

### Decision
修改 `create-new-feature.sh` 移除数字前缀，直接使用语义化名称。

### Rationale
当前脚本（`create-new-feature.sh:249-251`）逻辑：
```bash
FEATURE_NUM=$(printf "%03d" "$((10#$BRANCH_NUMBER))")
BRANCH_NAME="${FEATURE_NUM}-${BRANCH_SUFFIX}"
```

修改为：
```bash
BRANCH_NAME="${BRANCH_SUFFIX}"
```

脚本已有完善的语义化名称生成逻辑（`generate_branch_name` 函数，第 181-226 行），包括：
- 停用词过滤（a, an, the, to, for, etc.）
- 保留技术缩写词
- 3-4 词限制
- 长度截断（GitHub 244 字节限制）

### Alternatives Considered
1. **保留数字但自动同步**: 让所有工具共享计数器文件 → 并发问题复杂
2. **时间戳前缀**: 如 `20260120-feature-name` → 不如语义化名称直观
3. **UUID 前缀**: 如 `a1b2c3-feature-name` → 难以记忆和识别

### Implementation Notes
修改范围：
- 移除 `get_highest_from_specs`、`get_highest_from_branches`、`check_existing_branches` 函数的数字逻辑
- 简化 `BRANCH_NAME` 生成，直接使用 `BRANCH_SUFFIX`
- 添加重名检查：若 spec 目录或分支已存在，提示用户

---

## R3: Swift 日志最佳实践

### Decision
推荐使用 `os_log` (iOS 10+) 或 `Logger` API (iOS 14+)，按项目最低支持版本选择。

### Rationale
本项目目标平台为 iOS 15.0+，可使用 `Logger` API（更现代，更好的 Swift 集成）。

**Logger API 优势**:
- 类型安全的字符串插值
- 隐私标记（`.public`, `.private`）
- 与 Xcode Instruments 集成
- 结构化日志支持

### Alternatives Considered
1. **print()**: 仅用于调试，无日志级别、无持久化
2. **NSLog()**: Objective-C 遗留，性能较差
3. **第三方库 (SwiftyBeaver, CocoaLumberjack)**: 增加依赖，本项目不需要

### Implementation Notes
添加到 `Sources/constitution.md`:
```markdown
## Article IV.4: Logging Standards
**4.4 (Unified Logging)**: Use `Logger` API (iOS 14+) for all logging.
- Define subsystem as bundle identifier
- Define category per module (e.g., "Network", "AdRendering")
- Use appropriate log levels: .debug, .info, .notice, .error, .fault
- Mark sensitive data with .private
```

---

## R4: Swift 错误处理最佳实践

### Decision
采用分层错误处理策略：`Result` 用于异步/回调，`throws` 用于同步可失败操作。

### Rationale
- **Result<T, Error>**: 适合异步回调、网络请求、可组合的错误传播
- **throws/do-catch**: 适合同步操作、文件 I/O、初始化器
- **Optional**: 仅用于"无值"语义，不用于错误表示

### Alternatives Considered
1. **纯 Optional**: 丢失错误上下文，调试困难
2. **纯 throws**: 异步场景中不够符合人体工程学
3. **Combine/async-await**: 本项目已有回调模式，大规模迁移成本高

### Implementation Notes
添加到 `Sources/constitution.md`:
```markdown
## Article IV.5: Error Handling Standards
**4.5 (Structured Error Handling)**:
- Define domain-specific Error enums (e.g., `AdLoadingError`, `NetworkError`)
- Use `Result<T, Error>` for async operations with completion handlers
- Use `throws` for sync operations that can fail
- Never use Optional to represent error states
- Log errors at point of origin with context
```

---

## R5: XCodeGen 限制明确化

### Decision
在 `Sources/constitution.md` 中明确 XCodeGen 工作流，与 Federal Constitution Article I.2 保持一致。

### Rationale
当前限制仅在 Federal Constitution（`constitution.md` 第 14 行）：
> **1.2 (Deterministic Builds)**: [Non-Negotiable] Directly modifying `.xcodeproj` or `.xcworkspace` files is strictly forbidden.

需要在 `Sources/constitution.md` 中添加具体操作指导。

### Implementation Notes

**Layered Approach** (per clarification session 2026-01-20):

添加到 `Sources/constitution.md` (precision - enforced rule):
```markdown
## Article IV.6: Project Configuration (References Federal I.2)
**4.6 (XCodeGen Workflow)**: All Xcode project changes must use XcodeGen.
Modify `*.yml.template` files, then run XcodeGen to regenerate `.xcodeproj`.
Never commit `.xcodeproj` changes directly.

Rationale: `.xcodeproj` and `.xcworkspace` are in `.gitignore`; only template files are source-controlled.
```

添加到 `AGENTS.md` (guidance - detailed workflow):
```markdown
## Project Configuration Workflow

When modifying Xcode project structure:
1. Identify relevant template: `project.yml.template` or `*.podspec.template`
2. Make changes to YAML template
3. Run: `xcodegen generate`
4. Verify: Open `.xcodeproj` and check changes
5. Commit: Only commit `*.yml.template` changes

Common scenarios:
- Add new target: Edit `project.yml.template` targets section
- Add source files: XcodeGen auto-discovers files by convention
- Change build settings: Edit settings section in template

Troubleshooting:
- If XcodeGen fails: Check YAML syntax with `yamllint`
- If project missing files: Check glob patterns in template
```

---

## R6: Speckit 多 Constitution 检查

### Decision
修改 speckit 的 constitutional review 逻辑，递归检查所有 `constitution.md` 文件。

### Rationale
当前 speckit prompts 只引用根 `constitution.md`。根据 Federal Constitution 的 Governance 规则，State Constitutions（子目录 `constitution.md`）也应被检查。

### Implementation Notes
在 speckit plan prompt 中添加：
```bash
# Find all constitution files
CONSTITUTION_FILES=$(find . -name "constitution.md" -not -path "./specs/*" -not -path "./.specify/*")

# Check each one
for CONST_FILE in $CONSTITUTION_FILES; do
  echo "Checking: $CONST_FILE"
  # Run constitutional review against this file
done
```

预期检查的文件：
- `/constitution.md` (Federal)
- `/Sources/constitution.md` (State - Sources)
- `/Scripts/constitution.md` (State - Scripts)
- `/Tests/constitution.md` (State - Tests)

---

## R7: 现有 Spec 迁移策略

### Decision
创建迁移脚本，批量重命名现有 spec 目录和更新相关引用。

### Rationale
需要迁移：
- `001-unit-test-setup` → `unit-test-setup`
- `002-ai-infra-refactor` → `ai-infra-refactor`
- `003-ai-infra-reorg` → `ai-infra-reorg`

每个迁移包括：
1. 重命名 `specs/` 下的目录
2. 更新 `spec.md` 中的 `Feature Branch` 字段
3. 重命名 git 分支（如果存在）

### Implementation Notes
创建迁移脚本 `migrate-spec-names.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Migrate a single spec
migrate_spec() {
  local old_name="$1"
  local new_name="${old_name#[0-9][0-9][0-9]-}"

  # Skip if already migrated
  [ "$old_name" = "$new_name" ] && return 0

  # Rename directory
  mv "specs/$old_name" "specs/$new_name"

  # Update spec.md
  sed -i '' "s/Feature Branch.*$old_name/Feature Branch: \`$new_name\`/" "specs/$new_name/spec.md"

  # Rename git branch if exists
  git branch -m "$old_name" "$new_name" 2>/dev/null || true
}

# Migrate all numbered specs
for dir in specs/[0-9][0-9][0-9]-*; do
  [ -d "$dir" ] && migrate_spec "$(basename "$dir")"
done
```

---

## Summary

| Research Item | Decision | Status |
|---------------|----------|--------|
| R1: 配置引用机制 | 使用 `@../` 语法 | ✅ Resolved |
| R2: 语义化命名 | 修改脚本移除数字前缀 | ✅ Resolved |
| R3: Swift 日志 | 使用 Logger API | ✅ Resolved |
| R4: 错误处理 | Result + throws 分层策略 | ✅ Resolved |
| R5: XCodeGen 限制 | 添加到 Sources/constitution.md | ✅ Resolved |
| R6: 多 Constitution 检查 | 递归查找所有 constitution.md | ✅ Resolved |
| R7: Spec 迁移 | 创建迁移脚本 | ✅ Resolved |

所有 NEEDS CLARIFICATION 已解决，可进入 Phase 1 设计阶段。
