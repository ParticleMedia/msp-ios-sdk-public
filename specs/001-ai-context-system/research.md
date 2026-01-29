# Research: AI 上下文系统

**Feature**: 001-ai-context-system
**Date**: 2026-01-29
**Status**: Complete

## Research Questions

### RQ-1: 如何从 Commit 历史提取结构化经验？

**Question**: 如何从 git commit 历史中自动提取发布相关的经验教训？

**Research**:
- 分析当前仓库的 commit 历史格式（Conventional Commits）
- 评估 `fix(release)`, `fix(ci)`, `fix(integration)` 等前缀的可提取性
- 研究 commit message 和代码变更的关联性

**Finding**:
1. 当前仓库使用 Conventional Commits 格式，可通过正则匹配提取类型
2. Commit message 通常包含问题描述，但缺少结构化的根因和方案
3. 需要 AI 辅助分析 commit 内容来生成完整的上下文条目

**Decision**: 半自动化提取
- 脚本提取候选 commits（按类型和关键词过滤）
- AI 分析每个 commit 的变更内容，生成结构化上下文
- 用户确认后保存

**Rationale**: 全自动提取无法保证质量，纯手动太耗时。半自动方案平衡了效率和质量。

**Alternatives Rejected**:
- 全自动提取: 无法准确理解根因和方案
- 纯手动整理: 不符合 Article I.1 (Automation First)

---

### RQ-2: 上下文存储格式选择

**Question**: 使用什么格式存储上下文？JSON、YAML、Markdown 还是数据库？

**Research**:
- 分析现有项目的文档格式（主要使用 Markdown）
- 评估各格式的可读性、可搜索性、Git 兼容性
- 考虑 AI agent 的读取能力

**Finding**:
1. 现有文档体系全部使用 Markdown
2. AI agents 对 Markdown 有原生支持（Read tool）
3. Markdown 支持 YAML front matter 存储元数据
4. Git diff 对 Markdown 友好

**Decision**: Markdown + YAML Front Matter

```markdown
---
id: ctx-release-001
domain: release
tags: [pod, xcframework, crash]
created: 2026-01-29
source: commit:abc123
---

# 问题标题

## 问题描述
...

## 根因分析
...

## 解决方案
...

## 适用场景
...
```

**Rationale**: 与现有体系一致，人类和 AI 都易于读写，Git 版本控制友好。

**Alternatives Rejected**:
- JSON: 可读性差，不适合人工编辑
- YAML: 复杂嵌套结构可读性下降
- SQLite: 引入额外依赖，不利于版本控制

---

### RQ-3: 如何实现 AI 自动检测"可沉淀经验"？

**Question**: AI 如何判断某次问题解决值得沉淀？

**Research**:
- 分析什么样的经验具有复用价值
- 研究 Claude/GPT 等 LLM 的"自我反思"能力
- 评估基于规则 vs 基于 AI 判断的方案

**Finding**:
1. 有价值的经验通常包含: 调试过程、根因发现、非直观的解决方案
2. LLM 可以通过 system prompt 引导进行自我评估
3. 规则可以捕捉关键词，但无法判断"价值"
4. 结合规则触发 + AI 判断可以平衡准确性和效率

**Decision**: 规则触发 + AI 确认
- 在 AGENTS.md 添加触发规则（关键词、模式匹配）
- AI 根据规则自动提示，但最终由 AI 生成沉淀建议
- 用户最终确认是否保存

**触发规则示例**:
```markdown
## 上下文沉淀触发条件

当满足以下条件之一时，AI 应主动提示用户考虑沉淀上下文:

1. **调试修复**: 经过 3+ 轮对话才解决的技术问题
2. **根因发现**: 发现了问题的非直观根因
3. **关键词匹配**: 对话涉及 release, crash, compile error, integration 等关键词
4. **模式识别**: "原来是因为...", "问题出在...", "解决方案是..."
```

**Rationale**: 纯规则无法判断价值，纯 AI 判断可能遗漏。结合两者可提高召回率。

**Alternatives Rejected**:
- 纯规则触发: 误报率高，无法判断价值
- 纯 AI 判断: 可能忘记提示，依赖 AI 主动性
- 用户手动触发: 遗漏率高，不符合"自动沉淀"目标

---

### RQ-4: 上下文检索策略

**Question**: 如何实现高效且准确的上下文检索？

**Research**:
- 评估 grep 全文搜索 vs 索引文件 vs 向量嵌入
- 分析 500 条记录规模的性能需求
- 研究现有 AI agent 的检索能力

**Finding**:
1. 500 条记录规模，grep 全文搜索在 <1s 内可完成
2. 索引文件可以加速标签/领域筛选
3. 向量嵌入需要额外服务，复杂度过高
4. AI agents 有 Grep 和 Glob 工具，原生支持文件搜索

**Decision**: 索引文件 + Grep 搜索
- 维护 `index.md` 记录所有条目的 ID、标题、标签、领域
- 按领域快速筛选使用目录结构
- 关键词搜索使用 Grep
- AI 可通过 Grep tool 直接搜索上下文文件

**索引文件格式**:
```markdown
# Context Index

| ID | Title | Domain | Tags | Created |
|----|-------|--------|------|---------|
| ctx-release-001 | Pod 发布后使用方编译失败 | release | pod, compile | 2026-01-29 |
| ctx-ci-001 | CI 构建 XCFramework 路径错误 | ci | xcframework | 2026-01-28 |
```

**Rationale**: 简单高效，无需额外依赖。满足当前规模需求，后续可扩展。

**Alternatives Rejected**:
- 向量嵌入: 复杂度过高，需要额外服务
- 纯 grep 无索引: 无法快速按领域/标签筛选
- 数据库索引: 引入额外依赖

---

### RQ-5: 如何与现有 speckit 工作流集成？

**Question**: context 命令如何与现有的 speckit 工作流协调？

**Research**:
- 分析现有 skill 文件结构
- 研究 speckit 命令的注册机制
- 评估 context 命令的触发时机

**Finding**:
1. Skill 文件是独立的 Markdown，不需要"注册"
2. AI agent 通过 CLAUDE.md 等配置文件知道有哪些 skill
3. Context 命令是独立功能，不依赖 speckit 流程
4. 但可以在 speckit 流程中自动建议沉淀（如 /speckit.implement 完成后）

**Decision**: 独立命令 + 可选集成
- `/context.add`, `/context.list` 作为独立命令
- 在 AGENTS.md 添加建议：speckit.implement 完成后可考虑沉淀
- 不强制绑定，保持灵活性

**Rationale**: 解耦设计，context 系统可独立使用。集成点通过配置而非代码实现。

**Alternatives Rejected**:
- 强绑定 speckit: 降低灵活性，增加复杂度
- 完全独立无集成: 错失自动提示机会

---

## Summary of Decisions

| Topic | Decision | Key Rationale |
|-------|----------|---------------|
| 提取策略 | 半自动化（脚本+AI+确认） | 平衡效率和质量 |
| 存储格式 | Markdown + YAML Front Matter | 与现有体系一致，AI 友好 |
| 触发机制 | 规则触发 + AI 确认 | 提高召回率，减少遗漏 |
| 检索策略 | 索引文件 + Grep | 简单高效，满足规模 |
| 工作流集成 | 独立命令 + 可选建议 | 解耦设计，保持灵活 |

## References

1. 参考文章: https://zhuanlan.zhihu.com/p/1993009461451831150
2. 现有 skill 文件: `.agents-shared/skills/`
3. Constitution: `constitution.md`
4. AGENTS.md: 项目共享上下文
