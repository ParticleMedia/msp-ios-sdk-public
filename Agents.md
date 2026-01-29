# AI Agent Shared Context

> **Version**: 3.0
> **Last Updated**: 2026-01-20
> **Applies To**: All AI Agents

## 1. Project Technical Context

**Language**: Swift 5.0
**Target**: iOS 15.0+
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1

**Note**: For domain-specific development guidelines:
- Swift/Sources development: See `Sources/AGENTS-SOURCES.md`
- Scripts development: See `Scripts/AGENTS-SCRIPTS.md`

### Active Technologies

- Markdown configuration files (no code compilation) + N/A (documentation/configuration refactoring) (ai-infra-refactor)
- Bash (POSIX-compliant), Markdown + speckit workflow scripts, git (ai-infra-reorg)
- Swift 5.0, iOS 15.0+ + Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1 (unit-test-setup)

### Recent Changes

- ai-infra-reorg: Added Bash (POSIX-compliant), Markdown + speckit workflow scripts, git
- ai-infra-refactor: Added Markdown configuration files (no code compilation) + N/A (documentation/configuration refactoring)
- unit-test-setup: Added Swift 5.0, iOS 15.0+ + Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1

## 2. Pre-Task Checklist

- [ ] Clean working directory (`git status`)
- [ ] On correct branch
- [ ] In development mode (`./Scripts/switch-target.sh pods-dev`)

## 3. Shared Resources

### Skills
Location: `.agents-shared/skills/`
All agents can use all skills.

### Protocols
Location: `.agents-shared/protocols/`
- task-tier.protocol.md - Task classification guide
- output-format.protocol.md - Standardized output format

### Tools
- Scripts/tools/ - Automation scripts
- Sources/tools/ - Swift development tools
- Tests/templates/ - Test templates

## 4. Basic Workflow

### Branching
- feature/, fix/, chore/ prefixes
- Conventional Commits v1.0.0

### Commit Format
<type>(<scope>): <subject>

### Project Configuration Workflow

When modifying Xcode project structure (enforced by Federal Constitution Article I.2 and Sources Constitution Article IV.6):

**Step-by-Step Process**:
1. **Identify relevant template**: Find the appropriate `*.yml.template` file (e.g., `project.yml.template`, `*.podspec.template`)
2. **Make changes to YAML template**: Edit the template file with your project structure changes
3. **Run XcodeGen**: Execute `xcodegen generate` to regenerate `.xcodeproj`
4. **Verify changes**: Open the `.xcodeproj` in Xcode and verify the changes are correct
5. **Commit template only**: Commit only the `*.yml.template` changes (NOT the `.xcodeproj` files)

**Common Scenarios**:
- **Add new target**: Edit `project.yml.template` targets section
- **Add source files**: XcodeGen auto-discovers files by convention (no manual action needed)
- **Change build settings**: Edit the settings section in the appropriate template
- **Add dependencies**: Update `Podfile` (the Single Source of Truth for dependencies)

**Troubleshooting**:
- **XcodeGen fails**: Check YAML syntax with `yamllint project.yml.template`
- **Project missing files**: Verify glob patterns in template match your file structure
- **Build fails after regeneration**: Run `./Scripts/target-switching/round-trip-test.sh` to validate

## 5. Read-Only Zones

These files require human approval to modify:
- constitution.md (all versions)
- ARCHITECTURE.md
- README.md

## 6. Reference Documents

- constitution.md - Supreme law
- .claude/CLAUDE.md - Claude-specific rules
- .codex/CODEX.md - Codex-specific rules
- .cursor/CURSOR.md - Cursor-specific rules

## Active Technologies
- Swift 5.0 + CocoaPods, Quick, Nimble, OHHTTPStubs, XcodeGen (fix-unit-tests)
- Swift 5.0 + Quick ~> 7.0, Nimble ~> 13.0, Combine (debug-viewmodel-tests)
- N/A (unit tests only) (debug-viewmodel-tests)
- Bash (POSIX-compliant), Markdown + Git (commit 历史分析), Grep/Sed (文本处理) (001-ai-context-system)
- Markdown 文件 (`.context/` 目录) (001-ai-context-system)

## Recent Changes
- fix-unit-tests: Added Swift 5.0 + CocoaPods, Quick, Nimble, OHHTTPStubs, XcodeGen

## 7. Context System Rules

The project maintains a knowledge base in `.context/` to preserve development experience and enable knowledge reuse. AI agents should actively participate in both consuming and contributing to this system.

### 7.1 Automatic Context Loading

When user questions involve the following keywords, AI should **automatically search and reference** relevant context:

