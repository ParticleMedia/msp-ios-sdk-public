# MSP iOS SDK

MSP (Mobile SDK Platform) iOS SDK provides a unified advertising mediation framework for iOS applications. It integrates multiple ad networks through a modular adapter architecture with support for CocoaPods and Swift Package Manager distribution.

## Quick Start

### Local Development (pods-dev)

```bash
# Switch to development mode
./Scripts/switch-target.sh pods-dev

# Open workspace
open msp-ios-sdk.xcworkspace
```

### Release Commands

```bash
# Production release
./Scripts/msp-release.sh --profile=production run 1.0.0

# Production release (auto-select pod wait option 1 to avoid interactive prompt)
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-pods --pod-wait-choice 1

# Resume interrupted release
./Scripts/msp-release.sh resume

# Fix public tag (after GitHub Push Protection skip)
./Scripts/msp-release.sh fix-public-tag 1.0.0
```

## Development Modes

| Mode | Command | Use Case |
|------|---------|----------|
| `pods-dev` | `./Scripts/switch-target.sh pods-dev` | Daily development with source files |
| `pods-release` | `./Scripts/switch-target.sh pods-release` | Pre-release validation with XCFrameworks |
| `spm-release` | `./Scripts/switch-target.sh spm-release` | SPM distribution testing |

## Repository Layout

```
msp-ios-sdk/
├── Sources/
│   ├── Core/              # Core modules (MSPCore, MSPiOSCore, NovaCore, etc.)
│   ├── Adapters/          # Ad network adapters
│   └── tools/             # Shared Swift development tools
├── Tests/
│   └── templates/         # Test templates
├── ThirdParty/            # Vendor SDKs
├── Build/ReleaseArtifacts/  # Canonical build outputs
│   ├── XCFrameworks/      # All built XCFrameworks (core/adapters/third-party)
│   ├── Archives/          # xcodebuild archives
│   ├── Binary/            # Staging area for release zips (Binary/ inside zip)
│   └── Zips/              # Release zip outputs
├── Examples/              # MSPDemoApp
├── Scripts/
│   ├── msp-release.sh     # Main release entrypoint
│   ├── switch-target.sh   # Mode switching
│   ├── tools/             # Shared automation tools
│   └── templates/         # Release templates
│
├── .agents-shared/        # Shared AI capability layer
│   ├── protocols/         # Task tier, escalation, handoff protocols
│   └── skills/            # Shared skills for all agents
├── .context/              # AI context system - preserved development knowledge
│   ├── release/           # Release and deployment experiences (2 entries)
│   ├── ci/                # CI/CD pipeline knowledge
│   ├── integration/       # Third-party integration lessons
│   ├── compatibility/     # Version compatibility issues
│   ├── sources/           # Swift code patterns (Phase 2)
│   ├── architecture/      # Design decisions (Phase 2)
│   ├── testing/           # Test strategies (Phase 2)
│   └── templates/         # Context entry templates
├── .claude/               # Claude Code configuration
│   ├── skills/            # Claude-exclusive strategic skills
│   ├── agents/            # Autonomous sub-agents
│   └── commands/          # Slash commands
├── .codex/                # Codex CLI configuration
├── .cursor/               # Cursor IDE configuration
│
├── AGENTS.md              # AI agent operations manual (v2.0)
├── constitution.md        # Project governance rules
├── Podfile                # CocoaPods dependencies (source of truth)
├── Package.swift.template # SPM package template
└── *.podspec              # Pod specifications
```

## Release Profiles

| Profile | DRY_RUN | Purpose |
|---------|---------|---------|
| `production` | false | Full production release |
| `local-dev` | true | Local testing (no publishing) |
| `ci-test` | true | CI/CD validation |
| `quick-test` | true | Minimal validation |

## Documentation

### Technical Docs
- [Docs/INDEX.md](Docs/INDEX.md) - Documentation navigation
- [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) - System architecture
- [Docs/RELEASE.md](Docs/RELEASE.md) - Release semantics
- [Docs/TARGET_SWITCHING.md](Docs/TARGET_SWITCHING.md) - Mode switching details
- [Docs/THIRD_PARTY_UPGRADES.md](Docs/THIRD_PARTY_UPGRADES.md) - Dependency management
- [Docs/TROUBLESHOOTING.md](Docs/TROUBLESHOOTING.md) - Common issues
- [Scripts/README.md](Scripts/README.md) - Scripts reference

### AI & Governance
- [Docs/AI_AGENTS.md](Docs/AI_AGENTS.md) - Comprehensive AI agent architecture (v2.0)
- [AGENTS.md](AGENTS.md) - Operations manual for AI agents (v2.0)
- [.agents-shared/](.agents-shared/) - Shared capability layer (protocols, skills)
- [constitution.md](constitution.md) - Project governance rules

### Supported AI Agents
| Agent | Config | Use Case |
|-------|--------|----------|
| Claude Code | `.claude/` | Strategic analysis, architecture (Tier 2-3) |
| Codex CLI | `.codex/` | Quick execution, one-shot tasks (Tier 0-1) |
| Cursor IDE | `.cursor/` | Interactive development (Tier 1-2) |

## AI Context System

The project maintains a structured knowledge base in `.context/` that preserves development experience and lessons learned. This system enables AI agents to automatically retrieve relevant context when answering questions.

### Context Library

**Current Status**: 2 entries in Release domain

```bash
# View all contexts with dual-dimension classification
./Scripts/context/list-context.sh

# Search for specific topics
./Scripts/context/search-context.sh "static linking"

# Add new context manually
./Scripts/context/add-context.sh

# Extract contexts from commit history
./Scripts/context/init-context.sh
```

### Context Structure

Contexts are classified by two orthogonal dimensions:

**Domain** (领域): release, ci, integration, compatibility, sources, architecture, testing

**Layer** (层级):
- `business`: Product requirements, business rules, user scenarios
- `experience`: Debugging processes, lessons learned, solutions
- `tech`: API usage, architecture design, design patterns

### Available Skills

- `/context.add` - Manually add new context entry
- `/context.list` - Browse and filter context library

See [specs/001-ai-context-system/quickstart.md](specs/001-ai-context-system/quickstart.md) for detailed usage.

## Requirements

- Xcode 15.0+
- iOS 15.0+
- CocoaPods 1.14+
- XcodeGen (`brew install xcodegen`)
