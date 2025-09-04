# Scripts Library Documentation

This directory contains reusable library modules that provide common functionality across all build scripts.

## Available Libraries

### Demo App Builder (`demo_app_builder.sh`)
Provides reusable functions for building and validating the MSPDemoApp in various contexts.

### XCFramework Builder (`xcframework_builder.sh`)
Centralized XCFramework creation with CI path resolution and robust error handling.

### Color Utilities (`colors.sh`)
Standardized color definitions for consistent output across all scripts.

### Framework Configuration (`framework_config.sh`)
Framework-specific configuration management and build order handling.

### Common Utilities (`common.sh`)
Core utilities and shared functions used across all scripts.

### Logging System (`logging.sh`)
Structured logging with environment-aware output and CI/CD integration.

### Validation Framework (`validation.sh`)
Comprehensive validation for all inputs and environments.

### Xcode Operations (`xcode.sh`)
Advanced Xcode build operations and optimization.

### CocoaPods Management (`cocoapods.sh`)
CocoaPods integration and management utilities.

### CI/CD Support (`ci.sh`)
CI/CD environment detection and optimization features.

## Overview

The `demo_app_builder.sh` library contains modular functions that can be sourced by other scripts to provide demo app building capabilities without duplicating code.

## Available Functions

### Core Functions

#### `build_demo_app [destination] [configuration] [derived_data_path]`
Main function that automatically detects the linking mode and builds the demo app accordingly.

**Parameters:**
- `destination` (optional): Xcode destination (default: 'platform=iOS Simulator,name=iPhone 15')
- `configuration` (optional): Build configuration (default: Debug)
- `derived_data_path` (optional): Derived data path (default: /tmp/MSPDemoApp-DerivedData)

**Returns:** 0 on success, 1 on failure

#### `build_demo_app_framework [destination] [configuration] [derived_data_path]`
Builds the demo app using XCFramework linking mode.

#### `build_demo_app_static [destination] [configuration] [derived_data_path]`
Builds the demo app using static library linking mode (includes building MSPCore and NovaCore first).

#### `validate_demo_app_structure`
Validates the demo app project structure and dependencies without building.

**Returns:** 0 on success, 1 on failure

#### `detect_linking_mode`
Detects whether to use framework or static library linking based on available artifacts.

**Returns:** "framework" or "static"

### Utility Functions

#### `print_status [color] [message]`
Prints a colored status message.

**Parameters:**
- `color`: Color constant (RED, GREEN, YELLOW, BLUE)
- `message`: Message to print

## Usage Examples

### Basic Usage

```bash
#!/bin/bash

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/demo_app_builder.sh"

# Build demo app with default settings
build_demo_app
```

### Advanced Usage

```bash
#!/bin/bash

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/demo_app_builder.sh"

# Build for specific device and configuration
build_demo_app 'platform=iOS Simulator,name=iPhone 15 Pro' Release /tmp/CustomDerivedData

# Check linking mode
if [ "$(detect_linking_mode)" = "framework" ]; then
    echo "Using XCFramework linking"
else
    echo "Using static library linking"
fi

# Validate structure only
if validate_demo_app_structure; then
    echo "Structure validation passed"
else
    echo "Structure validation failed"
    exit 1
fi
```

### Integration with CI/CD

```bash
#!/bin/bash

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/demo_app_builder.sh"

# Try to build demo app
if build_demo_app; then
    echo "Demo app built successfully"
else
    echo "Demo app build failed, falling back to validation"
    
    # Fallback validation
    if validate_demo_app_structure; then
        echo "Structure validation passed - continuing CI pipeline"
    else
        echo "Structure validation failed - stopping CI pipeline"
        exit 1
    fi
fi
```

### Custom Build Scripts

```bash
#!/bin/bash

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/demo_app_builder.sh"

# Custom build workflow
echo "Starting custom build workflow..."

# Step 1: Build XCFrameworks
echo "Building XCFrameworks..."
# ... your XCFramework build logic ...

# Step 2: Build Demo App
echo "Building Demo App..."
if build_demo_app; then
    echo "Demo app ready for testing"
else
    echo "Demo app build failed"
    exit 1
fi

# Step 3: Run tests
echo "Running tests..."
# ... your test logic ...
```

## Integration Points

### Existing Scripts

The library can be integrated into existing scripts:

- **`build.sh`**: Add demo app building as a final step
- **`release.sh`**: Include demo app validation before release
- **CI/CD workflows**: Use for both building and validation

### New Scripts

Create new scripts that leverage the library:

- **`buildAndTest.sh`**: Build everything and run tests
- **`validate.sh`**: Validate project structure and dependencies
- **`ci-build.sh`**: CI-optimized build script

## Benefits

1. **Code Reuse**: No more duplicating demo app building logic
2. **Consistency**: Same building behavior across all scripts
3. **Maintainability**: Update logic in one place
4. **Flexibility**: Easy to customize for different use cases
5. **Error Handling**: Consistent error handling and fallbacks
6. **CI Integration**: Built-in support for CI/CD environments
7. **Path Resolution**: Automatic handling of CI path issues
8. **Fallback Support**: Graceful degradation when builds fail

## Dependencies

- Bash shell
- Xcode command line tools
- CocoaPods (for project dependencies)

## CI/CD Features

### Automatic Environment Detection
- Detects CI environment automatically
- Applies CI-specific optimizations
- Handles path resolution issues (e.g., `/tmp` vs `/private/tmp`)

### Fallback Mechanisms
- Graceful degradation when builds fail
- Structure validation as fallback
- Comprehensive error reporting for CI debugging

### Path Resolution
- Handles symlinked directories in CI
- Uses absolute paths for XCFramework creation
- Compatible with GitHub Actions and other CI platforms

## Error Handling

All functions return appropriate exit codes:
- `0`: Success
- `1`: Failure

The library includes comprehensive error handling and colored output for better user experience.

## Best Practices

1. **Always source the library** before using its functions
2. **Check return codes** from library functions
3. **Use fallback validation** when builds fail in CI
4. **Customize parameters** for your specific use case
5. **Handle errors gracefully** in your scripts
