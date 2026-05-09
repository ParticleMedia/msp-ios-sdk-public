---
name: freeze-cycle
description: Execute the weekly SDK code freeze or unfreeze workflow — creates/deletes freeze/nb-* branch, validates cherry-picks, and prints team notification template
category: release
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Bash, Read]
quick_reference: "When: Thursday PM (freeze) or Tuesday post-release (unfreeze). Run: make freeze NB_VERSION=xx.xx / make unfreeze NB_VERSION=xx.xx KEEP_BRANCH=1 (default keeps branch for diff)"
---

# Freeze Cycle Skill

> **Type**: Release Skill
> **Shared**: Yes (All agents can use)
> **Purpose**: Execute the weekly code freeze / unfreeze in one command

---

## When to Use

**Freeze** — when user says any of:
- "做 freeze"、"code freeze"、"freeze 一下"
- "今天要 freeze 了"、"开始 freeze"
- "create freeze branch"

**Unfreeze** — when user says any of:
- "unfreeze"、"发版完了 unfreeze"
- "删 freeze 分支"、"merge 回 develop"
- "发版结束了"

---

## Context (load ctx-release-007 for full detail)

- **Cadence**: 周四 PM freeze → 周五-周一 QA → 周二发版 → 周二 unfreeze
- **Branch naming**: `freeze/nb-{NB_VERSION}` (NB 版本，不是 SDK 版本)
- **Bugfix rule**: PR → `freeze/nb-*`，merge 后**立即** cherry-pick 回 develop
- **Release**: Jenkins `releaseCocoapod` job，BRANCH=`freeze/nb-*`

---

## Freeze Steps

### 1. Confirm inputs

Ask if not provided:
- `NB_VERSION` — NB App 版本号（如 `26.18.0`）

### 2. Check prerequisites

```bash
git status                        # 工作区必须干净
git rev-parse --abbrev-ref HEAD   # 必须在 develop
```

### 3. Execute

```bash
make freeze NB_VERSION=26.18.0
```

Script automatically:
- `git pull origin develop`
- Creates and pushes `freeze/nb-26.18.0`
- Switches back to `develop`
- Writes `.msp-freeze-state.json`
- Prints team notification template

### 4. Notify team

Copy the printed notification template and send to team Slack channel.

---

## Unfreeze Steps

### 1. Confirm inputs

- `NB_VERSION` — same version used at freeze time
- `KEEP_BRANCH` — **default `1`** (保留分支供后续 diff)，仅在需要清理误建分支时省略

### 2. Check prerequisites

```bash
git status   # 工作区必须干净
```

### 3. Execute

```bash
# 默认（保留分支供后续 diff）
make unfreeze NB_VERSION=26.18.0 KEEP_BRANCH=1

# 仅在确需清理时使用
make unfreeze NB_VERSION=26.18.0
```

Script automatically:
- `git fetch origin`
- Runs `git cherry` to detect un-cherry-picked commits
- **If missing commits**: aborts with list of commits to cherry-pick
- **If all synced**: merges back to develop; deletes branch only when `KEEP_BRANCH` is unset
- Removes `.msp-freeze-state.json`

### 4. If unfreeze aborts (missing cherry-picks)

```bash
git checkout develop && git pull origin develop
git cherry-pick <commit-hash>
git push origin develop
# Then re-run make unfreeze NB_VERSION=26.18.0
```

---

## Error Reference

| Error | Cause | Fix |
|-------|-------|-----|
| Working tree not clean | Uncommitted changes | `git stash` or commit first |
| Not on develop | Wrong branch | `git checkout develop` |
| Branch already exists | Previous freeze not cleaned up | `git branch -d freeze/nb-*` + `git push origin --delete freeze/nb-*` |
| Active freeze state exists | Previous freeze not unfrozen | `make unfreeze NB_VERSION=<old-version>` first |
| Un-cherry-picked commits | Bugfix not synced | Cherry-pick listed commits to develop |

---

## Related

- `ctx-release-007` — Full release cycle documentation
- `make freeze` / `make unfreeze` — Makefile targets
- Jenkins `releaseCocoapod` — Production release job (BRANCH=`freeze/nb-*`)
