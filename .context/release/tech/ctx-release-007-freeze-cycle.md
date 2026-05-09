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
summary: "Weekly SDK release cycle: Thu freeze, QA, release on user-specified date, unfreeze. Branch + state JSON + Slack flow."
status: active
created: 2026-04-30
---

# MSP SDK Release Cycle — Code Freeze 流程

## 节奏（每周循环）

| 时间 | 动作 | 执行者 | 命令 |
|------|------|--------|------|
| 周四 PM | Code Freeze：从 develop 创建 freeze 分支 | SDK | `make freeze NB_VERSION=26.15 RELEASE_DATE=2026-05-12` |
| 周五—周一 | QA 测试 freeze 分支 | QA | — |
| 发版日 | 发版：从 freeze 分支构建并发布 | SDK | Jenkins `releaseCocoapod` |
| 发版后 | Cleanup：cherry-pick 检查，**默认保留分支供后续 diff** | SDK | `make unfreeze NB_VERSION=26.15` |
| 发版后 | NB App 集成新 SDK 并发版 | NB team | — |

> **发版日不一定是周二**——历史多数是周二，但实际由 NB App 端决定。每次 freeze 必须显式确认 `RELEASE_DATE`（参见 freeze-cycle.skill.md Step 0）。

## Branch 命名规范

- Freeze 分支：`freeze/nb-{NB版本号}`（如 `freeze/nb-26.15`）
- Fix 分支：`fix/{description}`，从 freeze 分支切出
- Feature 分支：`feature/{description}`，从 develop 切出
- **用 NB 版本号**而非 SDK 版本号命名，SDK 版本通过 git tag 体现

## Branch 生命周期

```
make freeze NB_VERSION=26.15 RELEASE_DATE=2026-05-12
develop ──────────────────────► freeze/nb-26.15
                                      │
                                 Testing (frozen)
                                      │
                               Jenkins release
                                      │
                              make unfreeze NB_VERSION=26.15
develop ──── (cherry-picks) ──── freeze/nb-26.15 (kept, status=closed)
```

## Pre-flight 要求（freeze.sh 强制）

`make freeze` 启动后会做以下检查，**任何一条不通过都直接 abort 并给出 fix 指引**：

| 检查 | 失败处理 |
|------|---------|
| 当前在 `develop` 分支 | abort + 提示 `git checkout develop` |
| 工作区干净（无 staged/unstaged 改动）| abort + 提示 commit 或 stash |
| 本地 `develop == origin/develop`（精确匹配，不能 ahead/behind/diverged）| abort + 根据具体情况给出 `git pull` / 推 PR / 手动 resolve 指引 |
| `freeze/nb-{NB_VERSION}` 不存在 | abort + 提示删除 stale 分支 |
| `RELEASE_DATE` 格式合法（YYYY-MM-DD）且不在过去 | abort + 提示重输 |

**Article 1.4 合规**：脚本不会自动 fix（不会 auto pull、auto stash），所有问题必须先手动修正再重跑。

## State JSON 位置（schema v2）

`.msp-freeze-state.json` **提交在 freeze 分支上**，是该分支的元数据，不在 develop 上。

```json
{
  "schema_version": 2,
  "nb_version": "26.15",
  "freeze_branch": "freeze/nb-26.15",
  "frozen_at": "2026-05-09T08:20:51Z",
  "frozen_by": "Patrick",
  "develop_sha_at_freeze": "ce8addd7...",
  "planned_release_date": "2026-05-12",
  "status": "active"
}
```

- `status`：`active`（freeze 时）→ `closed`（unfreeze 时）
- `develop_sha_at_freeze`：freeze 时刻的 develop HEAD，方便后续做 diff 审计
- `.gitignore` 上仍有 `.msp-freeze-state.json`（防止 develop 上误提交 stale 本地副本）；freeze.sh 在 freeze 分支上用 `git add -f` 强制提交

读取远端 state（不切分支）：
```bash
git show origin/freeze/nb-26.15:.msp-freeze-state.json | jq .
```

## Slack 通知（自动）

freeze.sh 末尾会自动发 Slack 公告到 `MSP_FREEZE_SLACK_WEBHOOK_URL` 配置的 channel。

**配置位置**：`Scripts/config/slack.conf`（gitignore，不会提交）

```bash
MSP_FREEZE_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/REDACTED.../B.../...
MSP_SLACK_HANDLE=Pengyu          # 备用：纯文本署名
MSP_SLACK_USER_ID=U0XXXXXXXXX    # 优先：Slack mention（蓝色可点）
```

未配置 webhook 时，脚本只把 mrkdwn 写到 `.msp-freeze-notice.md`（gitignored，本地存档），需要手动复制到 Slack。

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
- [ ] 工作区干净，本地 develop 与 origin/develop 完全一致

### 执行
```bash
make freeze NB_VERSION=26.15 RELEASE_DATE=2026-05-12
# 自动：
#   1. Pre-flight checks（见上）
#   2. 创建 freeze/nb-26.15
#   3. 在 freeze 分支上写并提交 .msp-freeze-state.json
#   4. push freeze 分支
#   5. 切回 develop
#   6. 生成 .msp-freeze-notice.md（mrkdwn）
#   7. 自动 post 到 Slack（若 webhook 已配）
```

