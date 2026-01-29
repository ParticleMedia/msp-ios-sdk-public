---
name: context-list
description: List, search, and manage context entries in the knowledge base
category: knowledge-management
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Bash, Read]
---

# Context List Skill

> **Type**: Knowledge Management Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Help users browse and manage the context knowledge base

---

## Purpose

Provide users with tools to:
- View all contexts organized by layer and domain
- Filter contexts by domain, layer, or tags
- Search contexts by keywords
- Rebuild the context index when needed
- Understand the structure and content of the knowledge base

**Task Tier**: Tier 0-1 (Trivial to Standard)

---

## Scope

**Does**:
- List all active contexts with "By Layer" and "By Domain" views
- Filter by domain (release/ci/integration/compatibility)
- Filter by layer (business/experience/tech)
- Filter by tags
- Search in titles and content
- Rebuild index.md to refresh statistics
- Display context counts and summaries

**Does NOT**:
- Modify or delete context entries (use archive-context.sh for soft-delete)
- Create new contexts (use `/context.add` instead)
- Search with complex queries (use `search-context.sh` for advanced search)

---

## When to Use

**Primary Scenarios**:
1. User wants to browse available contexts
2. User asks "what contexts do we have?"
3. User wants to find contexts about a specific topic
4. User needs to see context statistics
5. After adding contexts, to verify they appear in the list

**Trigger Phrases**:
- "列出所有上下文" / "list all contexts"
- "查看上下文库" / "view context library"
- "有哪些上下文" / "what contexts exist"
- "/context.list"
- "show me release contexts"

**Quick Decision**:
- User wants to browse → Use this skill
- User wants to search for specific content → Use `search-context.sh` instead
- User wants to add context → Use `/context.add` instead

---

## Filter Options

### Domain Filter (`--domain`)
Limit results to a specific domain:
- `release` - Pod 发布、版本管理
- `ci` - CI/CD 构建流程
- `integration` - 集成兼容问题
- `compatibility` - 版本兼容迁移

**Example**: Show only release-related contexts

### Layer Filter (`--layer`)
Limit results to a specific knowledge type:
- `business` - 业务知识 (产品需求、业务规则)
- `experience` - 经验教训 (调试过程、解决方案) - Most common
- `tech` - 技术知识 (API 用法、架构设计)

**Example**: Show only experience-based troubleshooting contexts

### Tag Filter (`--tag`)
Search for contexts with specific tags:
- Tags are case-insensitive
- Partial matches work (e.g., "pod" matches "podspec")

**Example**: Find all contexts tagged with "crash"

### Search Filter (`--search`)
Search in context titles and content:
- Case-insensitive keyword search
- Searches across all fields

**Example**: Find contexts mentioning "duplicate symbol"

### View Options (`--view`)
- `by-layer` - Group by business/experience/tech
- `by-domain` - Group by release/ci/integration/compatibility
- `all` - Show both views (default)

---

## Procedure

### Step 1: Determine User Intent

Understand what the user wants to see:
- All contexts? → Use no filters
- Specific domain? → Use `--domain`
- Specific type? → Use `--layer`
- Find a topic? → Use `--search`

### Step 2: Execute List Command

Basic usage:
```bash
./Scripts/context/list-context.sh
```

With filters:
```bash
# Filter by domain
./Scripts/context/list-context.sh --domain release

# Filter by layer
./Scripts/context/list-context.sh --layer experience

# Search keyword
./Scripts/context/list-context.sh --search crash

# Combine filters
./Scripts/context/list-context.sh --domain release --layer experience

# Show only one view
./Scripts/context/list-context.sh --view by-layer
```

### Step 3: Interpret Results

The output shows:
- **By Layer** section: Contexts grouped by knowledge type
- **By Domain** section: Contexts grouped by business area
- Each entry includes: ID, Title, Domain/Layer, Created date

**Example Output**:
```
## By Layer

### Experience (5)
经验教训：调试过程、踩坑记录、解决方案

| ID | Title | Domain | Created |
|----|-------|--------|---------|
| ctx-release-001 | Pod 发布失败 | release | 2026-01-29 |
```

### Step 4: Present to User

