# MSP iOS SDK

MSP (Mobile SDK Platform) iOS SDK provides a unified advertising mediation framework for iOS applications. It integrates multiple ad networks through a modular adapter architecture with support for CocoaPods and Swift Package Manager distribution.

---

## 🚀 Quick Start

### Local Development

```bash
# Setup + switch to dev mode + open Xcode (one command)
make open

# Or step by step:
make setup        # bundle install + pod install + workspace update
make open         # switch pods-dev + open workspace
```

### Run Tests & Validation

```bash
make test         # Swift unit tests (MSPDemoApp scheme)
make validate     # Quick CI validation
make rtt          # Round-trip test (full target-switching compatibility)
make ci           # Full CI pipeline
```

### Release a Version

```bash
# Full release (CocoaPods + SPM)
make release VERSION=1.0.0 NOTES="Bug fixes and performance improvements"

# With extra flags
make release VERSION=1.0.0 NOTES="Fix crash" EXTRA_FLAGS="--only-pods"

# Resume interrupted release
make resume VERSION=1.0.0

# Or use the script directly:
./Scripts/msp-release.sh --profile=production run 1.0.0
./Scripts/msp-release.sh resume
```

### TestFlight Deployment

```bash
# First time setup: fetch credentials from private repo (one-time per machine)
make fetch-credentials

# Full deploy (archive + export + upload to App Store Connect)
make beta

# Dry run (archive + export only, no upload)
make beta-dry

# Override build number
./Scripts/testflight/deploy.sh --build-number 42
```

**Credentials are managed via a private repo** (`ParticleMedia/msp-ios-credentials`). Running `make fetch-credentials` clones it and installs:
- `AuthKey_*.p8` — ASC API key (App Manager role)
- `Distribution.p12` — iOS Distribution certificate (imported into Keychain automatically)
- `.env` — `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`

All credential files are gitignored and never committed to this repo.

The SDK version (`MARKETING_VERSION`) is read from `Scripts/config/sdk_version.conf` (SSOT). Build number is queried from ASC in real-time (falls back to `Scripts/testflight/config.yaml`).

### Cleanup

```bash
make clean        # Remove DerivedData + Pods
```

**All Makefile Targets:**

| Target | Purpose |
|--------|---------|
| `make setup` | Install dependencies (bundle + pod + workspace update) |
| `make open` | Switch to pods-dev and open Xcode workspace |
| `make test` | Run Swift unit tests (MSPDemoApp scheme) |
| `make validate` | Quick CI validation |
| `make rtt` | Round-trip test (target-switching compatibility) |
| `make ci` | Full CI pipeline |
| `make fetch-credentials` | Fetch ASC keys + Distribution cert from private credentials repo |
| `make beta` | Upload DemoApp to TestFlight |
| `make beta-dry` | Archive + export only, no upload |
| `make release VERSION=x NOTES="..."` | Production CocoaPods + SPM release |
| `make resume VERSION=x` | Resume interrupted release |
| `make clean` | Clean DerivedData and Pods |

**Advanced Release Commands (via script):**

| Command | Purpose |
|---------|---------|
| `./Scripts/msp-release.sh run <version> --only-pods` | CocoaPods only |
| `./Scripts/msp-release.sh run <version> --only-spm` | SPM only |
| `./Scripts/msp-release.sh create-github-releases <version>` | Fix missing GitHub Releases |
| `./Scripts/msp-release.sh fix-public-tag <version>` | Fix public remote tag |

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
│  │  ├─ MSPiOSCore           ├─ release/          (Modular)     │
│  │  └─ NovaCore             │   ├─ cli/          • Commands    │
│  └─ Adapters/               │   ├─ orchestrator/ • Workflow    │
│     ├─ Facebook             │   ├─ publish/      • Publishing  │
│     ├─ Google               │   ├─ utils/        • Utilities   │
│     ├─ Nova                 │   └─ verify/       • Validation  │
│     └─ ...                  └─ testflight/       (TF Deploy)   │
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
- **Makefile** - Developer workflow shortcuts

---

## 🔄 Development Modes

Switch between different development modes:

| Mode | Command | Use Case |
|------|---------|----------|
| `pods-dev` | `make open` or `./Scripts/switch-target.sh pods-dev` | Daily development with source files |
| `pods-release` | `./Scripts/switch-target.sh pods-release` | Pre-release validation with XCFrameworks |
| `spm-release` | `./Scripts/switch-target.sh spm-release` | SPM distribution testing |

---

## 📚 Documentation

### For Human Developers

| Document | Purpose |
|----------|---------|
| **[Scripts/README.md](Scripts/README.md)** | Scripts architecture and usage |
| **[Scripts/release/README.md](Scripts/release/README.md)** | Release system deep dive |
| **[Scripts/testflight/](#testflight-deployment)** | TestFlight deployment guide |
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

## Production Release Policy

Production releases can be triggered from CI/Jenkins **or** locally — no special flags required.

### CI/Jenkins Production Release

- Standard path for regular production releases.
- Trigger via the `releaseCocoapod` Jenkins pipeline with a clean `VERSION=X.Y.Z`.
- The pipeline enforces a clean Git state and a valid `release.md` automatically.

### Local Production Release

- Your Git working tree must be clean (`git status` shows nothing).
- `release.md` must exist and contain a `## Changes` section (auto-generated if absent).
- No branch restrictions; any branch is allowed.

```bash
make release VERSION=1.2.0 NOTES="Fix crash in ad loading"
# or directly:
./Scripts/msp-release.sh run 1.2.0
```

### Prerelease Publication

Use `MSP_PRERELEASE=1` to publish a test release (e.g., `3.6.8-rc.1`). Prereleases are
announced in Slack with a ⚠️ banner and are **not for production apps**.

```bash
# Local prerelease
make release-prerelease VERSION=3.6.8-rc.1 NOTES="RC for testing"

# Jenkins: tick the ⚠️ PRERELEASE checkbox and enter a VERSION with a suffix (e.g. 3.6.8-rc.1)
```

See [`specs/004-release-hardening/quickstart.md`](specs/004-release-hardening/quickstart.md) for a full walkthrough.

---

## 📖 Quick Links

- [Full Release Guide](Docs/RELEASE.md)
- [Scripts Reference](Scripts/README.md)
- [Troubleshooting](Docs/TROUBLESHOOTING.md)
- [AI Agent Guide](Docs/AI_AGENTS.md)
