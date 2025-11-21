# Multi-Module XcodeGen Migration Workflow

## Report Files Policy

**CRITICAL:** Report files MUST NOT be committed to the repository.

### Report Files That Must NOT Be Committed

- `*_Migration_Summary.md`
- `*_Project_Fix_Summary.md`
- `*_Validation_Checklist.md`
- `*_Migration_Report.md`
- `*_Fix_Report.md`
- `*.log`
- `*.tmp`
- `BuildReports/`
- `MigrationReports/`
- `Tmp/`

### Pre-Commit Cleanup

Before committing migration changes, always run:

```bash
./Scripts/tools/pre-commit-cleanup.sh
```

Or manually:

```bash
git reset -- '*_Migration_Summary.md'
git reset -- '*_Project_Fix_Summary.md'
git reset -- '*_Validation_Checklist.md'
git reset -- '*.log'
git reset -- '*.tmp'
```

### Files That SHOULD Be Committed

- `{Module}/project.yml` - XcodeGen specifications
- `Scripts/**/*.sh` - Updated build/workspace scripts
- `Podfile` - Podfile updates (if needed)
- `.gitignore` - Updated ignore rules

### Report File Storage

Report files can be:
1. Saved temporarily in `MigrationReports/` (gitignored)
2. Displayed in terminal output only
3. Saved to user's local directory outside repo

## Migration Stages

### Stage A — Analyze & Plan
- Analyze existing .xcodeproj
- Extract build settings, sources, resources
- Generate analysis report (NOT committed)

### Stage B — Generate project.yml
- Create XcodeGen specification
- Validate with `xcodegen generate`
- Generate validation report (NOT committed)

### Stage C — Workspace Integration
- Update `generate_workspace.sh`
- Update `switch-target.sh` if needed
- No reports needed

### Stage D — Script Adjustments
- Update build scripts
- Add XcodeGen generation steps
- No reports needed

### Stage E — Validation
- Run Pods mode validation
- Run SPM mode validation
- Run XCFramework build
- Generate validation checklist (NOT committed)

### Stage F — Commit
- Run pre-commit cleanup
- Commit only code changes
- Never commit reports

## Example Migration Workflow

```bash
# 1. Analyze module
./analyze-module.sh MSPOMSDK > MigrationReports/MSPOMSDK_analysis.txt

# 2. Generate project.yml
# (creates MSPOMSDK/project.yml)

# 3. Update scripts
# (modifies generate_workspace.sh, build scripts)

# 4. Validate
./validate-module.sh MSPOMSDK > MigrationReports/MSPOMSDK_validation.log

# 5. Pre-commit cleanup
./Scripts/tools/pre-commit-cleanup.sh

# 6. Commit
git add MSPOMSDK/project.yml Scripts/**/*.sh
git commit -m "MSPOMSDK Migration to XcodeGen"
```

## Automated Cleanup

The pre-commit cleanup script automatically removes:
- All `*_Summary.md` files
- All `*_Report.md` files
- All `*.log` files
- All `*.tmp` files
- Report directories

This ensures clean git history with only code changes.
