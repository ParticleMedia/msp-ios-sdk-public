---
description: Post-release SDK unfreeze — validates all cherry-picks are done, then deletes freeze/nb-{NB_VERSION} branch
uses-skill: freeze-cycle
---

## User Input

```text
$ARGUMENTS
```

## Task: SDK Unfreeze

Execute post-release cleanup. If `$ARGUMENTS` contains a version (e.g. `26.18.0`), use it as `NB_VERSION`. Otherwise read from `.msp-freeze-state.json` or ask the user.

## Steps

1. **Parse NB_VERSION** from `$ARGUMENTS`. If missing, check `.msp-freeze-state.json`. If still missing, ask: "要 unfreeze 的 NB 版本号是？"

2. **Check KEEP_BRANCH** — if `$ARGUMENTS` contains `keep` or `KEEP_BRANCH=1`, pass `KEEP_BRANCH=1`.

3. **Run unfreeze**:
   ```bash
   make unfreeze NB_VERSION=<NB_VERSION>
   # or with KEEP_BRANCH:
   make unfreeze NB_VERSION=<NB_VERSION> KEEP_BRANCH=1
   ```

4. **If aborted due to missing cherry-picks** — show the listed commits and guide user:
   ```bash
   git checkout develop && git pull origin develop
   git cherry-pick <hash>
   git push origin develop
   # then re-run /unfreeze
   ```

5. **On success** — confirm freeze branch is deleted and remind: next freeze is next Thursday.
