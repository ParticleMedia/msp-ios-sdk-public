# MSP iOS SDK

MSP (Mobile SDK Platform) iOS SDK provides a unified advertising mediation framework for iOS applications. It integrates multiple ad networks through a modular adapter architecture with support for CocoaPods and Swift Package Manager distribution.

---

## 🚀 Quick Start

### Local Development

```bash
# Switch to development mode
./Scripts/switch-target.sh pods-dev

# Open workspace
open msp-ios-sdk.xcworkspace
```

### Release a Version

```bash
# Full release (CocoaPods + SPM)
./Scripts/msp-release.sh --profile=production run 1.0.0

# Only release CocoaPods
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-pods

# Only release SPM
./Scripts/msp-release.sh --profile=production run 1.0.0 --only-spm

# Resume interrupted release
./Scripts/msp-release.sh resume
```

**Common Release Commands:**

| Command | Purpose |
|---------|---------|
| `run <version>` | Execute full release (CocoaPods + SPM) |
| `run <version> --only-pods` | CocoaPods only |
| `run <version> --only-spm` | SPM only |
| `resume` | Resume from state file |
| `create-github-releases <version>` | Fix missing GitHub Releases |
| `fix-public-tag <version>` | Fix public remote tag |

See [Docs/RELEASE.md](Docs/RELEASE.md) for detailed release documentation.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         MSP iOS SDK                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Sources/                    Scripts/                            │
│  ├─ Core/                    ├─ msp-release.sh   (Entrypoint)  │
│  │  ├─ MSPCore              ├─ switch-target.sh  (Mode switch) │
│  │  ├─ MSPiOSCore           └─ release/          (Modular)     │
│  │  └─ NovaCore                 ├─ cli/          • Commands    │
│  └─ Adapters/                   ├─ orchestrator/ • Workflow    │
│     ├─ Facebook                 ├─ publish/      • Publishing  │
│     ├─ Google                   ├─ utils/        • Utilities   │
│     ├─ Nova                     └─ verify/       • Validation  │
│     └─ ...                                                      │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Distribution                                                    │
│  ├─ CocoaPods (11 pods)                                         │
│  └─ Swift Package Manager                                       │
└─────────────────────────────────────────────────────────────────┘
```

**Key Directories:**
- **Sources/** - Swift source code (Core modules + Adapters)
- **Scripts/** - Automation (release, build, CI/CD)
- **Tests/** - Unit tests
- **Examples/** - MSPDemoApp
- **Build/ReleaseArtifacts/** - Build outputs (XCFrameworks, Zips)

---

## 🔄 Development Modes

Switch between different development modes:

| Mode | Command | Use Case |
|------|---------|----------|
| `pods-dev` | `./Scripts/switch-target.sh pods-dev` | Daily development with source files |
| `pods-release` | `./Scripts/switch-target.sh pods-release` | Pre-release validation with XCFrameworks |
| `spm-release` | `./Scripts/switch-target.sh spm-release` | SPM distribution testing |

---

## 📚 Documentation

### For Human Developers

| Document | Purpose |
|----------|---------|
| **[Scripts/README.md](Scripts/README.md)** | Scripts architecture and usage |
| **[Scripts/release/README.md](Scripts/release/README.md)** | Release system deep dive |
| **[Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)** | System architecture |
| **[Docs/RELEASE.md](Docs/RELEASE.md)** | Release process guide |
| **[Docs/TARGET_SWITCHING.md](Docs/TARGET_SWITCHING.md)** | Mode switching details |
| **[Docs/TROUBLESHOOTING.md](Docs/TROUBLESHOOTING.md)** | Common issues |

### For AI Agents

The project is AI-native with comprehensive documentation for AI assistance:

| Document | Purpose |
|----------|---------|
| **[constitution.md](constitution.md)** | Project governance (supreme law) |
| **[AGENTS.md](AGENTS.md)** | AI operations manual |
| **[Docs/AI_AGENTS.md](Docs/AI_AGENTS.md)** | Multi-agent architecture |
| **[.context/](.context/)** | Knowledge base (渐进式加载) |

**Supported AI Agents:**
- **Claude Code** (`.claude/`) - Strategic advisor (Tier 2-3)
- **Codex CLI** (`.codex/`) - Tactical executor (Tier 0-1)
- **Cursor IDE** (`.cursor/`) - Interactive partner (Tier 1-2)

**AI Context System:**
```bash
# Search for relevant knowledge
./Scripts/context/search-context.sh "static linking"

# Add new context entry
./Scripts/context/add-context.sh
```

See [.context/index.md](.context/index.md) for the complete knowledge base.

---

## 🛠️ Requirements

- Xcode 15.0+
- iOS 15.0+
- CocoaPods 1.14+
- XcodeGen (`brew install xcodegen`)

---

## 📦 Release Profiles

| Profile | DRY_RUN | Use Case |
|---------|---------|----------|
| `production` | ❌ | Full production release |
| `local-dev` | ✅ | Local testing (no publishing, default) |
| `quick-test` | ✅ | Minimal validation, fastest |

---

## 🎯 Release Modes

Release mode controls whether post-release verification runs:

| Mode | Verification | When Activated |
|------|--------------|----------------|
| `full` | Complete validation (includes remote + local verification) | `--profile=production` or `--full` flag |
| `simple` | Skips verification phase | `--profile=local-dev` / `quick-test` (default) |

**Key behavior:** `--profile=production` **automatically** activates full mode. No extra flags needed.

```bash
# Production release (full mode, automatic)
./Scripts/msp-release.sh --profile=production run 1.0.0

# Local testing (simple mode, default)
./Scripts/msp-release.sh run 1.0.0

# Force full mode on non-production profile
./Scripts/msp-release.sh --full run 1.0.0
```

---

## 📖 Quick Links

- [Full Release Guide](Docs/RELEASE.md)
- [Scripts Reference](Scripts/README.md)
- [Troubleshooting](Docs/TROUBLESHOOTING.md)
- [AI Agent Guide](Docs/AI_AGENTS.md)
