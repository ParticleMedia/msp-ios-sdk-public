# MSP iOS SDK - CI/CD Pipeline

This document describes the automated CI/CD pipeline for the MSP iOS SDK using **GitHub Actions** and **Fastlane**.

## 🚀 Overview

The CI/CD pipeline automates:
- **Testing**: Automated testing on pull requests
- **Building**: XCFramework generation with optional code signing
- **Validation**: CocoaPods spec validation
- **Releasing**: Automated GitHub releases and CocoaPods publishing
- **Quality**: Code linting and formatting checks

## 🏗️ Architecture

```
GitHub Actions (CI/CD Infrastructure)
    ↓
Fastlane (iOS Automation)
    ↓
Existing Build Scripts (XCFramework Generation)
    ↓
Output: XCFrameworks, GitHub Releases, CocoaPods
```

## 📋 Prerequisites

### Local Development Setup
1. **Ruby 3.0+** installed
2. **Bundler** for Ruby dependency management
3. **Xcode 15.2+** for iOS development
4. **CocoaPods** for dependency management

### GitHub Repository Setup
1. **GitHub Actions** enabled
2. **Repository secrets** configured (see [Secrets Configuration](#secrets-configuration))
3. **Branch protection rules** (recommended)

## 🛠️ Installation

### 1. Install Ruby Dependencies
```bash
# Install all Ruby dependencies including Fastlane
bundle install
```

### 2. Verify Installation
```bash
# Check Fastlane installation
bundle exec fastlane --version

# Check project status
bundle exec fastlane status
```

## 🔧 Fastlane Lanes

### Core Lanes

#### `test`
Runs all unit tests for the SDK frameworks.
```bash
bundle exec fastlane test
```

#### `build_all`
Builds all XCFrameworks (MSPiOSCore and NovaCore).
```bash
bundle exec fastlane build_all
```

#### `build_msp_ios_core`
Builds only MSPiOSCore XCFramework.
```bash
bundle exec fastlane build_msp_ios_core
```

#### `build_nova_core`
Builds only NovaCore XCFramework.
```bash
bundle exec fastlane build_nova_core
```

#### `validate_podspecs`
Validates all CocoaPods spec files.
```bash
bundle exec fastlane validate_podspecs
```

#### `release`
Complete release process for a specific pod.
```bash
bundle exec fastlane release pod_name:MSPCore version:1.0.0
```

### Utility Lanes

#### `setup_dev`
Sets up the development environment.
```bash
bundle exec fastlane setup_dev
```

#### `clean`
Cleans build artifacts and CocoaPods cache.
```bash
bundle exec fastlane clean
```

#### `status`
Shows current project status and framework information.
```bash
bundle exec fastlane status
```

## 🔄 GitHub Actions Workflows

### 1. CI - Pull Request Validation (`ci.yml`)
**Triggers**: Pull requests, pushes to main/develop
**Purpose**: Validate code quality and build success

**Job Structure**:
- **`validate`**: Builds XCFrameworks and runs core validation
- **`demo-app`**: Compiles and validates the demo app using built XCFrameworks

**Features**:
- ✅ Ruby dependency installation
- ✅ CocoaPods dependency installation
- ✅ Podspec validation
- ✅ Unit test execution
- ✅ Framework building (development mode)
- ✅ XCFramework creation with CI optimizations
- ✅ Demo app compilation and validation
- ✅ SwiftProtobuf compatibility fixes
- ✅ Artifact upload and sharing between jobs
- ✅ Code quality checks (RuboCop, SwiftFormat)

### 2. Release - Automated Publishing (`release.yml`)
**Triggers**: GitHub releases, manual workflow dispatch
**Purpose**: Automated publishing and distribution

### 3. Manual Build - On-Demand (`manual-build.yml`)
**Triggers**: Manual workflow dispatch
**Purpose**: On-demand framework building

**Features**:
- 🚀 Production framework building
- 🔒 Code signing support
- 📦 Podspec validation
- 🎯 GitHub release creation
- 📱 CocoaPods trunk publishing
- 📊 Artifact management

**Features**:
- 🎛️ Framework selection (all, MSPiOSCore, NovaCore)
- 🔐 Optional code signing
- 📤 Configurable artifact upload
- 📊 Build summary and reporting

## 🔧 CI-Specific Features

### XCFramework Building
- **CI Optimizations**: Automatic detection and optimization for CI environment
- **Path Resolution**: Handles CI path issues (e.g., `/tmp` vs `/private/tmp`)
- **Artifact Sharing**: XCFrameworks built in `validate` job shared with `demo-app` job

### SwiftProtobuf Compatibility
- **Automatic Fixes**: CI automatically fixes `nonisolated(unsafe)` syntax issues
- **Version Compatibility**: Handles SwiftProtobuf 1.31.0 compatibility with Xcode 15.2
- **Fallback Validation**: Graceful fallback to structure validation if compilation fails

### Demo App Validation
- **Full Compilation**: Attempts full demo app compilation in CI
- **Dependency Verification**: Ensures XCFrameworks are properly linked
- **Structure Validation**: Fallback validation when compilation fails

## 🔐 Secrets Configuration

Configure these secrets in your GitHub repository settings:

### Required Secrets
```yaml
# Code signing for production builds
CODE_SIGNING_P12: "base64-encoded-p12-file"
CODE_SIGNING_PASSWORD: "p12-file-password"

# CocoaPods publishing
COCOAPODS_TRUNK_TOKEN: "your-cocoapods-token"
```

### Optional Secrets
```yaml
# Apple Developer credentials
APPLE_ID: "your.apple.id@example.com"
APPLE_ID_PASSWORD: "your-apple-id-password"

# Notification services
SLACK_WEBHOOK_URL: "slack-webhook-url"
```

## 📱 Usage Examples

### Local Development
```bash
# Setup environment
bundle exec fastlane setup_dev

# Run tests
bundle exec fastlane test

# Build frameworks (development)
bundle exec fastlane build_all

# Check status
bundle exec fastlane status
```

### Automated Release
```bash
# Complete release process
bundle exec fastlane release pod_name:MSPCore version:1.0.0

# Create GitHub release only
bundle exec fastlane create_github_release pod_name:MSPCore version:1.0.0

# Publish to CocoaPods only
bundle exec fastlane publish_to_cocoapods pod_name:MSPCore version:1.0.0
```

### Manual GitHub Actions
1. Go to **Actions** tab in GitHub
2. Select **Manual Build** workflow
3. Click **Run workflow**
4. Configure options:
   - Framework: `all`, `MSPiOSCore`, or `NovaCore`
   - Code signing: `true` or `false`
   - Upload artifacts: `true` or `false`

## 🔍 Troubleshooting

### Common Issues

#### Ruby Version Mismatch
```bash
# Check Ruby version
ruby --version

# Use correct Ruby version
rbenv local 3.0.0  # or rvm use 3.0.0
```

#### Bundle Install Issues
```bash
# Clear bundle cache
bundle clean --force

# Reinstall dependencies
bundle install
```

#### Fastlane Command Not Found
```bash
# Use bundle exec
bundle exec fastlane --version

# Or install globally
gem install fastlane
```

#### Code Signing Issues
```bash
# Use development mode (no code signing)
SKIP_CODE_SIGN=1 bundle exec fastlane build_all
```

### Debug Mode
```bash
# Enable Fastlane debug output
FASTLANE_DEBUG=1 bundle exec fastlane build_all

# Verbose output
bundle exec fastlane build_all --verbose
```

## 📚 Additional Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [CocoaPods Documentation](https://guides.cocoapods.org/)
- [iOS Code Signing Guide](https://developer.apple.com/support/code-signing/)

## 🤝 Contributing

### Adding New Lanes
1. Add lane definition in `fastlane/Fastfile`
2. Update this documentation
3. Test locally before committing

### Modifying Workflows
1. Update workflow files in `.github/workflows/`
2. Test with pull requests
3. Update documentation accordingly

### Best Practices
- Always use `bundle exec` for Fastlane commands
- Test lanes locally before pushing
- Keep secrets secure and never commit them
- Use semantic versioning for releases
- Document new features and changes

## 📊 Monitoring and Metrics

### Workflow Status
- Monitor workflow runs in GitHub Actions tab
- Set up notifications for failures
- Track build times and success rates

### Build Artifacts
- XCFrameworks are uploaded as artifacts
- Retention period: 7 days (CI), 30 days (Release)
- Download artifacts for local testing

### Performance Optimization
- Use GitHub-hosted runners for faster builds
- Cache Ruby dependencies and CocoaPods
- Parallel job execution where possible

---

**Last Updated**: January 2025  
**Version**: 1.1.0 (Enhanced CI Workflow)  
**Maintainer**: MSP iOS SDK Team

