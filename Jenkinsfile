#!/usr/bin/env groovy

/**
 * MSP iOS SDK Jenkins Pipeline
 * 
 * This pipeline builds MSPCore and its dependencies using the modular script system.
 * It supports both pull request validation and release builds.
 * 
 * Pipeline Features:
 * - Automatic environment detection and configuration
 * - Dependency management (MSPiOSCore, NovaCore)
 * - Podspec validation and testing
 * - Artifact collection and archiving
 * - Build status reporting
 * - Performance monitoring
 * 
 * Usage:
 * - PR builds: Validates MSPCore and dependencies
 * - Release builds: Full build with artifact publishing
 * - Manual builds: On-demand builds with custom parameters
 */

pipeline {
    agent {
        label 'ios-build-agent' // Configure this label in Jenkins
    }
    
    options {
        // Build retention
        buildDiscarder(logRotator(numToKeepStr: '10'))
        
        // Timeout
        timeout(time: 60, unit: 'MINUTES')
        
        // Skip default checkout
        skipDefaultCheckout()
        
        // Timestamps
        timestamps()
        
        // AnsiColor for better log output
        ansiColor('xterm')
    }
    
    parameters {
        choice(
            name: 'BUILD_TYPE',
            choices: ['pr-validation', 'release', 'manual'],
            description: 'Type of build to perform'
        )
        
        string(
            name: 'FRAMEWORK_NAME',
            defaultValue: 'MSPCore',
            description: 'Framework to build (default: MSPCore)'
        )
        
        booleanParam(
            name: 'SKIP_CODE_SIGN',
            defaultValue: true,
            description: 'Skip code signing (recommended for CI)'
        )
        
        booleanParam(
            name: 'CLEAN_BUILD',
            defaultValue: true,
            description: 'Clean build artifacts before building'
        )
        
        booleanParam(
            name: 'PUBLISH_ARTIFACTS',
            defaultValue: false,
            description: 'Publish build artifacts'
        )
        
        string(
            name: 'CUSTOM_VERSION',
            defaultValue: '',
            description: 'Custom version override (optional)'
        )
    }
    
    environment {
        // CI Environment
        CI = 'true'
        JENKINS_URL = "${env.JENKINS_URL}"
        
        // Build Configuration
        SKIP_CODE_SIGN = "${params.SKIP_CODE_SIGN ? '1' : '0'}"
        CLEAN_BUILD = "${params.CLEAN_BUILD ? '1' : '0'}"
        
        // Paths
        WORKSPACE_PATH = "${WORKSPACE}"
        SCRIPTS_PATH = "${WORKSPACE}/Scripts"
        
        // CocoaPods
        COCOAPODS_DISABLE_STATS = 'true'
        COCOAPODS_CACHE_DIR = "${WORKSPACE}/.cocoapods_cache"
        
        // Xcode
        DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer'
        XCODE_XCCONFIG_FILE = "${WORKSPACE}/ci.xcconfig"
        
        // Build artifacts
        ARTIFACTS_DIR = "${WORKSPACE}/artifacts"
        
        // Logging
        LOG_LEVEL = 'INFO'
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔍 Checking out repository..."
                    
                    checkout scm
                    
                    // Get build information
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    
                    env.GIT_BRANCH_NAME = sh(
                        script: 'git rev-parse --abbrev-ref HEAD',
                        returnStdout: true
                    ).trim()
                    
                    echo "📋 Build Information:"
                    echo "  Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "  Branch: ${env.GIT_BRANCH_NAME}"
                    echo "  Build Type: ${params.BUILD_TYPE}"
                    echo "  Framework: ${params.FRAMEWORK_NAME}"
                }
            }
        }
        
        stage('Environment Setup') {
            steps {
                script {
                    echo "🔧 Setting up build environment..."
                    
                    // Create necessary directories
                    sh '''
                        mkdir -p "${ARTIFACTS_DIR}"
                        mkdir -p "${COCOAPODS_CACHE_DIR}"
                        mkdir -p "${WORKSPACE}/DerivedData"
                    '''
                    
                    // Create CI-specific xcconfig
                    writeFile file: 'ci.xcconfig', text: '''// CI-specific build optimizations
COMPILER_INDEX_STORE_ENABLE = NO
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -O
DEBUG_INFORMATION_FORMAT = dwarf
ONLY_ACTIVE_ARCH = NO
'''
                    
                    // Verify required tools
                    sh '''
                        echo "🔍 Verifying build tools..."
                        
                        # Check Xcode
                        if ! command -v xcodebuild >/dev/null 2>&1; then
                            echo "❌ Xcode command line tools not found"
                            exit 1
                        fi
                        
                        # Check CocoaPods
                        if ! command -v pod >/dev/null 2>&1; then
                            echo "❌ CocoaPods not found"
                            exit 1
                        fi
                        
                        # Check Git
                        if ! command -v git >/dev/null 2>&1; then
                            echo "❌ Git not found"
                            exit 1
                        fi
                        
                        echo "✅ All required tools found"
                        
                        # Display versions
                        echo "📋 Tool Versions:"
                        xcodebuild -version | head -1
                        pod --version
                        git --version
                    '''
                }
            }
        }
        
        stage('Dependency Resolution') {
            steps {
                script {
                    echo "📦 Resolving dependencies..."
                    
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Install CocoaPods dependencies
                        echo "🔧 Installing CocoaPods dependencies..."
                        pod install --repo-update
                        
                        # Verify workspace
                        if [[ ! -d "msp-ios-sdk.xcworkspace" ]]; then
                            echo "❌ Workspace not found after pod install"
                            exit 1
                        fi
                        
                        echo "✅ Dependencies resolved successfully"
                    '''
                }
            }
        }
        
        stage('Build Dependencies') {
            when {
                anyOf {
                    params.BUILD_TYPE == 'release'
                    params.BUILD_TYPE == 'manual'
                }
            }
            steps {
                script {
                    echo "🏗️ Building framework dependencies..."
                    
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Build MSPiOSCore first (dependency)
                        echo "🔧 Building MSPiOSCore..."
                        if [[ -f "Scripts/buildiOSCoreXCFramework.sh" ]]; then
                            SKIP_CODE_SIGN="${SKIP_CODE_SIGN}" ./Scripts/buildiOSCoreXCFramework.sh
                        else
                            echo "⚠️ MSPiOSCore build script not found, using unified build script"
                            SKIP_CODE_SIGN="${SKIP_CODE_SIGN}" ./Scripts/build.sh --framework MSPiOSCore
                        fi
                        
                        # Build NovaCore (dependency)
                        echo "🔧 Building NovaCore..."
                        if [[ -f "Scripts/buildNovaXCFramework.sh" ]]; then
                            SKIP_CODE_SIGN="${SKIP_CODE_SIGN}" ./Scripts/buildNovaXCFramework.sh
                        else
                            echo "⚠️ NovaCore build script not found, using unified build script"
                            SKIP_CODE_SIGN="${SKIP_CODE_SIGN}" ./Scripts/build.sh --framework NovaCore
                        fi
                        
                        echo "✅ Dependencies built successfully"
                    '''
                }
            }
        }
        
        stage('Validate MSPCore') {
            steps {
                script {
                    echo "🔍 Validating MSPCore podspec..."
                    
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Validate podspec
                        echo "🔧 Validating MSPCore.podspec..."
                        pod spec lint MSPCore.podspec --allow-warnings
                        
                        echo "✅ MSPCore podspec validation passed"
                    '''
                }
            }
        }
        
        stage('Build MSPCore') {
            steps {
                script {
                    echo "🏗️ Building MSPCore..."
                    
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Clean if requested
                        if [[ "${CLEAN_BUILD}" == "1" ]]; then
                            echo "🧹 Cleaning build artifacts..."
                            ./Scripts/build.sh --clean
                        fi
                        
                        # Build MSPCore using the unified build script
                        echo "🔧 Building MSPCore framework..."
                        SKIP_CODE_SIGN="${SKIP_CODE_SIGN}" ./Scripts/build.sh --framework MSPCore
                        
                        echo "✅ MSPCore build completed"
                    '''
                }
            }
        }
        
        stage('Test MSPCore') {
            steps {
                script {
                    echo "🧪 Testing MSPCore..."
                    
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Run tests if test scheme exists
                        echo "🔧 Running MSPCore tests..."
                        xcodebuild test \
                            -workspace msp-ios-sdk.xcworkspace \
                            -scheme MSPCore \
                            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
                            -derivedDataPath DerivedData \
                            -quiet
                        
                        echo "✅ MSPCore tests passed"
                    '''
                }
            }
        }
        
        stage('Collect Artifacts') {
            when {
                params.PUBLISH_ARTIFACTS
            }
            steps {
                script {
                    echo "📦 Collecting build artifacts..."
                    
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Create artifacts directory
                        mkdir -p "${ARTIFACTS_DIR}"
                        
                        # Collect podspec
                        if [[ -f "MSPCore.podspec" ]]; then
                            cp MSPCore.podspec "${ARTIFACTS_DIR}/"
                            echo "📄 Collected: MSPCore.podspec"
                        fi
                        
                        # Collect source files
                        if [[ -d "MSPCore" ]]; then
                            tar -czf "${ARTIFACTS_DIR}/MSPCore-source.tar.gz" MSPCore/
                            echo "📁 Collected: MSPCore source"
                        fi
                        
                        # Collect build logs
                        find . -name "*.log" -type f -exec cp {} "${ARTIFACTS_DIR}/" \\;
                        
                        # Create build info
                        cat > "${ARTIFACTS_DIR}/build-info.txt" << EOF
Build Information
=================
Build Type: ${BUILD_TYPE}
Framework: ${FRAMEWORK_NAME}
Git Commit: ${GIT_COMMIT_SHORT}
Git Branch: ${GIT_BRANCH_NAME}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Jenkins Build: ${BUILD_NUMBER}
Jenkins Job: ${JOB_NAME}
EOF
                        
                        echo "✅ Artifacts collected successfully"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Cleaning up build environment..."
                
                // Archive artifacts if they exist
                if (fileExists("${env.ARTIFACTS_DIR}")) {
                    archiveArtifacts artifacts: 'artifacts/**/*', allowEmptyArchive: true
                }
                
                // Archive build logs
                if (fileExists('xcodebuild*.log')) {
                    archiveArtifacts artifacts: 'xcodebuild*.log', allowEmptyArchive: true
                }
                
                // Clean up temporary files
                sh '''
                    rm -f ci.xcconfig
                    rm -rf DerivedData
                '''
            }
        }
        
        success {
            script {
                echo "✅ Build completed successfully!"
                
                // Send success notification
                if (params.BUILD_TYPE == 'release') {
                    echo "🚀 Release build completed successfully"
                } else {
                    echo "✅ Validation build completed successfully"
                }
            }
        }
        
        failure {
            script {
                echo "❌ Build failed!"
                
                // Send failure notification
                echo "💥 Build failed for ${params.FRAMEWORK_NAME}"
                echo "   Commit: ${env.GIT_COMMIT_SHORT}"
                echo "   Branch: ${env.GIT_BRANCH_NAME}"
            }
        }
        
        unstable {
            script {
                echo "⚠️ Build completed with warnings"
            }
        }
    }
}
