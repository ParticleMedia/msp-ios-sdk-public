# MSP iOS SDK

A comprehensive iOS SDK for mobile advertising and monetization, featuring multiple ad network adapters and a unified interface for developers.

## 🚀 Features

- **Multiple Ad Network Support**: Google, Facebook, InMobi, Mintegral, MobileFuse, Pubmatic, Unity, and more
- **Unified Interface**: Consistent API across all ad networks
- **XCFramework Support**: Modern binary distribution format
- **CocoaPods Integration**: Easy dependency management
- **Comprehensive Testing**: Unit tests and UI tests included
- **CI/CD Pipeline**: Automated building, testing, and releasing

## 🏗️ Architecture

The SDK is organized into several key components:

- **MSPCore**: Core utility framework and common functionality
- **MSPiOSCore**: iOS-specific core framework
- **NovaCore**: Advanced UI and interaction framework
- **Adapters**: Network-specific implementations for various ad platforms
- **MSPDemoApp**: Example application demonstrating SDK usage

## 📦 Installation

### CocoaPods

```ruby
# Core framework
pod 'MSPCore', '~> 0.0.93'

# UI framework
pod 'NovaCore', '~> 0.0.95'

# Specific adapters
pod 'GoogleAdapter', '~> 0.0.1'
pod 'FacebookAdapter', '~> 0.0.1'
pod 'NovaAdapter', '~> 0.0.1'
```

### Manual Installation

1. Clone the repository
2. Run `pod install` to install dependencies
3. Build the XCFrameworks using the provided scripts
4. Integrate the frameworks into your project

## 🔧 Build Scripts

The project includes a comprehensive modular build system for creating XCFrameworks:

### New Modular System (v2.0.0)

The project now features a modern, modular script architecture with:
- **Unified Build Script**: Single command to build all frameworks
- **Enhanced Release Script**: Automated releases with rollback capabilities
- **Demo App Builder**: Dedicated script for building and testing the demo app
- **Library Modules**: Reusable components for common operations
- **Plugin System**: Environment-specific optimizations
- **Configuration Management**: Flexible settings for different environments
- **Backward Compatibility**: Legacy scripts still available

```bash
# Build all frameworks (recommended)
./Scripts/build.sh

# Build specific framework
./Scripts/build.sh MSPiOSCore
./Scripts/build.sh NovaCore

# Build multiple frameworks
./Scripts/build.sh --frameworks "MSPiOSCore NovaCore"

# Build demo app
./Scripts/buildDemoApp.sh

# Development builds (no code signing)
./Scripts/build.sh --skip-code-sign

# Check build status
./Scripts/build.sh --status

# Dry run to preview
./Scripts/build.sh --dry-run all

# Legacy scripts (for backward compatibility)
./Scripts/buildiOSCoreXCFramework.sh
./Scripts/buildNovaXCFramework.sh
```

### NovaCore Resource Packaging

- `NovaCore/NovaCore/Resources` is the single source of truth for all bundle resources (JS, Lottie, etc.); `asset_sync.sh` rebuilds `NBResourceBundle.bundle` from there on every run.
- Do not add files directly into `NBResourceBundle.bundle` expecting them to persist; the bundle is regenerated each build.
- Avoid adding individual resource files to the Xcode target; rely on the bundle to prevent duplicates in the final framework.

## 🚀 CI/CD Pipeline

This project includes a comprehensive CI/CD pipeline using **GitHub Actions** and **Fastlane**:

### Automated Workflows

- **CI Validation**: Automated testing and validation on pull requests
- **Demo App Compilation**: Full demo app building and validation in CI
- **Release Automation**: Automated framework building and publishing
- **Manual Builds**: On-demand framework building with configurable options

### Quick Setup

```bash
# Install dependencies
bundle install
pod install

# Or use the new modular build system
./Scripts/build.sh --info

# Build and test demo app
./Scripts/buildDemoApp.sh
```

### Fastlane Commands

```bash
# Check project status
bundle exec fastlane status

# Run tests
bundle exec fastlane test

# Build frameworks
bundle exec fastlane build_all

# Complete release process
bundle exec fastlane release pod_name:MSPCore version:1.0.0
```

📚 **For detailed CI/CD documentation, see [CI_CD_README.md](CI_CD_README.md)**

## 🧪 Testing

The project includes comprehensive testing:

```bash
# Run all tests
bundle exec fastlane test

# Run specific test targets
xcodebuild test -workspace msp-ios-sdk.xcworkspace -scheme MSPiOSCore
xcodebuild test -workspace msp-ios-sdk.xcworkspace -scheme NovaCore
```

## 📱 Requirements

- **iOS**: 15.0+
- **Xcode**: 15.2+
- **Ruby**: 3.0+ (for CI/CD tools)
- **CocoaPods**: 1.14+

## 🔐 Code Signing

The project supports both development and production builds:

- **Development**: No code signing required, suitable for testing
- **Production**: Code signing enabled for App Store distribution

Set the `SKIP_CODE_SIGN` environment variable to control signing behavior.

## 📊 Project Structure

```
msp-ios-sdk/
├── MSPCore/                 # Core utility framework
├── MSPiOSCore/             # iOS-specific core
├── NovaCore/               # Advanced UI framework
├── Adapters/               # Network-specific adapters
│   ├── GoogleAdapter/
│   ├── FacebookAdapter/
│   ├── NovaAdapter/
│   └── ...
├── MSPDemoApp/             # Example application
├── Scripts/                # Modular build system
│   ├── build.sh            # Unified build script (v2.0.0)
│   ├── release.sh          # Enhanced release script (v2.0.0)
│   ├── buildDemoApp.sh     # Demo app builder script
│   ├── buildAndTest.sh     # Build and test script
│   ├── lib/                # Shared library modules
│   ├── config/             # Configuration files
│   ├── plugins/            # Environment plugins
│   └── Legacy scripts      # Backward compatibility
├── fastlane/               # CI/CD automation
├── .github/workflows/      # GitHub Actions workflows
└── Gemfile                 # Ruby dependencies
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Development Workflow

```bash
# Setup development environment
bundle exec fastlane setup_dev

# Make changes and test
bundle exec fastlane test

# Build and verify
bundle exec fastlane build_all

# Check project status
bundle exec fastlane status
```

## 📚 Documentation

- [Build Scripts Documentation](Scripts/README.md) - Complete guide to the modular build system
- [Quick Reference](Scripts/QUICK_REFERENCE.md) - Quick commands and troubleshooting
- [CI/CD Pipeline Guide](CI_CD_README.md) - Complete CI/CD automation guide
- [API Documentation](MSPCore/MSPCore.docc/) - Framework API reference
- [Example App](MSPDemoApp/) - Usage examples and demos

## 🔗 Links

- **Repository**: [GitHub](https://github.com/ParticleMedia/msp-ios-sdk)
- **Public Repository**: [msp-ios-sdk-public](https://github.com/ParticleMedia/msp-ios-sdk-public)
- **Issues**: [GitHub Issues](https://github.com/ParticleMedia/msp-ios-sdk/issues)

## 📄 License

Copyright © 2025 NewsBreak. All rights reserved.

---

**Maintainer**: MSP iOS SDK Team  
**Last Updated**: January 2025  
**Version**: 2.1.0 (Enhanced CI/CD & Demo App Support)
