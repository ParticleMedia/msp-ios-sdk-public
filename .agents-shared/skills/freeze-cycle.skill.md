---
name: freeze-cycle
description: Execute the weekly SDK code freeze or unfreeze workflow — creates/closes freeze/nb-* branch, commits state JSON on the freeze branch, posts a Slack announcement, and validates cherry-picks
category: release
shared: true
applicable_agents: [claude-code, codex, cursor]
allowed-tools: [Bash, Read]
quick_reference: "When: freeze before QA window / unfreeze post-release. Run: make freeze NB_VERSION=xx.xx RELEASE_DATE=YYYY-MM-DD / make unfreeze NB_VERSION=xx.xx (default keeps branch). ALWAYS confirm NB_VERSION + RELEASE_DATE with user before executing."
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

- **Cadence**: 周四 PM freeze → 周五–周一 QA → 发版日（**通常**周二，但每次以用户指定的 `RELEASE_DATE` 为准）→ unfreeze
- **Branch naming**: `freeze/nb-{NB_VERSION}` (NB 版本，不是 SDK 版本)
- **State JSON**: 提交在 freeze 分支上（schema v2，含 `develop_sha_at_freeze` / `planned_release_date` / `status`）
- **Bugfix rule**: PR → `freeze/nb-*`，merge 后**立即** cherry-pick 回 develop
- **Release**: Jenkins `releaseCocoapod` job，BRANCH=`freeze/nb-*`
- **Slack**: freeze 自动 post 到 `MSP_FREEZE_SLACK_WEBHOOK_URL`（配在 `Scripts/config/slack.conf`，gitignored）

---

## Freeze Steps

### Step 0 — **MANDATORY** confirmation with user (do NOT skip)

Before invoking `make freeze`, you **MUST** confirm BOTH inputs with the user
even if they were stated earlier in the session. Skipping this step has burned
us before — release dates change and stale assumptions ship to Slack.

Ask the user:

1. `NB_VERSION` — NB App 版本号（如 `26.19.0`）
2. `RELEASE_DATE` — 计划发版日期，YYYY-MM-DD 格式
   - 默认建议下一个周二，但**仍要问一次**——发版日不一定是周二
   - 如果用户指定的日期是周末或当天，警告但不阻塞

Then echo back the plan and wait for explicit confirmation:

```
即将 freeze:
  NB Version:        26.19.0
  Release Branch:    freeze/nb-26.19.0
  Frozen at:         2026-05-09 (today)
  Planned Release:   2026-05-12 (Tuesday)
  Slack Channel:     auto-post via webhook
继续？(y/n)
```

If user is running `make freeze` directly from CLI (rare), the script accepts
defaults — but Claude must always confirm.

### Step 1 — Pre-flight check (script does this automatically)

The script aborts with explicit guidance if any check fails (Article 1.4: no auto-fix):
- Currently on `develop`
- Working tree clean
- `develop` exactly matches `origin/develop` (not behind / ahead / diverged)
- `freeze/nb-{NB_VERSION}` does not already exist
- `RELEASE_DATE` is YYYY-MM-DD and not in the past

### Step 2 — Execute

```bash
make freeze NB_VERSION=26.19.0 RELEASE_DATE=2026-05-12
```

Script automatically:
- Creates `freeze/nb-26.19.0` from develop
- Writes + commits `.msp-freeze-state.json` (schema v2) **on the freeze branch**
- Pushes the freeze branch
- Switches back to develop (state file disappears from working tree)
- Generates Slack mrkdwn → writes to `.msp-freeze-notice.md` (gitignored archive)
- Posts to Slack via `MSP_FREEZE_SLACK_WEBHOOK_URL` (if configured)

### Step 3 — Verify result

- Check `make freeze` exit code = 0
- Confirm Slack post landed (script reports `Slack announcement posted.` on success)
- If webhook missing or post failed, copy `.msp-freeze-notice.md` to Slack manually

---

