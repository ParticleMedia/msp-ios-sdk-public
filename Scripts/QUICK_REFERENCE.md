# MSP iOS SDK Scripts - Quick Reference

## 🚀 Quick Start

```bash
# Build all frameworks
./Scripts/build.sh

# Build demo app
./Scripts/buildDemoApp.sh

# Release a framework
./Scripts/release.sh MSPiOSCore 1.2.3

# Check project status
./Scripts/build.sh --status
```

## 📋 Common Commands

### Build Operations
```bash
# Build specific framework
./Scripts/build.sh --framework MSPiOSCore

# Build demo app
./Scripts/buildDemoApp.sh

# Build and test everything
./Scripts/buildAndTest.sh

# Build without code signing
./Scripts/build.sh --skip-code-sign

# Preview build (dry run)
./Scripts/build.sh --dry-run all

# Clean build artifacts
./Scripts/build.sh --clean
```

### Release Operations
```bash
# Release with CocoaPods publishing
PUBLISH_TO_COCOAPODS=true ./Scripts/release.sh MSPiOSCore 1.2.3

# Preview release (dry run)
./Scripts/release.sh --dry-run MSPiOSCore 1.2.3

# Force release with uncommitted changes
./Scripts/release.sh --force MSPiOSCore 1.2.3

# Create backup
./Scripts/release.sh --backup
```

### Project Information
```bash
# Show project status
./Scripts/build.sh --status

# Show project information
./Scripts/build.sh --info

# Show build script help
./Scripts/build.sh --help

# Show release script help
./Scripts/release.sh --help
```

## 🔧 Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SKIP_CODE_SIGN` | Skip code signing | `0` (enabled) |
| `PUBLISH_TO_COCOAPODS` | Enable CocoaPods publishing | `false` |
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

## 🛠️ Troubleshooting

### Common Issues

**"iOS workspace not found"**
```bash
# Ensure you're in project root
cd /path/to/msp-ios-sdk
./Scripts/build.sh
```

**"Required tool not found"**
```bash
# Check environment manually
xcodebuild -version
pod --version
git --version
```

**"Build script syntax errors"**
```bash
# Check Bash version
bash --version
# Should be 3.2+
```

**"Release validation failed"**
```bash
# Check podspec syntax
pod spec lint MSPiOSCore/MSPiOSCore.podspec

# Verify git status
git status
```

### Debug Mode
```bash
# Enable verbose output
./Scripts/build.sh --verbose
./Scripts/release.sh --verbose
```



## 🔄 Migration from Legacy Scripts

| Legacy Command | New Command |
|----------------|-------------|
| `./Scripts/makeBuild.sh` | `./Scripts/build.sh` |
| `./Scripts/buildiOSCoreXCFramework.sh` | `./Scripts/build.sh --framework MSPiOSCore` |
| `./Scripts/buildNovaXCFramework.sh` | `./Scripts/build.sh --framework NovaCore` |
| `./Scripts/releaseCocoapod.sh` | `./Scripts/release.sh` |
| `./Scripts/buildDemoApp.sh` | `./Scripts/buildDemoApp.sh` (new dedicated script) |
| `./Scripts/buildAndTest.sh` | `./Scripts/buildAndTest.sh` (new comprehensive script) |

## 📝 Best Practices

1. **Always use dry-run first**
   ```bash
   ./Scripts/build.sh --dry-run all
   ./Scripts/release.sh --dry-run MSPiOSCore 1.2.3
   ```

2. **Check environment before operations**
   ```bash
   ./Scripts/build.sh --status
   ./Scripts/build.sh --info
   ```

3. **Use appropriate flags for your use case**
   ```bash
   # Development
   ./Scripts/build.sh --skip-code-sign
   
   # Production
   ./Scripts/build.sh
   ```

4. **Create backups before releases**
   ```bash
   ./Scripts/release.sh --backup
   ./Scripts/release.sh MSPiOSCore 1.2.3
   ```

## 🆘 Getting Help

```bash
# Show help for any script
./Scripts/build.sh --help
./Scripts/release.sh --help

# Show version information
./Scripts/build.sh --version
./Scripts/release.sh --version
```

## 📞 Support

- **Documentation**: See `README.md` for detailed documentation
- **Status Check**: Run `./Scripts/build.sh --status` to check project status
- **Logs**: Check generated log files for detailed error information
- **Team**: Contact MSP iOS SDK team for additional support

---

**Last Updated:** January 2025  
**Version:** 2.1.0
