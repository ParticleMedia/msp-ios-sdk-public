# Jenkins Complete Setup Guide - MSP iOS SDK

This comprehensive guide covers both **Build** and **Release** Jenkins jobs for the MSP iOS SDK project, providing complete CI/CD automation using existing script infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Build Job Setup](#build-job-setup)
4. [Release Job Setup](#release-job-setup)
5. [Usage Examples](#usage-examples)
6. [Troubleshooting](#troubleshooting)
7. [Security & Maintenance](#security--maintenance)
8. [Integration Details](#integration-details)

## Overview

The Jenkins setup provides two complementary pipelines:

### **Build Job** (`MSPCore-Build`)
- **Purpose**: Build and validate MSPCore framework
- **Pipeline**: `Jenkinsfile`
- **Script**: `Scripts/buildMSPCore.sh`
- **Features**: Validation, building, testing, artifact collection

### **Release Job** (`MSP-iOS-SDK-Release`)
- **Purpose**: Release pods to CocoaPods and GitHub
- **Pipeline**: `Jenkinsfile.release`
- **Scripts**: `Scripts/release.sh` (single pod) + `Scripts/release-sequential.sh` (dependencies)
- **Features**: Single pod release, sequential release, dry-run, rollback, publishing

### **Key Benefits**
- ✅ **Complete Script Reuse**: Leverages existing `Scripts/` infrastructure
- ✅ **Automated CI/CD**: Build validation and release automation
- ✅ **Secure Credentials**: Jenkins credential store integration
- ✅ **Comprehensive Logging**: Detailed error reporting and artifact collection
- ✅ **Rollback Support**: Automatic failure recovery and manual rollback

## Prerequisites

### Jenkins Server Requirements
- **Jenkins**: Version 2.400+ (with Pipeline plugin)
- **Required Plugins**:
  - Pipeline (workflow-job)
  - Git
  - GitHub Integration
  - AnsiColor (for better log output)
  - Build Timeout
  - Timestamper
  - Credentials Binding

### Build Agent Requirements
- **macOS**: 12.0+ (Monterey or later)
- **Xcode**: 14.0+ with command line tools
- **CocoaPods**: Latest version
- **Git**: Latest version
- **GitHub CLI**: Latest version (for releases)
- **Node.js**: 16+ (for some build tools)

### Environment Setup
```bash
# Install required tools
xcode-select --install
sudo gem install cocoapods
brew install git gh node

# Verify installations
xcodebuild -version
pod --version
git --version
gh --version
node --version
```

## Build Job Setup

### Overview
The build job validates, builds, and tests the MSPCore framework using the existing `Scripts/buildMSPCore.sh` script.

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

```bash
# Import job configuration
curl -X POST -H "Content-Type: application/xml" \
     -d @jenkins-job-config.xml \
     "http://your-jenkins-server/createItem?name=MSPCore-Build"
```

### Build Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `BUILD_TYPE` | Choice | `pr-validation` | Type of build (pr-validation, release, manual) |
| `FRAMEWORK_NAME` | String | `MSPCore` | Framework to build |
| `SKIP_CODE_SIGN` | Boolean | `true` | Skip code signing (recommended for CI) |
| `CLEAN_BUILD` | Boolean | `true` | Clean build artifacts before building |
| `PUBLISH_ARTIFACTS` | Boolean | `false` | Publish build artifacts |
| `CUSTOM_VERSION` | String | `` | Custom version override (optional) |

### Build Process

#### Pipeline Stages
1. **Checkout**: Clone repository and get build information
2. **Environment Setup**: Verify tools and create directories
3. **Dependency Resolution**: Install CocoaPods dependencies
4. **Build Dependencies**: Build MSPiOSCore and NovaCore (if needed)
5. **Validate MSPCore**: Validate MSPCore.podspec
6. **Build MSPCore**: Build the MSPCore framework
7. **Test MSPCore**: Run tests if available
8. **Collect Artifacts**: Archive build artifacts (if enabled)

#### Build Types
- **PR Validation**: Validates podspec, builds framework, runs tests
- **Release Build**: Full validation, testing, and artifact publishing
- **Manual Build**: Customizable parameters and on-demand execution

## Release Job Setup

### Overview
The release job handles complete pod releases using the existing `Scripts/release.sh` script, supporting release, dry-run, and rollback operations.

### Credential Setup

#### 1. CocoaPods Trunk Token
```bash
# Get your trunk token
pod trunk me

# Or register if you don't have one
pod trunk register your-email@example.com 'Your Name' --description='Jenkins CI'
```

#### 2. GitHub Token
Create a GitHub Personal Access Token with these permissions:
- `repo` (Full control of private repositories)
- `write:packages` (Write packages to GitHub Package Registry)

#### 3. Jenkins Credential Configuration
1. **Go to Jenkins Dashboard**
2. **Click "Manage Jenkins" → "Manage Credentials"**
3. **Add CocoaPods Credentials**:
   - **Kind**: Secret text
   - **Secret**: Your CocoaPods trunk token
   - **ID**: `cocoapods-trunk-token`
   - **Description**: CocoaPods trunk token for publishing

4. **Add GitHub Credentials**:
   - **Kind**: Secret text
   - **Secret**: Your GitHub token
   - **ID**: `github-token`
   - **Description**: GitHub token for releases

### Method 1: Using Jenkinsfile.release (Recommended)

1. **Create New Pipeline Job**:
   - Go to Jenkins Dashboard
   - Click "New Item"
   - Enter job name: `MSP-iOS-SDK-Release`
   - Select "Pipeline"
   - Click "OK"

2. **Configure Pipeline**:
   - In "Pipeline" section:
     - Definition: "Pipeline script from SCM"
     - SCM: "Git"
     - Repository URL: `https://github.com/ParticleMedia/msp-ios-sdk-public.git`
     - Credentials: Add GitHub credentials if needed
     - Branch: `*/main` (or your target branch)
     - Script Path: `Jenkinsfile.release`

3. **Configure Build Triggers**:
   - Poll SCM: `H/30 * * * *` (every 30 minutes)
   - **Note**: Releases are typically manual, so polling is optional

4. **Save and Test**:
   - Click "Save"
   - Click "Build with Parameters" to test

### Method 2: Using Job Configuration XML

```bash
# Import job configuration
curl -X POST -H "Content-Type: application/xml" \
     -d @jenkins-release-job-config.xml \
     "http://your-jenkins-server/createItem?name=MSP-iOS-SDK-Release"
```

### Release Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `RELEASE_TYPE` | Choice | `release` | Type of release operation |
| `POD_NAME` | Choice | - | Pod to release (MSPiOSCore, NovaCore, MSPCore, Sequential) |
| `VERSION` | String | - | Version to release (e.g., 1.2.3) |
| `PUBLISH_TO_COCOAPODS` | Boolean | `false` | Publish to CocoaPods trunk |
| `CREATE_GITHUB_RELEASE` | Boolean | `true` | Create GitHub release |
| `SKIP_BUILD` | Boolean | `false` | Skip building frameworks |
| `SKIP_VALIDATION` | Boolean | `false` | Skip podspec validation |
| `FORCE_RELEASE` | Boolean | `false` | Force release with validation issues |
| `ROLLBACK_VERSION` | String | - | Version to rollback (rollback only) |
| `RELEASE_NOTES` | Text | - | Release notes for GitHub |

### Sequential Release Process

When `POD_NAME` is set to `Sequential`, the release process follows this order:

1. **FacebookAdapter** - Released first
2. **GoogleAdapter** - Released second  
3. **NovaAdapter** - Released third
4. **MSPCore** - Released last (depends on all adapters)

**Key Features:**
- **Version Consistency**: All pods must have the same version number
- **CocoaPods Sync**: Waits for each adapter to be available on CocoaPods before proceeding
- **Exponential Backoff**: Uses exponential backoff (30s → 45s → 67s → ... → max 10min) for sync verification
- **Error Handling**: Stops on first failure and provides rollback instructions
- **Comprehensive Logging**: Detailed logs for each step of the process

### Release Process

#### Release Types
1. **Release (Full Release)**:
   - Pre-release validation
   - Environment setup
   - Dependency resolution
   - Framework building (if not skipped)
   - Podspec validation (if not skipped)
   - Git tag creation and push
   - GitHub release creation
   - CocoaPods publishing (if enabled)
   - Artifact collection

2. **Dry Run**:
   - Pre-release validation
   - Environment setup
   - Shows what would be released
   - No actual changes made

3. **Rollback**:
   - Delete git tag
   - Delete GitHub release
   - Clean up artifacts

## Usage Examples

### Build Job Examples

#### 1. PR Validation Build
**Parameters**:
- `BUILD_TYPE`: `pr-validation`
- `FRAMEWORK_NAME`: `MSPCore`
- `SKIP_CODE_SIGN`: `true`
- `CLEAN_BUILD`: `true`

**Result**: Validates podspec, builds framework, runs tests

#### 2. Release Build
**Parameters**:
- `BUILD_TYPE`: `release`
- `FRAMEWORK_NAME`: `MSPCore`
- `PUBLISH_ARTIFACTS`: `true`

**Result**: Full validation, testing, and artifact publishing

#### 3. Manual Build
**Parameters**:
- `BUILD_TYPE`: `manual`
- `FRAMEWORK_NAME`: `MSPCore`
- `CUSTOM_VERSION`: `1.2.3`

**Result**: Custom build with specific version

### Release Job Examples

#### 1. Sequential Release Version 1.2.3
**Parameters**:
- `RELEASE_TYPE`: `release`
- `POD_NAME`: `Sequential`
- `VERSION`: `1.2.3`
- `PUBLISH_TO_COCOAPODS`: `true`
- `CREATE_GITHUB_RELEASE`: `true`

**Result**: Releases FacebookAdapter → GoogleAdapter → NovaAdapter → MSPCore with CocoaPods sync verification

#### 2. Single Pod Release MSPCore Version 1.2.3
**Parameters**:
- `RELEASE_TYPE`: `release`
- `POD_NAME`: `MSPCore`
- `VERSION`: `1.2.3`
- `PUBLISH_TO_COCOAPODS`: `true`
- `CREATE_GITHUB_RELEASE`: `true`

**Result**: Single pod release with CocoaPods publishing and GitHub release

#### 3. Dry Run Sequential Release
**Parameters**:
- `RELEASE_TYPE`: `dry-run`
- `POD_NAME`: `Sequential`
- `VERSION`: `2.0.0`

**Result**: Preview what would be released in sequential order without making changes

#### 4. Rollback Sequential Release
**Parameters**:
- `RELEASE_TYPE`: `rollback`
- `POD_NAME`: `Sequential`
- `ROLLBACK_VERSION`: `1.2.3`

**Result**: Rollback all pods in the sequential release

#### 5. Release Without CocoaPods Publishing
**Parameters**:
- `RELEASE_TYPE`: `release`
- `POD_NAME`: `NovaCore`
- `VERSION`: `1.1.0`
- `PUBLISH_TO_COCOAPODS`: `false`
- `CREATE_GITHUB_RELEASE`: `true`

**Result**: Release with GitHub release but no CocoaPods publishing

## Troubleshooting

### Common Build Issues

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

### Common Release Issues

#### 1. "CocoaPods trunk token not found"
```bash
# Solution: Add credential to Jenkins
# Go to Jenkins → Manage Credentials → Add Secret Text
# ID: cocoapods-trunk-token
# Secret: your-trunk-token
```

#### 2. "GitHub CLI not authenticated"
```bash
# Solution: Add GitHub token to Jenkins
# Go to Jenkins → Manage Credentials → Add Secret Text
# ID: github-token
# Secret: your-github-token
```

#### 3. "Version already exists"
```bash
# Solution: Use a different version number
# Or use --force flag if intentional
```

#### 4. "Git working directory not clean"
```bash
# Solution: Commit or stash changes
# Or use --force flag if intentional
```

#### 5. "Podspec validation failed"
```bash
# Solution: Fix podspec issues
# Or use --skip-validation flag (not recommended)
```

### Debug Mode

Enable verbose output for debugging:

1. **For Build Jobs**:
   - Set `BUILD_TYPE` to "manual"
   - Add `--verbose` flag to build script

2. **For Release Jobs**:
   - Set `FORCE_RELEASE` to `true` for testing
   - Use `dry-run` mode first

### Log Analysis

Check these log locations:
- Jenkins console output
- `artifacts/` directory (build jobs)
- `release-artifacts/` directory (release jobs)
- Build agent system logs
- GitHub release logs (release jobs)
- CocoaPods publishing logs (release jobs)

## Security & Maintenance

### Credential Management
- **Never hardcode tokens** in scripts or configuration
- **Use Jenkins credential store** for all sensitive data
- **Rotate tokens regularly**
- **Limit token permissions** to minimum required

### Access Control
- **Restrict job access** to authorized users only
- **Use Jenkins role-based access control**
- **Audit build and release activities**
- **Monitor for unauthorized operations**

### Build Validation
- **Always test with dry-run** before actual release
- **Validate version numbers** carefully
- **Review release notes** before publishing
- **Monitor build and release success/failure**

### Regular Maintenance
- **Update Jenkins plugins**
- **Update build tools** (Xcode, CocoaPods, GitHub CLI)
- **Clean up old artifacts**
- **Monitor disk space**
- **Rotate credentials**

### Performance Optimization
- **Use build caching**
- **Optimize build scripts**
- **Monitor resource usage**
- **Scale build agents as needed**

## Integration Details

### Scripts Used

#### Build Job Integration
- `Scripts/build.sh`: Unified build script
- `Scripts/buildiOSCoreXCFramework.sh`: MSPiOSCore build
- `Scripts/buildNovaXCFramework.sh`: NovaCore build
- `Scripts/buildMSPCore.sh`: MSPCore-specific build script

#### Release Job Integration
- `Scripts/release.sh`: Single pod release script (reused completely)
- `Scripts/release-sequential.sh`: Sequential release script for dependencies
- `Scripts/build.sh`: Framework building
- `Scripts/buildiOSCoreXCFramework.sh`: MSPiOSCore build
- `Scripts/buildNovaXCFramework.sh`: NovaCore build

### Configuration Files
- `Scripts/config/frameworks.conf`: Framework configurations
- `Scripts/lib/ci.sh`: CI/CD integration
- `Scripts/lib/common.sh`: Common utilities

### Environment Detection
Both jobs automatically detect Jenkins environment and apply optimizations:
- CI-specific build settings
- Performance monitoring
- Artifact collection
- Error reporting

### Environment Variables

#### Build Job Environment
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

# Build artifacts
ARTIFACTS_DIR=${WORKSPACE}/artifacts
```

#### Release Job Environment
```bash
# CI Environment
CI=true
JENKINS_URL=${env.JENKINS_URL}

# Release Configuration
PUBLISH_TO_COCOAPODS=true/false
FORCE_RELEASE=true/false

# Paths
WORKSPACE_PATH=${WORKSPACE}
SCRIPTS_PATH=${WORKSPACE}/Scripts

# CocoaPods
COCOAPODS_DISABLE_STATS=true
COCOAPODS_CACHE_DIR=${WORKSPACE}/.cocoapods_cache

# Xcode
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Build artifacts
ARTIFACTS_DIR=${WORKSPACE}/release-artifacts

# Credentials (from Jenkins credential store)
COCOAPODS_TRUNK_TOKEN=***
GITHUB_TOKEN=***
```

## Support

### Getting Help
1. Check Jenkins console output
2. Review build/release logs
3. Test scripts locally
4. Check environment setup
5. Contact development team

### Reporting Issues
When reporting issues, include:
- Jenkins version and plugins
- Build agent environment
- Error logs and stack traces
- Build/release parameters used
- Steps to reproduce
- Expected vs actual behavior

---

**Last Updated**: January 2025  
**Version**: 2.0.0  
**Maintainer**: MSP iOS SDK Team  
**Files**: Jenkinsfile, Jenkinsfile.release, jenkins-job-config.xml, jenkins-release-job-config.xml
