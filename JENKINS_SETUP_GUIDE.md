# Jenkins Setup Guide for MSPCore Build

This guide provides complete instructions for setting up Jenkins to build MSPCore.podspec using the existing script infrastructure.

## Overview

The Jenkins setup includes:
- **Jenkinsfile**: Complete pipeline definition with stages for validation, building, and testing
- **buildMSPCore.sh**: Dedicated script for MSPCore builds
- **Job Configuration**: XML configuration for Jenkins job setup
- **CI Integration**: Full integration with existing script system

## Prerequisites

### Jenkins Server Requirements
- **Jenkins**: Version 2.400+ (with Pipeline plugin)
- **Plugins Required**:
  - Pipeline (workflow-job)
  - Git
  - GitHub Integration
  - AnsiColor (for better log output)
  - Build Timeout
  - Timestamper

### Build Agent Requirements
- **macOS**: 12.0+ (Monterey or later)
- **Xcode**: 14.0+ with command line tools
- **CocoaPods**: Latest version
- **Git**: Latest version
- **Node.js**: 16+ (for some build tools)

### Environment Setup
```bash
# Install required tools
xcode-select --install
sudo gem install cocoapods
brew install git node

# Verify installations
xcodebuild -version
pod --version
git --version
node --version
```

## Jenkins Job Setup

### Method 1: Using Jenkinsfile (Recommended)

1. **Create New Pipeline Job**:
   - Go to Jenkins Dashboard
   - Click "New Item"
   - Enter job name: `MSPCore-Build`
   - Select "Pipeline"
   - Click "OK"

2. **Configure Pipeline**:
   - In "Pipeline" section:
     - Definition: "Pipeline script from SCM"
     - SCM: "Git"
     - Repository URL: `https://github.com/ParticleMedia/msp-ios-sdk-public.git`
     - Credentials: Add GitHub credentials if needed
     - Branch: `*/main` (or your target branch)
     - Script Path: `Jenkinsfile`

3. **Configure Build Triggers**:
   - GitHub hook trigger for GITScm polling
   - Poll SCM: `H/15 * * * *` (every 15 minutes)

4. **Save and Test**:
   - Click "Save"
   - Click "Build Now" to test

### Method 2: Using Job Configuration XML

1. **Import Job Configuration**:
   ```bash
   # Copy the jenkins-job-config.xml to your Jenkins server
   curl -X POST -H "Content-Type: application/xml" \
        -d @jenkins-job-config.xml \
        "http://your-jenkins-server/createItem?name=MSPCore-Build"
   ```

2. **Update Repository URL**:
   - Edit the job configuration
   - Update the Git repository URL to your actual repository
   - Update credentials if needed

## Configuration Details

### Build Parameters

The Jenkins job supports the following parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `BUILD_TYPE` | Choice | `pr-validation` | Type of build (pr-validation, release, manual) |
| `FRAMEWORK_NAME` | String | `MSPCore` | Framework to build |
| `SKIP_CODE_SIGN` | Boolean | `true` | Skip code signing (recommended for CI) |
| `CLEAN_BUILD` | Boolean | `true` | Clean build artifacts before building |
| `PUBLISH_ARTIFACTS` | Boolean | `false` | Publish build artifacts |
| `CUSTOM_VERSION` | String | `` | Custom version override (optional) |

### Environment Variables

The pipeline sets up the following environment variables:

```bash
# CI Environment
CI=true
JENKINS_URL=${env.JENKINS_URL}

# Build Configuration
SKIP_CODE_SIGN=1
CLEAN_BUILD=1

# Paths
WORKSPACE_PATH=${WORKSPACE}
SCRIPTS_PATH=${WORKSPACE}/Scripts

# CocoaPods
COCOAPODS_DISABLE_STATS=true
COCOAPODS_CACHE_DIR=${WORKSPACE}/.cocoapods_cache

# Xcode
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
XCODE_XCCONFIG_FILE=${WORKSPACE}/ci.xcconfig

# Build artifacts
ARTIFACTS_DIR=${WORKSPACE}/artifacts
```

## Build Process

