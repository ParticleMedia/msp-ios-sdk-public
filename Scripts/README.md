# MSP iOS SDK Scripts Documentation

## Overview

The MSP iOS SDK project now features a comprehensive modular script architecture that provides enhanced build automation, release management, and testing capabilities. This system is designed to be maintainable, extensible, and compatible with various development environments.

## Architecture Overview

```
Scripts/
├── build.sh                 # Unified build script (v2.0.0)
├── release.sh               # Enhanced release script (v2.0.0)
├── lib/                     # Shared library modules
│   ├── common.sh           # Core utilities and functions
│   ├── logging.sh          # Logging and output formatting
│   ├── validation.sh       # Environment and input validation
│   ├── xcode.sh            # Xcode build operations
│   ├── cocoapods.sh        # CocoaPods management
│   └── ci.sh               # CI/CD environment support
├── config/                  # Configuration files
│   ├── build.conf          # Build settings and optimization
│   ├── frameworks.conf     # Framework configurations
│   └── environments.conf   # Environment-specific settings
├── plugins/                 # Environment-specific plugins
│   ├── local.sh            # Local development optimizations
│   ├── github-actions.sh   # GitHub Actions CI support
│   └── fastlane.sh         # Fastlane integration
└── Legacy scripts (backward compatibility)
    ├── buildiOSCoreXCFramework.sh
    ├── buildNovaXCFramework.sh
    └── releaseCocoapod.sh
```

## Core Scripts

### 1. Unified Build Script (`build.sh`)

**Version:** 2.0.0  
**Purpose:** Centralized build automation for all frameworks

### 2. Demo App Builder (`buildDemoApp.sh`)

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

### 3. Build and Test Script (`buildAndTest.sh`)

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

### 4. Enhanced Release Script (`release.sh`)

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

#### Options:
- `--help, -h`: Show help information
- `--version, -v`: Show version information
- `--framework, -f`: Specify framework to build
- `--frameworks`: Specify multiple frameworks
- `--dry-run`: Preview operations without execution
- `--skip-code-sign`: Skip code signing process
- `--status`: Show current build status
- `--info`: Show project information
- `--clean`: Clean build artifacts
- `--clean-all`: Clean all artifacts
- `--verbose`: Enable verbose output

### 2. Enhanced Release Script (`release.sh`)

**Version:** 2.0.0  
**Purpose:** Comprehensive release automation with rollback capabilities

#### Features:
- **Automated validation**: Environment, pod, and version validation
- **Rollback support**: Automatic rollback on failure
- **Backup system**: Pre-release backup and restore capabilities
- **Multi-platform publishing**: GitHub releases and CocoaPods publishing
- **Git integration**: Automatic tag creation and management
- **Error recovery**: Comprehensive error handling and recovery

#### Usage:
```bash
# Release a framework
./Scripts/release.sh MSPiOSCore 1.2.3

# Dry run release
./Scripts/release.sh --dry-run MSPiOSCore 1.2.3

# Release with CocoaPods publishing
PUBLISH_TO_COCOAPODS=true ./Scripts/release.sh MSPiOSCore 1.2.3

# Force release with uncommitted changes
./Scripts/release.sh --force MSPiOSCore 1.2.3

# Create backup
./Scripts/release.sh --backup

# Restore from backup
./Scripts/release.sh --restore backup_directory

# Rollback a release
./Scripts/release.sh --rollback MSPiOSCore 1.2.3
```

#### Options:
- `--help, -h`: Show help information
- `--version, -v`: Show version information
- `--dry-run`: Preview release without execution
- `--force`: Force release even with validation issues
- `--skip-build`: Skip building frameworks
- `--skip-validation`: Skip podspec validation
- `--skip-cocoapods`: Skip CocoaPods publishing
- `--skip-github`: Skip GitHub release creation
- `--publish-cocoapods`: Enable CocoaPods publishing
- `--backup`: Create backup before release
- `--restore`: Restore from backup directory
- `--rollback`: Rollback a specific release
- `--verbose`: Enable verbose output

#### Environment Variables:
- `COCOAPODS_TRUNK_TOKEN`: CocoaPods trunk token for publishing
- `GITHUB_TOKEN`: GitHub token for releases
- `FORCE_RELEASE`: Force release even with validation issues
- `PUBLISH_TO_COCOAPODS`: Enable CocoaPods publishing (default: false)



## Library Modules

### Common Utilities (`lib/common.sh`)
Core utilities and shared functions used across all scripts:
- Environment detection
- Path management
- Error handling
- Utility functions

### Logging System (`lib/logging.sh`)
Structured logging with environment-aware output:
- Color-coded output
- CI/CD integration
- Log levels and filtering
- Structured formatting