Summarize the results:
- Total number of contexts found
- Highlight relevant entries based on user's question
- Suggest specific context IDs if user wants details

**Response Template**:
```
找到 {count} 个相关上下文：

{显示相关条目摘要}

要查看具体内容，可以：
- 直接阅读文件: .context/{domain}/{context-id}.md
- 使用搜索工具: ./Scripts/context/search-context.sh {keywords}
```

---

## Special Operations

### Rebuild Index (`--rebuild`)

When to use:
- After manually editing context files
- If index.md seems out of sync
- To refresh statistics

**Command**:
```bash
./Scripts/context/list-context.sh --rebuild
```

This regenerates index.md with:
- Updated counts for each domain and layer
- Current date stamp
- All active contexts listed

**Note**: Rebuilding is automatic when using `/context.add`, so manual rebuild is rarely needed.

---

## Example Workflows

### Workflow 1: User Wants Overview

**User**: "我们有哪些上下文？"

**AI**:
```bash
./Scripts/context/list-context.sh
```

**Response**: "当前有 12 个上下文，分布在 3 个领域：
- Release: 5 个
- CI: 4 个
- Integration: 3 个

大部分是经验教训类(experience)，记录了调试过程和解决方案。"

### Workflow 2: Find Specific Topic

**User**: "有没有关于 pod 发布失败的上下文？"

**AI**:
```bash
./Scripts/context/list-context.sh --domain release --search pod
```

**Response**: "找到 2 个相关上下文：
1. [ctx-release-001] Pod 发布后编译失败
2. [ctx-release-003] Pod trunk push 验证失败

可以查看 .context/release/ctx-release-001.md 了解详情。"

### Workflow 3: Browse by Layer

**User**: "给我看看所有的技术知识类上下文"

**AI**:
```bash
./Scripts/context/list-context.sh --layer tech --view by-domain
```

**Response**: Shows all tech-layer contexts grouped by domain

---

## Best Practices

1. **Start Broad**: Use no filters first to see overall structure
2. **Combine Filters**: Narrow down with `--domain` + `--layer` for precision
3. **Use Search**: For specific topics, `--search` is more flexible than filters
4. **Check Counts**: The (N) count after each section helps gauge coverage
5. **Suggest Next Steps**: After listing, guide users to relevant context IDs

---

## Error Handling

**Common Issues**:

1. **No contexts found**
   - Verify `.context/` directory exists
   - Check if any context files exist: `ls .context/*/ctx-*.md`
   - Suggest running `/context.add` or `/context.init` to create first context

2. **Empty results after filtering**
   - Filters may be too restrictive
   - Suggest broader search or removing filters
   - Show what filters are applied

3. **Script not found**
   - Ensure in repository root
   - Check: `ls Scripts/context/list-context.sh`

---

## Related Skills

- `/context.add` - Create new context entries
- `/context.init` - Initialize from commit history
- `search-context.sh` - Advanced context search with relevance ranking
- `archive-context.sh` - Soft-delete contexts (mark as archived)

---

## Output Examples

### By Layer View
```
## By Layer

### Business (2)
业务知识：产品需求、业务规则、用户场景

| ID | Title | Domain | Created |
|----|-------|--------|---------|
| ctx-release-002 | 发布流程规范 | release | 2026-01-28 |

### Experience (8)
经验教训：调试过程、踩坑记录、解决方案

| ID | Title | Domain | Created |
|----|-------|--------|---------|
| ctx-release-001 | Pod 发布失败 | release | 2026-01-29 |
| ctx-ci-001 | GitHub Actions 超时 | ci | 2026-01-27 |
...
```

### By Domain View
```
## By Domain

### Release (5)

| ID | Title | Layer | Created |
|----|-------|-------|---------|
| ctx-release-001 | Pod 发布失败 | experience | 2026-01-29 |
| ctx-release-002 | 发布流程规范 | business | 2026-01-28 |
...
```

---

## Constitutional Compliance

This skill supports:
- **Federal I.1** (Automation First) - Automates knowledge discovery
- **Federal III.1** (Module Cohesion) - Knowledge base management is cohesive

The list functionality makes the context system transparent and accessible, encouraging knowledge reuse.
