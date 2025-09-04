fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests for all frameworks

### ios build_msp_ios_core

```sh
[bundle exec] fastlane ios build_msp_ios_core
```

Build MSPiOSCore XCFramework

### ios build_nova_core

```sh
[bundle exec] fastlane ios build_nova_core
```

Build NovaCore XCFramework

### ios build_all

```sh
[bundle exec] fastlane ios build_all
```

Build all XCFrameworks

### ios validate_podspecs

```sh
[bundle exec] fastlane ios validate_podspecs
```

Validate CocoaPods specs

### ios validate_podspecs_comprehensive

```sh
[bundle exec] fastlane ios validate_podspecs_comprehensive
```

Comprehensive CocoaPods specs validation

### ios build_demo_app_simulator

```sh
[bundle exec] fastlane ios build_demo_app_simulator
```

Build MSPDemoApp for simulator

### ios build_demo_app_device

```sh
[bundle exec] fastlane ios build_demo_app_device
```

Build MSPDemoApp for device

### ios validate_demo_app

```sh
[bundle exec] fastlane ios validate_demo_app
```

Comprehensive MSPDemoApp validation

### ios verify_pod_installation

```sh
[bundle exec] fastlane ios verify_pod_installation
```

Verify pod installation

### ios publish_to_cocoapods

```sh
[bundle exec] fastlane ios publish_to_cocoapods
```

Publish to CocoaPods trunk

### ios create_github_release

```sh
[bundle exec] fastlane ios create_github_release
```

Create GitHub release

### ios release

```sh
[bundle exec] fastlane ios release
```

Complete release process

### ios validate_ci_minimal

```sh
[bundle exec] fastlane ios validate_ci_minimal
```

Ultra-minimal CI validation (only most reliable steps)

### ios setup_dev

```sh
[bundle exec] fastlane ios setup_dev
```

Setup development environment

### ios clean

```sh
[bundle exec] fastlane ios clean
```

Clean build artifacts

### ios status

```sh
[bundle exec] fastlane ios status
```

Show project status

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
