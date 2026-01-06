# Changelog

All notable changes to the MSP iOS SDK release system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase B: Release System Simplification

#### Breaking Changes
- **Removed `MSP_RELEASE_TIER`**: Use `DRY_RUN=false` for production, `DRY_RUN=true` for testing
- **State file schema upgraded to v3**: Removes `release_tier` field, adds `dry_run` field
- **Profile-based configuration**: New `--profile` flag for easier setup

#### Features
- **One-click release from feature branches**: Automatic release branch creation
- **Improved CDN wait**: Real-time progress display, 60s minimum wait time
- **Enhanced error handling**: Fixed logger `set -u` compatibility (7 commits)
- **Better branch validation**: Feature branches can initiate production releases

#### Fixes
- fix(logger): Export all variables for `set -u` compatibility
- fix(release): Allow feature/* branches in production mode
- fix(config): Use default value syntax for optional parameters
- fix(release): Fix CDN wait hang and insufficient wait time

#### Migration
- See [PHASE_B_MIGRATION.md](docs/PHASE_B_MIGRATION.md) for migration guide
- Backward compatibility maintained for Schema v2

#### Commits
- e60af1f83: Export all variables
- c9d7b2dcb: Add defensive checks
- 0ef5a8aab: Use arithmetic comparison
- b10756e60: Validate parameters
- 6a1fed30e: Handle non-numeric values
- 45345d57b: Pattern matching validation
- 368901499: Allow feature/* branches
- 793b78811: Fix optional parameters
- 474422a55: Phase B Step 5 Extended cleanup
- 6cf412273: Fix CDN wait hang

---

## [0.3.0-rc.13] - 2026-01-05

### Phase A: Previous Release
- Initial release system implementation
- Dual-tier architecture (preflight/release)
- State file Schema v2