## Unfreeze Steps

### Step 0 — Confirm with user

Ask the user:
1. `NB_VERSION` — must match the freeze
2. Whether to delete the branch: **default = retain** for future diff/audit. Only set `DELETE_BRANCH=1` if user explicitly asks to clean up.

### Step 1 — Pre-flight (script does this)

- Working tree clean
- Remote `freeze/nb-{NB_VERSION}` exists
- All freeze-branch commits are cherry-picked to `develop` (`git cherry` check)

### Step 2 — Execute

```bash
# Default (retain branch + mark state as closed)
make unfreeze NB_VERSION=26.19.0

# Explicit deletion (rare — only when user asks to clean up)
make unfreeze NB_VERSION=26.19.0 DELETE_BRANCH=1
```

Script automatically:
- Aborts with list if any commits on freeze branch are not in develop
- Updates state JSON: `status: "closed"` + `closed_at` timestamp; commits and pushes to freeze branch
- Retains the branch by default; deletes only when `DELETE_BRANCH=1`

> Legacy `KEEP_BRANCH=0/1` args are still accepted (backwards compat); new code/docs use `DELETE_BRANCH=1` for clarity.

### Step 3 — If unfreeze aborts on missing cherry-picks

develop is branch-protected — cherry-picks must go through a PR:

```bash
git checkout develop && git pull origin develop
git checkout -b chore/cherry-pick-<short-hash>
git cherry-pick <commit-hash>
git push -u origin chore/cherry-pick-<short-hash>
gh pr create --base develop --fill
# After PR merges:
make unfreeze NB_VERSION=26.19.0
```

> Freeze metadata commits (`chore(freeze): record freeze state ...` / `chore(freeze): close ...`) are auto-ignored by the cherry-pick check — they live only on the freeze branch by design and are never expected on develop.

---

## Error Reference

| Error | Cause | Fix |
|-------|-------|-----|
| Not inside a git repository | Wrong cwd | `cd` to msp-ios-sdk checkout |
| NB_VERSION contains invalid characters | Slashes, spaces, leading `.`/`-` | Use semver format (e.g., `26.18.0`) |
| Working tree not clean | Uncommitted changes | Commit or `git stash` |
| Not on develop | Wrong branch | `git checkout develop` |
| Local develop is BEHIND origin/develop | Need fresh remote | `git pull origin develop` |
| Local develop is AHEAD of origin/develop | Unmerged local commits | Open PR to develop, merge, then re-run |
| Local develop has DIVERGED | History mismatch | Manual resolve or `git reset --hard origin/develop` (careful) |
| Branch already exists | Stale freeze branch with same NB_VERSION | Delete it: `git push origin --delete freeze/nb-XX.YY` |
| RELEASE_DATE invalid format | Not YYYY-MM-DD | Re-input in correct format |
| RELEASE_DATE in the past | Date typo | Pick today or future |
| Un-cherry-picked commits | Bugfix not synced | Cherry-pick listed commits to develop, push via PR, re-run |
| Local freeze branch ahead with non-metadata commits | Un-pushed local fix | Push to freeze branch via PR (or revert) before re-running |

---

## Slack Configuration

Webhook + handle live in `Scripts/config/slack.conf` (gitignored):

```bash
MSP_FREEZE_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
MSP_SLACK_USER_ID=U0XXXXXXXXX     # optional: <@USER_ID> mention in notice
MSP_SLACK_HANDLE=Pengyu           # fallback: plain-text name
```

If webhook is unset, freeze.sh writes the mrkdwn to `.msp-freeze-notice.md` and warns
that the user must copy/paste manually.

---

## Related

- `ctx-release-007` — Full release cycle documentation
- `make freeze` / `make unfreeze` — Makefile targets
- `Scripts/freeze.sh` / `Scripts/unfreeze.sh` — implementations
- Jenkins `releaseCocoapod` — Production release job (BRANCH=`freeze/nb-*`)