`RELEASE_DATE` 不传时默认下一个周二。

## Bugfix 流程（Freeze 期间）

```bash
# 1. 从 freeze 分支切 fix 分支
git checkout freeze/nb-26.15
git checkout -b fix/crash-on-load

# 2. 修复，创建 PR（base → freeze/nb-26.15）
git add . && git commit -m "fix(core): resolve crash on ad load"
git push -u origin fix/crash-on-load

# 3. fix PR merge 进 freeze 分支后，立即 cherry-pick 回 develop（开 PR）
git checkout develop && git pull origin develop
git checkout -b chore/cherry-pick-<short-hash>
git cherry-pick <commit-hash>
git push -u origin chore/cherry-pick-<short-hash>
gh pr create --base develop --fill
# PR review 后 merge 到 develop
```

**重要**：
- 每次 fix 合入 freeze 分支后必须**立即** cherry-pick 回 develop，不能等 unfreeze（unfreeze 会校验 cherry-pick，未同步会 abort）
- **develop 是受保护分支，不能直接 push**——cherry-pick 也要走 PR
- freeze 分支上的 `chore(freeze):` 元数据 commit（state/notice 文件）unfreeze 会自动忽略，**不需要** cherry-pick 这些

## 发版

### Jenkins 标准路径（推荐）
Jenkins job `releaseCocoapod` 参数：
- `BRANCH`: `freeze/nb-26.15`
- `VERSION`: `3.6.6`
- `RELEASE_NOTES`: 本次发版说明

### 本地紧急发版（Jenkins 不可用时）
```bash
git checkout freeze/nb-26.15 && git pull origin freeze/nb-26.15
MSP_ALLOW_LOCAL_RELEASE=1 ./Scripts/msp-release.sh --profile=production run 3.6.6 --force
```

## Cleanup（发版后）

**默认保留 freeze 分支供后续 diff/排查使用**：

```bash
make unfreeze NB_VERSION=26.15
# 自动：
#   1. 校验所有 freeze 分支 commit 都已 cherry-pick 到 develop（未通过则 abort + 列出未同步的 commit）
#   2. 在 freeze 分支上把 state.status 改为 closed，加 closed_at 时间戳，commit + push
#   3. 远程/本地 freeze 分支保留
```

仅在确实需要清理（例如分支命名错误、误创建）时才删除：

```bash
make unfreeze NB_VERSION=26.15 DELETE_BRANCH=1
# 删除 remote + local freeze 分支
```

> 旧参数 `KEEP_BRANCH=0` / `KEEP_BRANCH=1` 仍兼容，但新代码统一用 `DELETE_BRANCH=1` 表达"显式删除"语义。

### Cherry-pick 校验失败
unfreeze 会列出未 cherry-pick 的真实 fix commit（freeze 元数据 commit 自动忽略）。处理方式：
```bash
git checkout develop && git pull origin develop
git checkout -b chore/cherry-pick-<short-hash>
git cherry-pick <commit-hash>
git push -u origin chore/cherry-pick-<short-hash>
gh pr create --base develop --fill
# PR merge 进 develop 后，重新跑：
make unfreeze NB_VERSION=26.15
```

## 跨版本功能

Feature 分支从 develop 切出，完成后合回 develop，自然随下次 freeze 发布，无需特殊处理。

## FAQ

**Q: freeze 脚本说"local develop is BEHIND origin/develop"？**
本地落后远端，需要先 pull：
```bash
git pull origin develop
make freeze NB_VERSION=...
```

**Q: freeze 脚本说"local develop is AHEAD of origin/develop"？**
本地有未推的 commit。**不要直接 push develop**（受保护分支），先开 PR 合入再重跑 freeze。

**Q: freeze 脚本说"local develop has DIVERGED from origin/develop"？**
本地和远端各自有不同 commit。手动 reset 或 merge 后重跑。建议：
```bash
git fetch origin develop
git reset --hard origin/develop  # 谨慎：会丢本地未推 commit
```

**Q: freeze 脚本说分支已存在？**
上次 freeze 没有正确清理。如果是误建分支：
```bash
git branch -D freeze/nb-26.15 2>/dev/null || true
git push origin --delete freeze/nb-26.15
make freeze NB_VERSION=26.15
```

**Q: 忘了 cherry-pick 怎么办？**
unfreeze 会 abort 并列出未同步的 commit，按提示 cherry-pick 后重跑。

**Q: 发版后发现紧急 bug？**
跳过 freeze 流程，直接从 develop 或 hotfix 分支通过 Jenkins 发版。

**Q: 怎么查看历史 freeze 的元数据？**
```bash
git show origin/freeze/nb-26.15:.msp-freeze-state.json | jq .
```

**Q: Slack 通知没发出去？**
检查 `Scripts/config/slack.conf` 的 `MSP_FREEZE_SLACK_WEBHOOK_URL` 是否配置。脚本会把 mrkdwn 写到 `.msp-freeze-notice.md`，可以手动复制粘贴。
