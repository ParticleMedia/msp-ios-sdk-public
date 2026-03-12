---
name: context-init
description: Initialize context system by extracting experience from git commit history
category: knowledge-management
quick_reference: "When: Bootstrapping context system for first time. Run: ./Scripts/context/init-context.sh — scans git history for debugging patterns and generates initial context entries."
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Bash, Read]
---

# Context Init Skill

> **Type**: Knowledge Management Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Bootstrap the context knowledge base from existing commit history

---

## Purpose

Extract and preserve valuable debugging experience from git commit history by:
- Scanning for problem-solving commits (fix/resolve patterns)
- Filtering for substantial changes (not trivial fixes)
- Guiding interactive review and classification
- Creating structured context entries automatically

**Task Tier**: Tier 2 (Complex - requires user interaction)

---

## Scope

**Does**:
- Extract commits matching `fix(domain):` pattern from git history
- Filter out trivial changes (typos, formatting)
- Present commits interactively for user review
- Guide layer classification (business/experience/tech)
- Generate context files from commit information
- Update context index automatically

**Does NOT**:
- Modify or delete existing contexts
- Work without user interaction (all contexts require confirmation)
- Extract from non-fix commits (features, chores, etc.)

---

## When to Use

**Primary Scenarios**:
1. First-time context system setup (bootstrap knowledge base)
2. Periodic extraction of recent problem-solving work
3. After completing a major debugging effort
4. When onboarding new team members (capture historical knowledge)

**Trigger Phrases**:
- "初始化上下文" / "initialize context"
- "从历史提取经验" / "extract experience from history"
- "/context.init"
- "build context from commits"

**Quick Decision**:
- Need to bootstrap knowledge base → Use this skill
- Have specific knowledge to add → Use `/context.add` instead
- Want to browse existing contexts → Use `/context.list` instead

---

## Prerequisites

Before running the script:
1. Working git repository with commit history
2. Commits following Conventional Commits format (`fix(domain): message`)
3. User available for interactive review (non-automated)
4. Clear understanding of layer classification concepts

---

## Procedure

### Step 1: Determine Scope

Ask the user:
- Which domain to focus on? (default: all)
- How many commits to review? (default: 20)

**Command Options**:
```bash
# Extract from all domains (default)
./Scripts/context/init-context.sh

# Focus on specific domain
./Scripts/context/init-context.sh --domain release

# Increase commit limit
./Scripts/context/init-context.sh --limit 50

# Combine options
./Scripts/context/init-context.sh --domain ci --limit 30
```

### Step 2: Execute Script

Run the initialization:
```bash
./Scripts/context/init-context.sh [OPTIONS]
```

The script will:
1. Scan git history for `fix(domain):` commits
2. Filter out trivial changes (typos, formatting)
3. Present each commit for review

### Step 3: Guide Interactive Review

For each commit, the script shows:
- Commit hash and subject
- Commit body (if any)
- Files changed

**User Actions**:
- **y**: Create context from this commit
- **n**: Skip this commit
- **q**: Quit the process

### Step 4: Assist with Layer Classification

When user confirms a commit, help classify the layer:

**Layer Selection**:
- **b** (business): Product requirements, business rules
- **e** (experience): Debugging process, troubleshooting (DEFAULT)
- **t** (tech): Technical implementation, API usage

**Auto-suggestion Logic**:
The script suggests layer based on keywords:
- "product", "requirement" → business
- "debug", "fix", "crash" → experience (most common)
- "api", "architecture", "design" → tech

**AI Guidance**:
```
If commit mentions debugging/troubleshooting → Recommend "experience"
If commit documents API usage/patterns → Recommend "tech"
If commit explains business logic/rules → Recommend "business"
```

### Step 5: Verify Creation

After each context is created:
- Confirm the context file was generated
- Note the context ID (e.g., ctx-release-001)
- Index is automatically updated

### Step 6: Review Results

At the end:
- Show total contexts created
- Suggest running `/context.list` to view results
- Recommend rebuilding index if needed

---

## Example Session

**Scenario**: Initialize release contexts from last 10 commits

**Command**:
```bash
./Scripts/context/init-context.sh --domain release --limit 10
```

**Output Flow**:
```
🔍 Scanning commit history for release-related fixes...
Domain filter: release
Limit: 10

📝 Found 8 commit(s) matching pattern
🔎 Filtering for substantial problem-solving commits...
✅ 5 candidate commit(s) after filtering

Sample candidates:
  - ea820b5a: fix(release): Pod 发布后使用方编译失败...
  - fb123456: fix(release): xcframework 打包错误...

🎯 Starting interactive review...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Commit: ea820b5a
📝 Subject: fix(release): Pod 发布后使用方编译失败

Details:
  发布后使用方集成时出现 duplicate symbol 错误

🔗 Files changed:
  Sources/Adapters/FacebookAdapter/FacebookAdapter.swift
  MSPFacebookAdapter.podspec
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Create context for this commit? [y/n/q]: y

🏷️  Please classify this context into a layer:

  [b] business    - 业务知识
  [e] experience  - 经验教训
  [t] tech        - 技术知识

💡 Suggested: experience

Select layer [b/e/t] (default: e): <Enter>

✅ Creating context...
   Domain: release
   Layer: experience
   Commit: ea820b5a

✅ Created: .context/release/ctx-release-001.md
📇 Updating index...

[... continues for other commits ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ Initialization complete!
   Created: 3 context(s)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**AI Response**:
"成功从提交历史中提取了 3 个上下文！现在可以通过 `/context.list` 查看，或在遇到类似问题时自动加载这些经验。"

---

## Best Practices

1. **Start Small**: Use `--limit 10` on first run to test the process
2. **Focus Domains**: Use `--domain` to focus on one area at a time
3. **Default to Experience**: Most fix commits should be classified as "experience"
4. **Review Carefully**: Skip commits with incomplete information
5. **Batch Processing**: Process commits in batches (10-20 at a time)

---

## Edge Cases

### No Commits Found

**Cause**: No commits match `fix(domain):` pattern

**Action**:
- Verify commits follow Conventional Commits format
- Check if the domain exists (release/ci/integration/compatibility)
- Try without `--domain` filter
- Consider using `/context.add` for manual entry

### All Commits Filtered Out

**Cause**: All commits appear trivial (typos, formatting)

**Action**:
- Increase `--limit` to get more candidates
- Review filter logic if necessary
- Manually add important contexts with `/context.add`

### Commit Body Empty

**Cause**: Commit has no detailed description

**Action**:
- User can still create context
- Problem description will be minimal
- Suggest editing the context file later to add details

---

## Post-Initialization

After running init-context.sh:

1. **Verify Results**:
   ```bash
   ./Scripts/context/list-context.sh
   ```

2. **Edit if Needed**:
   - Context files are in `.context/{domain}/`
   - Can manually edit to improve descriptions
   - Files are Markdown - easy to modify

3. **Rebuild Index**:
   ```bash
   ./Scripts/context/list-context.sh --rebuild
   ```

4. **Test Search**:
   ```bash
   ./Scripts/context/search-context.sh <keywords>
   ```

---

## Related Skills

- `/context.add` - Manually add context entries
- `/context.list` - View and manage contexts
- `search-context.sh` - Search for relevant contexts

---

## Constitutional Compliance

This skill supports:
- **Federal I.1** (Automation First) - Automates knowledge extraction
- **Federal II.1** (Validation Loop) - Interactive validation before creation

The init process ensures quality by requiring user confirmation for each context, preventing automatic bulk creation of low-quality entries.
