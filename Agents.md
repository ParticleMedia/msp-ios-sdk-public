# AI Agent Shared Context

> **Version**: 3.0
> **Last Updated**: 2026-01-20
> **Applies To**: All AI Agents

## 1. Project Technical Context

**Language**: Swift 5.0
**Target**: iOS 15.0+
**Testing**: Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1

**Note**: For domain-specific development guidelines:
- Swift/Sources development: See `Sources/AGENTS-SOURCES.md`
- Scripts development: See `Scripts/AGENTS-SCRIPTS.md`

### Active Technologies

- Markdown configuration files (no code compilation) + N/A (documentation/configuration refactoring) (ai-infra-refactor)
- Bash (POSIX-compliant), Markdown + speckit workflow scripts, git (ai-infra-reorg)
- Swift 5.0, iOS 15.0+ + Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1 (unit-test-setup)

### Recent Changes

- ai-infra-reorg: Added Bash (POSIX-compliant), Markdown + speckit workflow scripts, git
- ai-infra-refactor: Added Markdown configuration files (no code compilation) + N/A (documentation/configuration refactoring)
- unit-test-setup: Added Swift 5.0, iOS 15.0+ + Quick ~> 7.0, Nimble ~> 13.0, OHHTTPStubs/Swift ~> 9.1

## 2. Pre-Task Checklist

- [ ] Clean working directory (`git status`)
- [ ] On correct branch
- [ ] In development mode (`./Scripts/switch-target.sh pods-dev`)

## 3. Shared Resources

### Skills
Location: `.agents-shared/skills/`
All agents can use all skills.

### Protocols
Location: `.agents-shared/protocols/`
- task-tier.protocol.md - Task classification guide
- output-format.protocol.md - Standardized output format

### Tools
- Scripts/tools/ - Automation scripts
- Sources/tools/ - Swift development tools
- Tests/templates/ - Test templates

## 4. Basic Workflow

### Branching
- feature/, fix/, chore/ prefixes
- Conventional Commits v1.0.0

### Commit Format
<type>(<scope>): <subject>

### Project Configuration Workflow

When modifying Xcode project structure (enforced by Federal Constitution Article I.2 and Sources Constitution Article IV.6):

**Step-by-Step Process**:
1. **Identify relevant template**: Find the appropriate `*.yml.template` file (e.g., `project.yml.template`, `*.podspec.template`)
2. **Make changes to YAML template**: Edit the template file with your project structure changes
3. **Run XcodeGen**: Execute `xcodegen generate` to regenerate `.xcodeproj`
4. **Verify changes**: Open the `.xcodeproj` in Xcode and verify the changes are correct
5. **Commit template only**: Commit only the `*.yml.template` changes (NOT the `.xcodeproj` files)

**Common Scenarios**:
- **Add new target**: Edit `project.yml.template` targets section
- **Add source files**: XcodeGen auto-discovers files by convention (no manual action needed)
- **Change build settings**: Edit the settings section in the appropriate template
- **Add dependencies**: Update `Podfile` (the Single Source of Truth for dependencies)

**Troubleshooting**:
- **XcodeGen fails**: Check YAML syntax with `yamllint project.yml.template`
- **Project missing files**: Verify glob patterns in template match your file structure
- **Build fails after regeneration**: Run `./Scripts/target-switching/round-trip-test.sh` to validate

## 5. Read-Only Zones

These files require human approval to modify:
- constitution.md (all versions)
- ARCHITECTURE.md
- README.md

## 6. Reference Documents

- constitution.md - Supreme law
- .claude/CLAUDE.md - Claude-specific rules
- .codex/CODEX.md - Codex-specific rules
- .cursor/CURSOR.md - Cursor-specific rules

## Active Technologies
- Swift 5.0 + CocoaPods, Quick, Nimble, OHHTTPStubs, XcodeGen (fix-unit-tests)
- Swift 5.0 + Quick ~> 7.0, Nimble ~> 13.0, Combine (debug-viewmodel-tests)
- N/A (unit tests only) (debug-viewmodel-tests)

## Recent Changes
- fix-unit-tests: Added Swift 5.0 + CocoaPods, Quick, Nimble, OHHTTPStubs, XcodeGen
