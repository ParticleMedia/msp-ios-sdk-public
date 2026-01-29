---
name: context-add
description: Manually add a new context entry to preserve valuable debugging experience
category: knowledge-management
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Bash, Read, Grep]
---

# Context Add Skill

> **Type**: Knowledge Management Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Help users preserve valuable debugging and development experience

---

## Purpose

Guide users through creating a new context entry in the `.context/` knowledge base by:
- Collecting structured information (problem, root cause, solution)
- Classifying the context by domain and layer
- Storing it in a reusable format for future reference

**Task Tier**: Tier 1 (Standard - requires user interaction)

---

## Scope

**Does**:
- Launch `Scripts/context/add-context.sh` to collect context information
- Guide users through domain selection (release/ci/integration/compatibility)
- Guide users through layer classification (business/experience/tech)
- Validate inputs and check for duplicates
- Create properly formatted context files
- Update the context index automatically

**Does NOT**:
- Automatically extract context without user input (use `/context.init` instead)
- Modify existing context entries (manual edit required)
- Search or list contexts (use `/context.list` instead)

---

## When to Use

**Primary Scenarios**:
1. After solving a complex problem that took 3+ conversation rounds
2. When user explicitly wants to save debugging experience
3. When AI suggests context precipitation (Section 7.2 in Agents.md)
4. After discovering non-obvious root causes

**Trigger Phrases**:
- "沉淀上下文" / "save this as context"
- "记录这个经验" / "record this experience"
- "/context.add"
- User clicks "yes" on precipitation prompt

**Quick Decision**:
- Problem was solved → Consider suggesting this skill
- Solution was obvious → Skip (not worth preserving)
- Root cause was discovered → Definitely use this skill
- Repeated similar issue → Strongly recommend this skill

---

## Layer Classification Guide

Help users choose the correct layer:

### Business Layer (业务知识)
**Use when**: Content answers "why the product/business requires this"

**Examples**:
- "为什么发布前需要特定的验证流程"
- Product requirements or business rules
- User scenarios and workflows

**Keywords**: requirement, product, user, business, feature, spec

### Experience Layer (经验教训)
**Use when**: Content describes debugging process or problem-solving

**Examples**:
- "发布后 crash 的调试过程和解决方案"
- Troubleshooting steps and pitfalls
- "我们踩过的坑" - lessons learned

**Keywords**: debug, fix, crash, error, issue, problem, solution
**Default**: Most problem-fixing contexts should use this layer

### Tech Layer (技术知识)
**Use when**: Content explains technical implementation details

**Examples**:
- "XCFramework 构建的最佳实践"
- API usage patterns
- Architecture design decisions

**Keywords**: api, architecture, design, pattern, implement, algorithm

---

## Procedure

### Step 1: Verify Prerequisites

Before running the script, ensure:
- User has clear understanding of the problem and solution
- The experience is worth preserving (not trivial)
- You have access to problem description, root cause, and solution

### Step 2: Execute Script

Run the add-context.sh script:

```bash
./Scripts/context/add-context.sh
```

### Step 3: Guide User Through Input

The script will prompt for:

1. **Domain Selection** - Help user choose:
   - `release` - Pod 发布、版本管理、集成问题
   - `ci` - CI/CD 构建、自动化流程
   - `integration` - 集成兼容、编译链接、crash 问题
   - `compatibility` - 版本兼容、迁移升级问题

2. **Layer Classification** - Suggest based on content type (see guide above)

3. **Title** - Help craft a clear, concise title (10+ characters)

4. **Problem Description** - Summarize symptoms and trigger conditions

5. **Root Cause Analysis** - Explain the "why" behind the problem

6. **Solution** - Document the fix or resolution steps

7. **Tags** - Suggest relevant tags based on the conversation

### Step 4: Review and Confirm

- Show the summary to the user
- Confirm all information is accurate
- The script will handle duplicate detection automatically

### Step 5: Verify Creation

After successful creation, the script will:
- Generate a unique context ID (e.g., `ctx-release-001`)
- Create the context file in `.context/{domain}/`
- Update the index.md automatically
- Display the file path

Confirm with user: "上下文已成功创建: {context_id}"

---

## Example Usage

**Scenario**: User solved a complex Pod release issue

**AI Response**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 这个经验可能值得沉淀！

这个问题的解决过程包含了有价值的调试经验和根因分析，建议保存为上下文，
以便下次遇到类似问题时快速引用。

运行 `/context.add` 开始记录，或告诉我"沉淀上下文"。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**User**: "好的，沉淀上下文"

**AI**: Launches the script and guides through input collection...

---

## Best Practices

1. **Be Concise**: Keep titles and descriptions clear and scannable
2. **Focus on Why**: Emphasize root cause over symptoms
3. **Use Tags**: Add relevant technical keywords for searchability
4. **Check Duplicates**: The script will warn if similar entries exist
5. **Layer Defaults**: When in doubt, use "experience" for fix-related contexts

---

## Error Handling

**Common Issues**:

1. **Script not found**
   - Ensure you're in the repository root
   - Check: `ls Scripts/context/add-context.sh`

2. **Duplicate context detected**
   - Review existing entries suggested by the script
   - Consider updating existing entry instead of creating new one

3. **Validation errors**
   - Ensure title is at least 10 characters
   - Ensure all required fields are filled
   - Verify layer is one of: business/experience/tech

---

## Related Skills

- `/context.init` - Initialize context from commit history
- `/context.list` - Search and view existing contexts
- `deep-reviewer.skill.md` - For comprehensive code review (may suggest contexts to create)

---

## Constitutional Compliance

This skill supports:
- **Federal I.1** (Automation First) - Automates knowledge preservation
- **Federal III.1** (Module Cohesion) - Knowledge base is independent module

The context system is designed to make AI responses better over time by building a reusable knowledge base.
