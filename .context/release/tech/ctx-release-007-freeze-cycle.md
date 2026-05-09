---
id: ctx-release-007
title: MSP SDK Release Cycle — Code Freeze 流程
domain: release
layer: tech
tags:
  - freeze
  - unfreeze
  - release-cycle
  - branch-model
  - cherry-pick
  - code-freeze
  - nb-version
  - weekly-release
triggers:
  - "make freeze"
  - "make unfreeze"
  - "freeze/nb-"
  - "code freeze"
  - "release cycle"
  - "weekly release"
  - "cherry-pick to freeze branch"
  - "NB_VERSION freeze"
summary: "Weekly SDK release cadence: Thu freeze, Fri-Mon QA, Tue release + unfreeze. Branch model, cherry-pick flow, NB_VERSION."
status: active
created: 2026-04-30
---

# MSP SDK Release Cycle — Code Freeze 流程

## 节奏（每周循环）

| 时间 | 动作 | 执行者 | 命令 |
|------|------|--------|------|
| 周四 PM | Code Freeze：从 develop 创建 freeze 分支 | SDK | `make freeze NB_VERSION=26.15` |
| 周五—周一 | QA 测试 freeze 分支 | QA | — |
| 周二 | 发版：从 freeze 分支构建并发布 | SDK | Jenkins `releaseCocoapod` |
| 周二（发版后） | Cleanup：合回 develop，**保留分支供后续 diff** | SDK | `make unfreeze NB_VERSION=26.15 KEEP_BRANCH=1` |
| 周二 PM | NB App 集成新 SDK 并发版 | NB team | — |

## Branch 命名规范

- Freeze 分支：`freeze/nb-{NB版本号}`（如 `freeze/nb-26.15`）
- Fix 分支：`fix/{description}`，从 freeze 分支切出
- Feature 分支：`feature/{description}`，从 develop 切出
- **用 NB 版本号**而非 SDK 版本号命名，SDK 版本通过 git tag 体现

## Branch 生命周期

```
make freeze NB_VERSION=26.15
develop ──────────────────────► freeze/nb-26.15
                                      │
                                 Testing (frozen)
                                      │
                               Jenkins release
                                      │
                              make unfreeze NB_VERSION=26.15 KEEP_BRANCH=1
develop ◄──────── merge ──────── freeze/nb-26.15 (kept for reference)
```

## Freeze 期间 PR 路由规则

| 改动类型 | 目标分支 | 需要 cherry-pick | 审批 |
|---------|---------|----------------|------|
| 新功能 | `develop` | 否 | 正常 review |
| Bugfix | `freeze/nb-xx.xx` | **必须** | 正常 review |
| 紧急功能 | `freeze/nb-xx.xx` | **必须** | SDK + QA 双重审批 |
| 跨版本功能（未完成） | `develop`（完成后合入） | 否 | 正常 review |

## Freeze 操作步骤

### 前提条件
- [ ] 所有计划 PR 已合入 develop
- [ ] develop CI 通过
- [ ] 工作区干净，当前在 develop 分支

### 执行
```bash
make freeze NB_VERSION=26.15
# 自动：pull develop → 创建 freeze/nb-26.15 → push remote → 写 state 文件
```

### Freeze 后通知模板
```
SDK Code Freeze (NB 26.15)
- Release branch: freeze/nb-26.15
- Freeze time: 2026-04-xx 21:00
- Planned release: 2026-04-xx (Tuesday)
- Bugfixes → PR to freeze/nb-26.15；new features → continue merging to develop
```

## Bugfix 流程（Freeze 期间）

```bash
# 1. 从 freeze 分支切 fix 分支
git checkout freeze/nb-26.15
git checkout -b fix/crash-on-load

# 2. 修复，创建 PR（base → freeze/nb-26.15）
git add . && git commit -m "fix(core): resolve crash on ad load"
git push -u origin fix/crash-on-load

# 3. PR merge 后，立即 cherry-pick 回 develop
git checkout develop && git pull origin develop
git cherry-pick <commit-hash>
git push origin develop
```

**重要**：每次 fix 合入 freeze 分支后必须**立即** cherry-pick 回 develop，不能等 unfreeze。

## 发版（周二）

### Jenkins 标准路径（推荐）
Jenkins job `releaseCocoapod` 参数：
- `BRANCH`: `freeze/nb-26.15`
- `VERSION`: `3.6.6`
- `RELEASE_NOTES`: 本次发版说明

### 本地紧急发版（Jenkins 不可用时）
```bash
# 1. 先把 freeze 分支合入 develop
git checkout develop && git pull origin develop
git merge freeze/nb-26.15 --no-ff && git push origin develop

# 2. 从 develop 执行本地发版
MSP_ALLOW_LOCAL_RELEASE=1 ./Scripts/msp-release.sh --profile=production run 3.6.6 --force
```

## Cleanup（发版后）

**默认保留 freeze 分支供后续 diff/排查使用**：

```bash
make unfreeze NB_VERSION=26.15 KEEP_BRANCH=1
# 自动：merge freeze 分支 → push develop → 更新 state 文件（保留 remote/local 分支）
```

仅在确实需要清理（例如分支命名错误、误创建）时才删除：

```bash
make unfreeze NB_VERSION=26.15
# 自动：merge freeze 分支 → push develop → 删 remote freeze 分支 → 更新 state 文件
```

### 遇到 merge conflict
```bash
git status
# 手动解决冲突
git add . && git commit && git push origin develop
# 默认保留 freeze 分支，无需额外清理
```

## 跨版本功能

Feature 分支从 develop 切出，完成后合回 develop，自然随下次 freeze 发布，无需特殊处理。

## FAQ

**Q: freeze 脚本说分支已存在？**  
上次 freeze 没有正确清理，手动删除后重新 freeze：
```bash
git branch -d freeze/nb-26.15
git push origin --delete freeze/nb-26.15
make freeze NB_VERSION=26.15
```

**Q: 忘了 cherry-pick 怎么办？**  
`make unfreeze` 会在 merge 时带回，但可能有冲突。应每次 fix 后立即 cherry-pick。

**Q: 发版后发现紧急 bug？**  
跳过 freeze 流程，直接从 develop 或 hotfix 分支通过 Jenkins 发版。