### Validation Framework (`lib/validation.sh`)
Comprehensive validation for all inputs and environments:
- Command availability checking
- Path validation
- Xcode environment validation
- Project structure validation

### Xcode Operations (`lib/xcode.sh`)
Advanced Xcode build operations:
- Multi-architecture builds
- XCFramework generation
- Code signing management
- Build optimization

### CocoaPods Management (`lib/cocoapods.sh`)
CocoaPods integration and management:
- Podspec validation
- Publishing automation
- Cache management
- Dependency resolution

### CI/CD Support (`lib/ci.sh`)
CI/CD environment detection and optimization:
- Environment detection
- Performance optimization
- Artifact management
- CI-specific configurations

### Demo App Builder (`lib/demo_app_builder.sh`)
Reusable demo app building functionality:
- Automatic linking mode detection
- Framework and static library building
- CI/CD integration with fallbacks
- Comprehensive error handling

### XCFramework Builder (`lib/xcframework_builder.sh`)
Centralized XCFramework creation:
- Multi-platform framework building
- CI path resolution (handles `/tmp` vs `/private/tmp`)
- Robust framework discovery
- Comprehensive error handling

### Framework Configuration (`lib/framework_config.sh`)
Framework-specific configuration management:
- Build order and dependencies
- Output directory management
- Special build requirements
- Configuration validation

### Color Utilities (`lib/colors.sh`)
Consistent color-coded output:
- Standardized color definitions
- CI/CD compatible output
- Consistent user experience
- Cross-platform compatibility

## Configuration System

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

## Plugin System

### Local Development (`plugins/local.sh`)
Local development optimizations:
- IDE integration
- Developer helpers
- Local build optimizations
- Debugging support

### GitHub Actions (`plugins/github-actions.sh`)
GitHub Actions CI integration:
- Workflow optimization
- Artifact management
- Environment setup
- Reporting integration

### Fastlane Integration (`plugins/fastlane.sh`)
Fastlane automation integration:
- Lane-specific settings
- Build automation
- Release automation
- Reporting integration

## Environment Requirements

### Required Tools:
- **Git**: Version control
- **Xcode**: iOS development tools
- **CocoaPods**: Dependency management
- **Bash**: Shell environment (3.2+)

### Optional Tools:
- **GitHub CLI**: GitHub release automation
- **Fastlane**: Advanced automation
- **Ruby/Bundler**: Dependency management

### Environment Variables:
- `COCOAPODS_TRUNK_TOKEN`: For CocoaPods publishing
- `GITHUB_TOKEN`: For GitHub releases
- `FORCE_RELEASE`: Override validation
- `PUBLISH_TO_COCOAPODS`: Enable publishing
- `SKIP_CODE_SIGN`: Skip code signing
- `VERBOSE`: Enable verbose output

## Best Practices

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

## Troubleshooting

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

### Debug Mode:
Enable verbose output for detailed debugging:
```bash
./Scripts/build.sh --verbose
./Scripts/release.sh --verbose
```

### Log Files:
Scripts generate detailed logs for troubleshooting:
- Build logs: `build_*.log`
- Release logs: `release_*.log`
- Test logs: `test_*.log`

## Migration Guide

### From Legacy Scripts:
1. **Backup existing scripts**: Create backups before migration
2. **Update paths**: Use new script paths and options
3. **Test thoroughly**: Run test framework to validate
4. **Update CI/CD**: Update automation scripts
5. **Document changes**: Update team documentation

### Compatibility:
- **Backward compatible**: Legacy scripts still work
- **Gradual migration**: Migrate one script at a time
- **Fallback support**: Legacy scripts available as fallback

## Contributing

### Development Guidelines:
1. **Follow modular architecture**: Use library modules
2. **Add tests**: Include test cases for new features
3. **Update documentation**: Keep docs current
4. **Test compatibility**: Ensure Bash 3.2+ compatibility
5. **Follow conventions**: Use consistent naming and structure

### Adding New Features:
1. **Create library module**: Add shared functionality
2. **Update configuration**: Add new settings
3. **Add tests**: Include comprehensive testing
4. **Update documentation**: Document new features
5. **Test integration**: Ensure compatibility

## Version History

### v2.0.0 (Current)
- **Modular architecture**: Complete rewrite with modular design
- **Enhanced release script**: Rollback, backup, and validation
- **Testing framework**: Comprehensive testing capabilities
- **Plugin system**: Environment-specific optimizations
- **Configuration system**: Flexible configuration management

### v1.0.0 (Legacy)
- **Basic build scripts**: Individual framework builds
- **Simple release process**: Manual release management
- **Limited testing**: Basic validation only

## Support

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
**Version:** 2.1.0 (Enhanced Demo App & CI Support)  
**Maintainer:** MSP iOS SDK Team
