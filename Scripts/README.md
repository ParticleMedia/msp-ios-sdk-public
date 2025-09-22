# MSP iOS SDK Scripts Documentation

## Overview

The MSP iOS SDK project features a comprehensive modular script architecture that provides enhanced build automation, release management, and testing capabilities. This system is designed to be maintainable, extensible, and compatible with various development environments.

## 🚀 Quick Start

```bash
# Build all frameworks
./Scripts/build.sh

# Build demo app
./Scripts/buildDemoApp.sh

# Complete release process (recommended)
./Scripts/release-modular.sh 0.0.2-migration-spm

# Dry run to preview operations
./Scripts/release-modular.sh --dry-run 0.0.2-migration-spm

# Check project status
./Scripts/build.sh --status
```

## 📦 Modular Release System

The modular release system follows this exact workflow:

1. **Create Release Branch** - Creates a release branch from the base branch
2. **Release CocoaPods** - Publishes all CocoaPods in dependency order
3. **Release SPM** - Publishes Swift Package Manager packages
4. **Push Release Branch** - Pushes the release branch to remote

### 📝 Release Notes System

The release system includes comprehensive release notes functionality with multiple generation methods:

#### Release Notes Sources

**1. Git-based Generation (`--release-notes-source git`)**
- Automatically generates from git commits since last tag
- Lists all commits with hashes for reference
- Handles initial releases gracefully

**2. Template-based Generation (`--release-notes-source template`)**
- Uses predefined or custom templates
- Supports placeholder replacement ({{VERSION}}, {{RELEASE_TYPE}}, {{DATE}})
- Rich formatting with emojis and sections

**3. Manual Input (`--release-notes-source prompt`)**
- Interactive prompt for custom release notes
- Multi-line input support with preview

**4. Simple Bullet Points (`--release-notes-source simple`)**
- Provide just bullet points for "What's New" section
- Automatically generates full release note structure
- Includes version, date, and environment automatically
- Perfect for quick releases with minimal input

**5. Direct Input (`--release-notes "Your notes here"`)**
- Provide notes directly via command line
- Perfect for automation and CI/CD

**6. Auto Mode (`--release-notes-source auto`) - Default**
- Intelligently chooses the best method
- Tries git first, falls back to template

#### Usage Examples

```bash
# Auto-generated release notes (default)
./Scripts/release-cocoapods-modular.sh --release-branch main 1.0.0

# Git-based release notes
./Scripts/release-cocoapods-modular.sh --release-branch main --release-notes-source git 1.0.0

# Custom template
./Scripts/release-cocoapods-modular.sh --release-branch main --release-notes-source template --release-notes-template Scripts/templates/release-notes-template.md 1.0.0

# Simple bullet points (recommended for quick releases)
./Scripts/release-cocoapods-modular.sh --release-notes-source simple --release-notes "Bug fixes and improvements
NovaCore migration" 1.0.0

# Interactive prompt
./Scripts/release-cocoapods-modular.sh --release-branch main --release-notes-source prompt 1.0.0

# Direct input
./Scripts/release-cocoapods-modular.sh --release-branch main --release-notes "## Release 1.0.0\n\n- Bug fixes\n- Improvements" 1.0.0
```

#### Simple Release Notes (Recommended)

The **Simple Bullet Points** method is the easiest way to create release notes:

**What you provide:**
```bash
--release-notes "Bug fixes and improvements
NovaCore migration
Performance optimizations"
```

**What you get automatically:**
```markdown
## Release 0.0.4-migration

### What's New
- Bug fixes and improvements
- NovaCore migration
- Performance optimizations

### Technical Details
- Version: 0.0.4-migration
- Release Date: 2025-09-20
- Environment: Local Development
```

**Benefits:**
- ✅ Minimal input required
- ✅ Automatic formatting
- ✅ Version and date auto-generated
- ✅ Environment detection
- ✅ Perfect for Slack notifications

#### Slack Integration

Release notes are automatically included in Slack notifications:
- **Release Start** - Shows notes in "Release Notes" field
- **Release Success** - Includes notes in success notifications
- **Smart Truncation** - Long notes truncated to 200 chars with "..."
- **Rich Formatting** - Structured data with emojis and sections

