# Quickstart: AI 基础设施重组

**Date**: 2026-01-20
**Feature**: [spec.md](./spec.md)

## Prerequisites

- Git (用于分支重命名)
- Bash shell (POSIX-compliant)
- 对项目配置文件的写权限

---

## Implementation Order

按依赖关系排序的实施顺序：

### Phase 1: 创建共享规则文件 (无依赖)

```bash
# 1.1 创建 Sources/AGENTS-SOURCES.md
touch Sources/AGENTS-SOURCES.md

# 1.2 创建 Scripts/AGENTS-SCRIPTS.md
touch Scripts/AGENTS-SCRIPTS.md
```

**内容要点**:
- `AGENTS-SOURCES.md`: MVVM-Repo 架构、API 设计原则、测试策略
- `AGENTS-SCRIPTS.md`: Config-driven 开发、POSIX 兼容、错误处理

---

### Phase 2: 更新 Constitution (无依赖)

```bash
# 2.1 更新 Sources/constitution.md
# 添加 Article IV.4 (Logging)
# 添加 Article IV.5 (Error Handling)
# 添加 Article IV.6 (XCodeGen Workflow)
```

---

### Phase 3: 更新 Agent 配置 (依赖 Phase 1)

```bash
# 3.1 更新 .claude/CLAUDE.md - 添加 @import
# 3.2 更新 .codex/CODEX.md - 添加 @import
# 3.3 更新 .cursor/CURSOR.md - 添加 @import
```

**添加内容**:
```markdown
## Domain-Specific Imports

When working in Sources/:
@../Sources/AGENTS-SOURCES.md

When working in Scripts/:
@../Scripts/AGENTS-SCRIPTS.md
```

---

### Phase 4: 清理 AGENTS.md 和 CLAUDE.md (依赖 Phase 1, 3)

```bash
# 4.1 从 AGENTS.md 移除 MVVM-Repo 内容
# 4.2 将 CLAUDE.md 的 Recent Changes 移至 AGENTS.md
# 4.3 删除根目录 CLAUDE.md
rm CLAUDE.md
```

---

### Phase 5: 修改 Speckit 脚本 (无依赖)

```bash
# 5.1 修改 create-new-feature.sh - 移除数字前缀
# 5.2 修改 update-agent-context.sh - 更新 AGENTS.md 而非 CLAUDE.md
```

**create-new-feature.sh 关键修改**:
```bash
# Before:
BRANCH_NAME="${FEATURE_NUM}-${BRANCH_SUFFIX}"

# After:
BRANCH_NAME="${BRANCH_SUFFIX}"
```

---

### Phase 6: 迁移现有 Spec (依赖 Phase 5)

```bash
# 6.1 运行迁移脚本
./migrate-spec-names.sh

# 或手动执行:
mv specs/001-unit-test-setup specs/unit-test-setup
mv specs/002-ai-infra-refactor specs/ai-infra-refactor
mv specs/003-ai-infra-reorg specs/ai-infra-reorg

# 更新 spec.md 中的 Feature Branch 字段
# 重命名 git 分支
git branch -m 001-unit-test-setup unit-test-setup
git branch -m 002-ai-infra-refactor ai-infra-refactor
git branch -m 003-ai-infra-reorg ai-infra-reorg
```

---

### Phase 7: 更新 Speckit Constitutional Review (依赖 Phase 2)

修改 speckit prompts 检查所有 constitution 文件：

```bash
# 在 plan 流程中添加多文件检查
CONSTITUTION_FILES=$(find . -name "constitution.md" \
  -not -path "./specs/*" \
  -not -path "./.specify/*")

for CONST_FILE in $CONSTITUTION_FILES; do
  echo "Checking: $CONST_FILE"
  # 执行 constitutional review
done
```

---

## Validation Checklist

实施完成后验证：

```bash
# 1. 验证共享规则文件存在
[ -f "Sources/AGENTS-SOURCES.md" ] && echo "✓ AGENTS-SOURCES.md exists"
[ -f "Scripts/AGENTS-SCRIPTS.md" ] && echo "✓ AGENTS-SCRIPTS.md exists"

# 2. 验证根 CLAUDE.md 已删除
[ ! -f "CLAUDE.md" ] && echo "✓ Root CLAUDE.md deleted"

# 3. 验证 Agent 配置引用
grep -q "AGENTS-SOURCES" .claude/CLAUDE.md && echo "✓ Claude imports updated"
grep -q "AGENTS-SOURCES" .codex/CODEX.md && echo "✓ Codex imports updated"
grep -q "AGENTS-SOURCES" .cursor/CURSOR.md && echo "✓ Cursor imports updated"

# 4. 验证 spec 目录命名
ls specs/ | grep -v "^[0-9]" > /dev/null && echo "✓ Specs use semantic names"

# 5. 验证 Constitution 更新
grep -q "Logging" Sources/constitution.md && echo "✓ Logging rules added"
grep -q "Error Handling" Sources/constitution.md && echo "✓ Error handling added"
grep -q "XCodeGen" Sources/constitution.md && echo "✓ XCodeGen rules added"

# 6. 运行完整验证
./Scripts/target-switching/round-trip-test.sh
```

---

## Rollback Plan

如需回滚：

```bash
# 1. 恢复根 CLAUDE.md
git checkout HEAD~1 -- CLAUDE.md

# 2. 恢复 spec 目录名称
mv specs/unit-test-setup specs/001-unit-test-setup
# ... 其他目录

# 3. 恢复 git 分支名称
git branch -m unit-test-setup 001-unit-test-setup
# ... 其他分支

# 4. 删除新建文件
rm Sources/AGENTS-SOURCES.md Scripts/AGENTS-SCRIPTS.md

# 5. 恢复修改的文件
git checkout HEAD~1 -- AGENTS.md .claude/CLAUDE.md .codex/CODEX.md .cursor/CURSOR.md
```

---

## Estimated Scope

| Phase | Files | Complexity |
|-------|-------|------------|
| Phase 1: Create shared rules | 2 new | Low |
| Phase 2: Update constitution | 1 modify | Low |
| Phase 3: Update agent configs | 3 modify | Low |
| Phase 4: Clean AGENTS/CLAUDE | 2 modify, 1 delete | Low |
| Phase 5: Modify scripts | 2 modify | Medium |
| Phase 6: Migrate specs | 3 rename + updates | Medium |
| Phase 7: Update speckit prompts | ~3 modify | Medium |

**Total**: ~15 files affected