**How to Load Context**:
1. Identify domain from user question keywords (see mapping table below)
2. Use `Scripts/context/search-context.sh` to search for relevant entries:
   ```bash
   ./Scripts/context/search-context.sh <keywords>
   ```
3. Alternative: Search `.context/{domain}/` directly using Grep tool
4. Reference found context in your response: "根据 [ctx-xxx] 的经验..." or "Based on context [ctx-xxx]..."
5. Cite the context ID and key insights from the context entry

**Using search-context.sh**:
```bash
# Basic search
./Scripts/context/search-context.sh pod release

# Search in specific domain
./Scripts/context/search-context.sh --domain release crash

# Search in specific layer
./Scripts/context/search-context.sh --layer experience build fail

# Get only context IDs
./Scripts/context/search-context.sh --format ids pod
```

The script will:
- Automatically map keywords to relevant domains
- Search context files with case-insensitive matching
- Sort results by relevance (match count)
- Return top 5 results by default

**Keyword-to-Domain Mapping**:

| Keywords | Domain | Example Usage |
|----------|--------|---------------|
| release, pod, podspec, xcframework, 发布, 版本, publish, trunk | `release` | "发布 pod 后使用方编译失败" → Search `.context/release/` |
| ci, cd, build, 构建, github actions, workflow | `ci` | "GitHub Actions 构建失败" → Search `.context/ci/` |
| integration, 集成, crash, 编译, compile, linker, link | `integration` | "集成后 crash" → Search `.context/integration/` |
| compatibility, 兼容, migration, 升级, deprecate | `compatibility` | "版本升级后兼容性问题" → Search `.context/compatibility/` |

**Search Strategy**:
- Use Grep tool with `-i` (case insensitive) and `output_mode: "files_with_matches"` to find relevant context files
- Read the top 2-3 most relevant context files
- Extract key insights from "根因分析" and "解决方案" sections
- Present findings concisely in your response

**Example**:
```
User: "pod 发布后使用方编译失败，出现 duplicate symbol 错误"

AI Response:
根据 [ctx-release-001] 的经验，这种问题通常是由于第三方 SDK 被静态链接了两次导致的。

解决方案：
1. 检查 podspec 是否使用了 vendored_frameworks
2. 创建 shim framework 避免直接链接静态库
3. 确保 SDK 只在使用方项目中链接一次

[继续提供具体指导...]
```

### 7.2 Context Precipitation Prompts

When the following conditions are met, AI should **proactively suggest** saving the experience as context:

**Trigger Conditions** (ALL must be satisfied):

1. **Debugging Completed** (调试完成)
   - The conversation involved 3+ rounds of back-and-forth to solve a technical problem
   - A solution was successfully found and verified

2. **Root Cause Discovered** (根因发现)
   - The conversation contains phrases indicating insight:
     - "原来是因为...", "问题出在...", "根本原因是..."
     - "the root cause is...", "the issue was...", "turns out..."
   - The problem required investigation beyond surface symptoms

3. **Domain Match** (领域匹配)
   - The problem falls into one of the supported domains:
     - `release` - Pod 发布、版本管理、集成问题
     - `ci` - CI/CD 构建、自动化流程
     - `integration` - 集成兼容、编译链接、crash
     - `compatibility` - 版本兼容、迁移升级

4. **Non-Duplicate** (非重复)
   - Search existing context in the relevant domain
   - Verify no highly similar entry exists
   - If similar context exists, suggest updating it instead

**When NOT to Suggest**:
- Simple questions answered in 1-2 rounds
- Trivial fixes (typos, formatting, minor config changes)
- Well-documented issues already in context
- User explicitly declined precipitation before

**Prompt Template**:

When all conditions are met, append this message to your response:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 这个经验可能值得沉淀！

这个问题的解决过程包含了有价值的调试经验和根因分析，建议保存为上下文，
以便下次遇到类似问题时快速引用。

运行 `/context.add` 开始记录，或告诉我"沉淀上下文"。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Layer Classification Guidance**:

When helping users create context, suggest the appropriate layer:

- **business** (业务知识): Product requirements, business rules, user scenarios
  - Example: "为什么要在发布前进行特定的验证流程"

- **experience** (经验教训): Debugging process, pitfalls, solutions
  - Example: "发布后 crash 的调试过程和解决方案"
  - **Default for most fix-related contexts**

- **tech** (技术知识): API usage, architecture design, design patterns
  - Example: "XCFramework 构建的最佳实践"

### 7.3 Context Management Commands

Users can interact with the context system through these commands:

- `/context.add` - Manually add a new context entry (implemented in Phase 5)
- `/context.list` - List and search existing context (implemented in Phase 7)
- `/context.init` - Initialize context from commit history (available now)

**Note**: Context system is under active development. Not all commands may be available yet.