### Pipeline Stages

1. **Checkout**: Clone repository and get build information
2. **Environment Setup**: Verify tools and create directories
3. **Dependency Resolution**: Install CocoaPods dependencies
4. **Build Dependencies**: Build MSPiOSCore and NovaCore (if needed)
5. **Validate MSPCore**: Validate MSPCore.podspec
6. **Build MSPCore**: Build the MSPCore framework
7. **Test MSPCore**: Run tests if available
8. **Collect Artifacts**: Archive build artifacts (if enabled)

### Build Types

#### PR Validation Build
- Validates MSPCore podspec
- Builds framework
- Runs tests
- No artifact publishing

#### Release Build
- Builds all dependencies
- Full validation and testing
- Publishes artifacts
- Comprehensive reporting

#### Manual Build
- Customizable parameters
- On-demand execution
- Full control over build process

## Troubleshooting

### Common Issues

#### 1. "Xcode command line tools not found"
```bash
# Solution: Install Xcode command line tools
xcode-select --install
```

#### 2. "CocoaPods not found"
```bash
# Solution: Install CocoaPods
sudo gem install cocoapods
```

#### 3. "Workspace not found"
```bash
# Solution: Ensure you're in the project root
cd /path/to/msp-ios-sdk
ls -la msp-ios-sdk.xcworkspace
```

#### 4. "Dependencies not found"
```bash
# Solution: Install CocoaPods dependencies
pod install
```

#### 5. "Build timeout"
- Increase Jenkins job timeout
- Check build agent resources
- Optimize build process

### Debug Mode

Enable verbose output for debugging:

```bash
# In Jenkins job parameters
# Set BUILD_TYPE to "manual"
# Add --verbose flag to build script
```

### Log Analysis

Check these log locations:
- Jenkins console output
- `xcodebuild*.log` files
- `artifacts/` directory
- Build agent system logs

## Advanced Configuration

### Custom Build Agents

Configure Jenkins agents with specific labels:

```bash
# In Jenkins agent configuration
# Add label: ios-build-agent
# Ensure Xcode and tools are installed
```

### Caching

Optimize builds with caching:

```bash
# CocoaPods cache
COCOAPODS_CACHE_DIR=${WORKSPACE}/.cocoapods_cache

# DerivedData cache
# Configure in Xcode build settings
```

### Notifications

Configure build notifications:

```bash
# Email notifications
# Slack integration
# GitHub status updates
```

## Integration with Existing Scripts

The Jenkins setup integrates seamlessly with your existing script infrastructure:

### Scripts Used
- `Scripts/build.sh`: Unified build script
- `Scripts/buildiOSCoreXCFramework.sh`: MSPiOSCore build
- `Scripts/buildNovaXCFramework.sh`: NovaCore build
- `Scripts/buildMSPCore.sh`: MSPCore-specific build script

### Configuration Files
- `Scripts/config/frameworks.conf`: Framework configurations
- `Scripts/lib/ci.sh`: CI/CD integration
- `Scripts/lib/common.sh`: Common utilities

### Environment Detection
The scripts automatically detect Jenkins environment and apply optimizations:
- CI-specific build settings
- Performance monitoring
- Artifact collection
- Error reporting

## Monitoring and Maintenance

### Build Monitoring
- Monitor build success rates
- Track build times
- Analyze failure patterns
- Optimize build performance

### Regular Maintenance
- Update Jenkins plugins
- Update build tools (Xcode, CocoaPods)
- Clean up old build artifacts
- Monitor disk space

### Performance Optimization
- Use build caching
- Optimize build scripts
- Monitor resource usage
- Scale build agents as needed

## Support

### Getting Help
1. Check Jenkins console output
2. Review build logs
3. Test scripts locally
4. Check environment setup
5. Contact development team

### Reporting Issues
When reporting issues, include:
- Jenkins version and plugins
- Build agent environment
- Error logs and stack traces
- Steps to reproduce
- Expected vs actual behavior

---

**Last Updated**: January 2025  
**Version**: 1.0.0  
**Maintainer**: MSP iOS SDK Team
