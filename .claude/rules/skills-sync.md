# Skills Sync Rule

When creating or modifying skill files in `.claude/skills/`:
1. Apply the same change to `.agents-shared/skills/` (the shared source for Codex/Cursor)
2. Both copies must stay identical — `.claude/skills/` is NOT a fork, it is a mirror

When creating or modifying skill files in `.agents-shared/skills/`:
1. Apply the same change to `.claude/skills/`

Order: write the primary change first, then sync the copy.
