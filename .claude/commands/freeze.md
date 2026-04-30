---
description: Execute weekly SDK code freeze — creates freeze/nb-{NB_VERSION} branch from develop and prints team notification template
uses-skill: freeze-cycle
---

## User Input

```text
$ARGUMENTS
```

## Task: SDK Code Freeze

Execute the weekly code freeze. If `$ARGUMENTS` contains a version (e.g. `26.18.0`), use it as `NB_VERSION`. Otherwise ask the user.

## Steps

1. **Parse NB_VERSION** from `$ARGUMENTS`. If missing, ask: "这次 freeze 的 NB 版本号是？"

2. **Check prerequisites**:
   ```bash
   git status
   git rev-parse --abbrev-ref HEAD
   ```
   Fail fast if working tree is dirty or not on `develop`.

3. **Run freeze**:
   ```bash
   make freeze NB_VERSION=<NB_VERSION>
   ```

4. **Report result** — show the printed notification template and remind user to send it to the team Slack channel.