#### Template System

**Default Template:**
```markdown
## {{RELEASE_TYPE}} {{VERSION}}

### What's New
- Bug fixes and improvements
- Performance optimizations
- Enhanced stability

### Technical Details
- Version: {{VERSION}}
- Release Date: {{DATE}}
- Environment: {{ENVIRONMENT}}
```

**Custom Template Support:**
- Create templates in `Scripts/templates/`
- Use placeholders: `{{VERSION}}`, `{{RELEASE_TYPE}}`, `{{DATE}}`
- Rich formatting with emojis and sections

#### Testing Release Notes

```bash
# Test release notes functionality
./Scripts/test-release-notes.sh

# Test individual functions
source Scripts/lib/release-common.sh
generate_release_notes_from_git "1.0.0" "" "CocoaPods"
generate_release_notes_from_template "1.0.0" "CocoaPods"
```

### 🔔 Slack Notifications

The release system includes comprehensive Slack notifications for real-time updates:

#### Setup

1. **Create Slack App** at [api.slack.com/apps](https://api.slack.com/apps)
2. **Enable Incoming Webhooks** in your app settings
3. **Add webhook to workspace** and copy the webhook URL
4. **Set environment variable:**
   ```bash
   export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
   ```

#### Notification Types

- **🔄 Release Start** - When releases begin
- **✅ Individual Pod Status** - Real-time pod release updates  
- **🎉 Release Success** - When all releases complete successfully
- **❌ Release Failure** - Immediate alerts for failures
- **⚠️ Release Warnings** - For partial success scenarios
- **📊 Release Summary** - Final statistics and metrics

#### Environment Detection

The system automatically detects the environment:
- **Local Development** - Shows user@hostname
- **Jenkins** - Shows build number
- **GitHub Actions** - Shows workflow name
- **CI** - Shows generic CI environment

#### Configuration

```bash
# Environment variables
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export SLACK_CHANNEL="#releases"  # Optional, defaults to #releases
export SLACK_USERNAME="MSP iOS SDK Bot"  # Optional
export SLACK_ICON_EMOJI=":rocket:"  # Optional

# Test notifications
./Scripts/test-slack-integration.sh
```

#### Integration Examples

**Local Scripts:**
```bash
# Automatic notifications
./Scripts/release-cocoapods-modular.sh --release-branch main 1.0.0
./Scripts/release-spm-modular.sh --release-branch main 1.0.0
```

**Jenkins Integration:**
```bash
# Use Jenkins integration script
./Scripts/jenkins-slack-integration.sh cocoapods 1.0.0 main
./Scripts/jenkins-slack-integration.sh spm 1.0.0 main
```

**GitHub Actions:**
- Notifications automatically included in workflow
- Set `SLACK_WEBHOOK_URL` as repository secret
- Set `SLACK_CHANNEL` as repository variable (optional)

### Main Orchestrator

#### `release-modular.sh`
The main release orchestrator that runs the complete release process.

```bash
# Complete release process
./Scripts/release-modular.sh 0.0.2-migration-spm

# Dry run to see what would happen
./Scripts/release-modular.sh --dry-run 0.0.2-migration-spm

# Skip certain steps
./Scripts/release-modular.sh --skip-spm 0.0.2-migration-spm
./Scripts/release-modular.sh --skip-cocoapods 0.0.2-migration-spm

# Skip code signing (for local testing)
./Scripts/release-modular.sh --skip-code-sign 0.0.2-migration-spm

# Use different base branch
./Scripts/release-modular.sh --base-branch main 0.0.2-migration-spm
```

### Individual Components

#### `create-release-branch.sh`
Creates a release branch from the base branch.

```bash
# Create release branch
./Scripts/create-release-branch.sh 0.0.2-migration-spm

# Use different base branch
./Scripts/create-release-branch.sh --base-branch main 0.0.2-migration-spm
```

#### `release-cocoapods-modular.sh`
Releases all CocoaPods in the correct dependency order.

**Release Order:**
1. **MSPSharedLibraries** (foundation dependency) → Check availability
2. **Adapters** (FacebookAdapter, GoogleAdapter, NovaAdapter, AmazonAdapter, PrebidAdapter) - Released in parallel for maximum efficiency
3. **Dependency Check** - Verify MSPSharedLibraries and PrebidAdapter availability for MSPCore
4. **MSPCore** (main framework)

**What it does for each pod:**
- Updates `spec.version` in podspec
- Updates `spec.source` to HTTP zip format
- Updates `getSDKVersion()` function in adapter code
- Updates `version` property in MSPCore
- Updates dependencies to use the new version
- Creates GitHub release with zip file
- Publishes to CocoaPods trunk
- Waits for availability with exponential backoff

```bash
# Release CocoaPods (must be on release branch)
./Scripts/release-cocoapods-modular.sh 0.0.2-migration-spm

# Skip validation
./Scripts/release-cocoapods-modular.sh --skip-validation 0.0.2-migration-spm
```

#### `release-spm-modular.sh`
Releases Swift Package Manager packages.

**SPM Packages:**
- **NovaCore** - Core SPM package
- **NovaAdapter** - Adapter SPM package (depends on NovaCore)

**What it does:**
- Updates version in `Package.swift` files
- Updates dependencies between SPM packages
- Creates git tags for SPM packages
- Pushes tags to remote

```bash
# Release SPM (must be on release branch)
./Scripts/release-spm-modular.sh 0.0.2-migration-spm
```

## 🏗️ Build System

### Unified Build Script (`build.sh`)

**Version:** 2.0.0  
**Purpose:** Centralized build automation for all frameworks

#### Features:
- **Multi-framework support**: Build MSPiOSCore, NovaCore, and MSPCore
- **Environment validation**: Automatic detection of required tools
- **Flexible configuration**: Support for different build modes
- **Error handling**: Comprehensive error reporting and recovery
- **Dry-run mode**: Preview build operations without execution

#### Usage:
```bash
# Build all frameworks
./Scripts/build.sh

# Build specific framework
./Scripts/build.sh --framework MSPiOSCore

# Build multiple frameworks
./Scripts/build.sh --frameworks "MSPiOSCore NovaCore"

# Dry run to preview
./Scripts/build.sh --dry-run all

# Skip code signing
./Scripts/build.sh --skip-code-sign

# Show build status
./Scripts/build.sh --status

# Show project information
./Scripts/build.sh --info

# Clean build artifacts
./Scripts/build.sh --clean

# Clean all artifacts
./Scripts/build.sh --clean-all
```

### Demo App Builder (`buildDemoApp.sh`)

**Version:** 1.0.0  
**Purpose:** Dedicated script for building and testing the MSPDemoApp

#### Features:
- **Automatic Linking Detection**: Automatically detects whether to use XCFramework or static library linking
- **CI Integration**: Optimized for CI/CD environments with fallback validation
- **Flexible Configuration**: Supports different build configurations and destinations
- **Error Handling**: Comprehensive error handling with graceful fallbacks

#### Usage:
```bash
# Build demo app with default settings
./Scripts/buildDemoApp.sh

# Build for specific simulator
./Scripts/buildDemoApp.sh 'platform=iOS Simulator,name=iPhone 15 Pro'

# Build with specific configuration
./Scripts/buildDemoApp.sh 'platform=iOS Simulator,name=iPhone 15' Release

# Build with custom derived data path
./Scripts/buildDemoApp.sh 'platform=iOS Simulator,name=iPhone 15' Debug /tmp/CustomDerivedData
```

### Build and Test Script (`buildAndTest.sh`)

**Version:** 1.0.0  
**Purpose:** Comprehensive build and test automation

#### Features:
- **Sequential Execution**: Builds frameworks, then demo app, then runs tests
- **Error Handling**: Stops on first failure with clear error reporting
- **Test Integration**: Integrates with existing test infrastructure
- **CI Compatibility**: Works in both local and CI environments

#### Usage:
```bash
# Run complete build and test cycle
./Scripts/buildAndTest.sh

# Run with specific framework
./Scripts/buildAndTest.sh MSPiOSCore

# Run with custom options
./Scripts/buildAndTest.sh --skip-code-sign --verbose
```

## 📚 Library Modules

This directory contains reusable library modules that provide common functionality across all build scripts. These libraries eliminate code duplication and ensure consistent behavior across all scripts.

### Available Libraries

#### Demo App Builder (`lib/demo_app_builder.sh`)
Provides reusable functions for building and validating the MSPDemoApp in various contexts.

**Core Functions:**
- `build_demo_app [destination] [configuration] [derived_data_path]` - Main function that automatically detects linking mode
- `build_demo_app_framework [destination] [configuration] [derived_data_path]` - Builds using XCFramework linking mode
- `build_demo_app_static [destination] [configuration] [derived_data_path]` - Builds using static library linking mode
- `validate_demo_app_structure` - Validates project structure without building
- `detect_linking_mode` - Detects whether to use framework or static library linking

**Usage Examples:**
```bash
#!/bin/bash
# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/demo_app_builder.sh"

# Build demo app with default settings
build_demo_app

# Build for specific device and configuration
build_demo_app 'platform=iOS Simulator,name=iPhone 15 Pro' Release /tmp/CustomDerivedData

# Check linking mode
if [ "$(detect_linking_mode)" = "framework" ]; then
    echo "Using XCFramework linking"
else
    echo "Using static library linking"
fi
```

**Benefits:**
- Code Reuse: No more duplicating demo app building logic
- Consistency: Same building behavior across all scripts
- Maintainability: Update logic in one place
- CI Integration: Built-in support for CI/CD environments
- Fallback Support: Graceful degradation when builds fail

#### XCFramework Builder (`lib/xcframework_builder.sh`)
Centralized XCFramework creation with CI path resolution and robust error handling.

#### Color Utilities (`lib/colors.sh`)
Standardized color definitions for consistent output across all scripts.

#### Framework Configuration (`lib/framework_config.sh`)
Framework-specific configuration management and build order handling.

#### Common Utilities (`lib/common.sh`)
Core utilities and shared functions used across all scripts:
- Environment detection
- Path management
- Error handling
- Utility functions

#### Logging System (`lib/logging.sh`)
Structured logging with environment-aware output:
- Color-coded output
- CI/CD integration
- Log levels and filtering
- Structured formatting

#### Validation Framework (`lib/validation.sh`)
Comprehensive validation for all inputs and environments:
- Command availability checking
- Path validation
- Xcode environment validation
- Project structure validation

#### Xcode Operations (`lib/xcode.sh`)
Advanced Xcode build operations:
- Multi-architecture builds
- XCFramework generation
- Code signing management
- Build optimization

#### CocoaPods Management (`lib/cocoapods.sh`)
CocoaPods integration and management with retry logic:
- Podspec validation with retry
- Publishing automation with exponential backoff
- Cache management
- Dependency resolution
- Network troubleshooting
- Alternative source fallbacks

#### Release Common (`lib/release-common.sh`)
Release-specific shared functionality:
- Pod configuration management
- Dependency order validation
- Retry logic with exponential backoff
- Podspec update utilities
- GitHub release management

#### CI/CD Support (`lib/ci.sh`)
CI/CD environment detection and optimization:
- Environment detection
- Performance optimization
- Artifact management
- CI-specific configurations

### Library Integration

#### Existing Scripts
The libraries can be integrated into existing scripts:
- **`build.sh`**: Add demo app building as a final step
- **`release.sh`**: Include demo app validation before release
- **CI/CD workflows**: Use for both building and validation

#### New Scripts
Create new scripts that leverage the libraries:
- **`buildAndTest.sh`**: Build everything and run tests
- **`validate.sh`**: Validate project structure and dependencies
- **`ci-build.sh`**: CI-optimized build script

### Library Dependencies
- Bash shell
- Xcode command line tools
- CocoaPods (for project dependencies)

### CI/CD Features

#### Automatic Environment Detection
- Detects CI environment automatically
- Applies CI-specific optimizations
- Handles path resolution issues (e.g., `/tmp` vs `/private/tmp`)

#### Fallback Mechanisms
- Graceful degradation when builds fail
- Structure validation as fallback
- Comprehensive error reporting for CI debugging

#### Path Resolution
- Handles symlinked directories in CI
- Uses absolute paths for XCFramework creation
- Compatible with GitHub Actions and other CI platforms

### Error Handling
All library functions return appropriate exit codes:
- `0`: Success
- `1`: Failure

The libraries include comprehensive error handling and colored output for better user experience.

### Best Practices
1. **Always source the library** before using its functions
2. **Check return codes** from library functions
3. **Use fallback validation** when builds fail in CI
4. **Customize parameters** for your specific use case
5. **Handle errors gracefully** in your scripts

## 🔧 Configuration System

### Build Configuration (`config/build.conf`)
Build settings and optimization flags:
- Compiler flags
- Build optimization settings
- Architecture-specific settings
- Environment overrides

### Framework Configuration (`config/frameworks.conf`)
Framework-specific configurations:
- Build order
- Dependencies
- Output directories
- Special requirements

### Environment Configuration (`config/environments.conf`)
Environment-specific settings:
- Development vs production
- CI/CD environment detection
- Platform-specific configurations
- Inheritance rules

## 🚀 Usage Examples

### Complete Release Process

```bash
# 1. Complete release (recommended)
./Scripts/release-modular.sh 0.0.2-migration-spm

# 2. Dry run first to verify
./Scripts/release-modular.sh --dry-run 0.0.2-migration-spm

# 3. Release with verbose output
./Scripts/release-modular.sh --verbose 0.0.2-migration-spm
```

### Step-by-Step Release

```bash
# 1. Create release branch
./Scripts/create-release-branch.sh 0.0.2-migration-spm

# 2. Release CocoaPods
./Scripts/release-cocoapods-modular.sh 0.0.2-migration-spm

# 3. Release SPM
./Scripts/release-spm-modular.sh 0.0.2-migration-spm

# 4. Push release branch
git push origin release/0.0.2-migration-spm
```

### Partial Release

```bash
# Only CocoaPods (no SPM)
./Scripts/release-modular.sh --skip-spm 0.0.2-migration-spm

# Only SPM (no CocoaPods)
./Scripts/release-modular.sh --skip-cocoapods 0.0.2-migration-spm

# Don't push (for testing)
./Scripts/release-modular.sh --skip-push 0.0.2-migration-spm
```

## ⚙️ Configuration

### Base Branch
The default base branch is `newsbreak_msp_migration_spm_dist`. You can change it:

```bash
./Scripts/release-modular.sh --base-branch main 0.0.2-migration-spm
```

### Release Branch
The default release branch is `release/VERSION`. You can change it:

```bash
./Scripts/release-modular.sh --release-branch my-release 0.0.2-migration-spm
```

## 🔄 Retry Logic

The system includes comprehensive retry logic with exponential backoff:

- **CocoaPods publishing**: 3 attempts with exponential backoff
- **Pod availability**: 8 attempts with exponential backoff (15s → 30s → 60s → ...)
- **GitHub releases**: 3 attempts with exponential backoff
- **Specs repo update**: 3 attempts with exponential backoff

## 📋 Dependencies

### Required Tools
- `git` - Version control
- `gh` - GitHub CLI for releases
- `pod` - CocoaPods for publishing
- `zip` - For creating release archives
- `xcodebuild` - Xcode build tools

### Required Environment
- GitHub repository access
- CocoaPods trunk access
- Clean working directory

### GitHub CLI Setup:
```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login
```

### CocoaPods Setup:
```bash
# Install CocoaPods
gem install cocoapods

# Setup trunk (one-time)
pod trunk register your-email@example.com 'Your Name'
```

## 🐛 Troubleshooting

### Common Issues:

1. **"iOS workspace not found"**
   - Ensure you're running from the project root
   - Verify the workspace directory exists

2. **"Required tool not found"**
   - Install missing tools (Xcode, CocoaPods, Git)
   - Check PATH environment variable

3. **"Build script syntax errors"**
   - Ensure Bash 3.2+ compatibility
   - Check for missing dependencies

4. **"Release validation failed"**
   - Check podspec syntax
   - Verify version format (semantic versioning)
   - Ensure clean git working directory

5. **Network Connectivity Issues**
   - Ensure stable internet connection
   - Check GitHub and CocoaPods access
   - Verify GitHub CLI authentication: `gh auth status`
   - Verify CocoaPods trunk: `pod trunk me`

6. **Release Branch Issues**
   ```bash
   # Check current branch
   git branch --show-current
   
   # Switch to release branch
   git checkout release/0.0.2-migration-spm
   
   # Create release branch if missing
   ./Scripts/create-release-branch.sh 0.0.2-migration-spm
   ```

7. **CocoaPods Issues**
   ```bash
   # Update specs repo
   bundle exec pod repo update
   
   # Clean CocoaPods cache
   bundle exec pod cache clean --all
   
   # Skip validation for testing
   ./Scripts/release-cocoapods-modular.sh --skip-validation 0.0.2-migration-spm
   ```

8. **GitHub Issues**
   ```bash
   # Check GitHub CLI authentication
   gh auth status
   
   # Re-authenticate if needed
   gh auth login
   ```

### Debug Mode:
Enable verbose output for detailed debugging:
```bash
./Scripts/build.sh --verbose
./Scripts/release-modular.sh --verbose
./Scripts/release-cocoapods-modular.sh --verbose
```

### Log Files:
Scripts generate detailed logs for troubleshooting:
- Build logs: `build_*.log`
- Release logs: `release_*.log`
- Test logs: `test_*.log`

## 🔧 Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SKIP_CODE_SIGN` | Skip code signing | `false` (enabled) |
| `PUBLISH_TO_COCOAPODS` | Enable CocoaPods publishing | `true` |
| `FORCE_RELEASE` | Force release with validation issues | `false` |
| `COCOAPODS_TRUNK_TOKEN` | CocoaPods publishing token | - |
| `GITHUB_TOKEN` | GitHub release token | - |
| `VERBOSE` | Enable verbose output | `false` |

## 📁 Output Locations

| Framework | Location |
|-----------|----------|
| MSPiOSCore | `MSPSharedLibraries/MSPiOSCore.xcframework` |
| NovaCore | `NovaAdapter/NovaCore.xcframework` |
| MSPCore | Source-only (no binary) |

## 🏆 Best Practices

### 1. Script Usage
- Always run scripts from the project root directory
- Use dry-run mode to preview operations
- Check environment validation before execution
- Use appropriate flags for your use case

### 2. Release Process
- Always test releases with dry-run first
- Create backups before major releases
- Validate podspecs before publishing
- Use semantic versioning for releases

### 3. Testing
- Run the test framework regularly
- Test in different environments
- Validate error scenarios
- Monitor performance metrics

### 4. Configuration
- Keep configurations in version control
- Use environment-specific overrides
- Document custom configurations
- Test configuration changes

## 🔄 Migration from Old System

The old release scripts have been removed and replaced with this modular system:

- ❌ `automate-release-setup.sh` → ✅ `create-release-branch.sh`
- ❌ `automated-release.sh` → ✅ `release-modular.sh`
- ❌ `release-cocoapods.sh` → ✅ `release-cocoapods-modular.sh`
- ❌ `release-spm.sh` → ✅ `release-spm-modular.sh`

The new system is more modular, easier to extend, and follows the exact workflow you specified.

## 🚀 Extending the System

### Adding New Pods
1. Add to `POD_RELEASE_ORDER` in `Scripts/lib/release-common.sh`
2. Add dependency mapping in `get_pod_dependencies_internal()`
3. Update adapter list in `release-cocoapods-modular.sh`

### Adding New SPM Packages
1. Add to `release-spm-modular.sh`
2. Create corresponding `Package.swift` files
3. Add tag creation logic

### Adding New Steps
1. Create new script in `Scripts/`
2. Add step to `release-modular.sh`
3. Update help and documentation

## 📊 Architecture Overview

```
Scripts/
├── build.sh                      # Unified build script (v2.0.0)
├── buildDemoApp.sh              # Demo app builder (v1.0.0)
├── buildAndTest.sh              # Build and test automation (v1.0.0)
├── release-modular.sh           # Main release orchestrator
├── create-release-branch.sh     # Release branch creation
├── release-cocoapods-modular.sh # CocoaPods release with retry logic
├── release-spm-modular.sh       # SPM release automation
├── lib/                         # Shared library modules
│   ├── common.sh               # Core utilities and functions
│   ├── logging.sh              # Logging and output formatting
│   ├── validation.sh           # Environment and input validation
│   ├── xcode.sh                # Xcode build operations
│   ├── cocoapods.sh            # CocoaPods management with retry logic
│   ├── release-common.sh       # Release-specific shared functions
│   └── ci.sh                   # CI/CD environment support
├── config/                      # Configuration files
│   ├── build.conf              # Build settings and optimization
│   ├── frameworks.conf         # Framework configurations
│   └── environments.conf       # Environment-specific settings
└── plugins/                     # Environment-specific plugins
    ├── local.sh                # Local development optimizations
    ├── github-actions.sh       # GitHub Actions CI support
    └── fastlane.sh             # Fastlane integration
```

## 📈 Version History

### v5.4.0 (Current - Simple Release Notes & Enhanced UX)
- **Simple Release Notes**: New `--release-notes-source simple` for easy bullet point input
- **Auto-Generated Structure**: Automatically creates full release note structure from bullet points
- **Smart Formatting**: Automatic version, date, and environment detection
- **Enhanced UX**: Minimal input required for professional release notes
- **Slack Integration**: Perfect formatting for Slack notifications
- **Documentation Updates**: Comprehensive examples and usage patterns

### v5.3.0 (Release Notes & Slack Notifications)
- **Release Notes System**: Comprehensive release notes generation with multiple sources (git, template, manual, auto)
- **Slack Notifications**: Real-time notifications for all release processes across all environments
- **Template System**: Customizable release notes templates with placeholder replacement
- **Environment Detection**: Smart environment detection for Jenkins, GitHub Actions, and local development
- **Rich Formatting**: Enhanced Slack notifications with emojis, structured data, and smart truncation
- **Testing Suite**: Comprehensive test scripts for both release notes and Slack integration
- **Documentation Consolidation**: Merged all documentation into single comprehensive README

### v5.2.1 (Fixed Release Flow & Dependency Checking)
- **Corrected Release Flow**: Fixed adapter availability checking to occur after ALL adapters are released
- **Proper Dependency Verification**: MSPCore dependencies (MSPSharedLibraries + PrebidAdapter) checked before MSPCore release
- **Optimized Process**: Single specs repository update before dependency checking
- **Sequential Logic**: MSPSharedLibraries → All Adapters (parallel) → Dependency Check → MSPCore

### v5.1.0 (Enhanced Documentation & Library Integration)
- **Consolidated Documentation**: Merged lib README into main documentation
- **Enhanced Library Documentation**: Comprehensive details for all library modules
- **Demo App Builder Documentation**: Detailed usage examples and integration guides
- **Improved Organization**: Better structured library module documentation
- **Single Source of Truth**: Eliminated duplicate documentation files

### v5.0.0 (Modular Release System)
- **Modular Architecture**: Complete rewrite with modular design
- **Dependency-Based Release**: Proper release order with exponential backoff
- **Retry Logic**: Comprehensive retry with exponential backoff
- **DRY Principle**: Shared common library eliminates duplication
- **AmazonAdapter Integration**: Full support for AmazonAdapter
- **HTTP Zip Format**: Modern podspec format for reliability
- **Parallel Adapter Release**: Adapters released in parallel for maximum efficiency (5x faster than sequential)

### v2.0.0 (Enhanced Release)
- **Enhanced release script**: Rollback, backup, and validation
- **Testing framework**: Comprehensive testing capabilities
- **Plugin system**: Environment-specific optimizations
- **Configuration system**: Flexible configuration management

### v1.0.0 (Legacy)
- **Basic build scripts**: Individual framework builds
- **Simple release process**: Manual release management
- **Limited testing**: Basic validation only

## 📞 Support

### Getting Help:
1. **Check documentation**: Review this README
2. **Run test framework**: Validate your environment
3. **Enable verbose mode**: Get detailed error information
4. **Check logs**: Review generated log files
5. **Contact team**: Reach out for additional support

### Reporting Issues:
1. **Include environment**: OS, tools, versions
2. **Provide logs**: Include relevant log files
3. **Describe steps**: Detailed reproduction steps
4. **Test framework output**: Include test results
5. **Expected vs actual**: Clear description of issue

---

**Last Updated:** January 2025  
**Version:** 5.4.0 (Simple Release Notes & Enhanced UX)  
**Maintainer:** MSP iOS SDK Team