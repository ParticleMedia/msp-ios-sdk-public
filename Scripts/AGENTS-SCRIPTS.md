# AI Agent Context: Scripts

> **Version**: 1.0
> **Last Updated**: 2026-01-20
> **Scope**: Scripts/ directory (Bash scripting, automation)
> **Applies To**: All AI Agents working in Scripts/

## Development Philosophy: Config-Driven Development

All Scripts/ automation follows **config-driven development**:

```
Configuration Files → Scripts → Deterministic Output
```

### Core Principles

1. **Configuration as Source of Truth**
   - Scripts read from `.yml.template`, `.podspec.template`, etc.
   - Never hardcode values in scripts
   - Configuration changes should not require script changes

2. **Idempotency**
   - Scripts can be run multiple times safely
   - Check state before modifying
   - Use atomic operations where possible

3. **Fail-Fast with Clear Errors**
   - Use `set -euo pipefail` (required by `Scripts/constitution.md` Article VI.1)
   - Validate inputs before processing
   - Provide actionable error messages

4. **POSIX Compliance**
   - Avoid bash-specific features where possible
   - Test with `/bin/sh` when practical
   - Document any bash-only requirements

## Script Structure Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script: script-name.sh
# Purpose: Brief description
# Usage: ./script-name.sh [arguments]

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
CONFIG_FILE="${PROJECT_ROOT}/config/settings.yml"

# Validation
validate_inputs() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE" >&2
        exit 1
    fi
}

# Main logic
main() {
    validate_inputs

    # Implementation here
    echo "Processing..."
}

# Entry point
main "$@"
```

## Error Handling Requirements

### Required Header (Constitution VI.1)

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Explanation**:
- `set -e`: Exit on any command failure
- `set -u`: Exit on undefined variable usage
- `set -o pipefail`: Exit if any command in a pipeline fails

### Error Messages

```bash
# ✅ Good: Clear, actionable error
if [[ ! -d "$BUILD_DIR" ]]; then
    echo "ERROR: Build directory not found: $BUILD_DIR" >&2
    echo "Run './Scripts/setup.sh' first to create it." >&2
    exit 1
fi

# ❌ Bad: Vague error
if [[ ! -d "$BUILD_DIR" ]]; then
    echo "Build failed" >&2
    exit 1
fi
```

### Exit Codes

Use standard exit codes:
- `0`: Success
- `1`: General error
- `2`: Misuse of shell command
- `126`: Command cannot execute
- `127`: Command not found
- `128+N`: Signal N received

## Idempotency Patterns

### Check Before Create

```bash
# ✅ Idempotent: Check if directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
fi

# ❌ Not idempotent: Always creates
mkdir "$TARGET_DIR"
```

### Atomic Operations

```bash
# ✅ Atomic: Write to temp file, then move
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

echo "content" > "$TEMP_FILE"
mv "$TEMP_FILE" "$TARGET_FILE"

# ❌ Not atomic: Partial write on failure
echo "content" > "$TARGET_FILE"
```

### State Checks

```bash
# ✅ Check state before modifying
if ! grep -q "export PATH" ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# ❌ Blindly append
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## Configuration-Driven Examples

### Reading YAML Config

```bash
# Using yq (YAML processor)
DEPLOY_ENV=$(yq eval '.deployment.environment' config.yml)
API_URL=$(yq eval '.api.base_url' config.yml)

# Fallback: Simple grep/sed for key-value pairs
CONFIG_VALUE=$(grep "^key:" config.yml | sed 's/key: //')
```

### Processing Template Files

```bash
# Example: Generate Podfile from template
process_template() {
    local template="$1"
    local output="$2"
    local version="$3"

    sed "s/{{VERSION}}/$version/g" "$template" > "$output"
}

process_template "Podfile.template" "Podfile" "1.2.3"
```

### Dynamic Script Behavior

```bash
# Read configuration to determine behavior
MODE=$(yq eval '.build.mode' project.yml)

case "$MODE" in
    development)
        enable_debugging
        ;;
    production)
        enable_optimizations
        ;;
    *)
        echo "ERROR: Unknown mode: $MODE" >&2
        exit 1
        ;;
esac
```

## Testing Scripts

### Unit Test Pattern

```bash
# test-script.sh
source "./script-to-test.sh"

test_validate_inputs() {
    # Setup
    CONFIG_FILE="/tmp/test-config.yml"
    echo "key: value" > "$CONFIG_FILE"

    # Test
    if validate_inputs; then
        echo "PASS: validate_inputs"
    else
        echo "FAIL: validate_inputs"
        exit 1
    fi

    # Cleanup
    rm "$CONFIG_FILE"
}

test_validate_inputs
```

### Integration Test Pattern

```bash
# test-integration.sh
#!/usr/bin/env bash
set -euo pipefail

# Setup
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Run script
./Scripts/build.sh --output "$TEMP_DIR"

# Verify
if [[ -f "$TEMP_DIR/result.txt" ]]; then
    echo "PASS: Script produced expected output"
else
    echo "FAIL: Missing result.txt"
    exit 1
fi
```

## Common Patterns

### Argument Parsing

```bash
usage() {
    echo "Usage: $0 [--env ENV] [--verbose]" >&2
    exit 1
}

VERBOSE=false
ENV="development"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)
            ENV="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            usage
            ;;
    esac
done
```

### Logging

```bash
log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[DEBUG] $*" >&2
    fi
}
```

### File Operations

```bash
# Safe file copy with backup
backup_and_copy() {
    local src="$1"
    local dest="$2"

    if [[ -f "$dest" ]]; then
        cp "$dest" "${dest}.backup"
    fi

    cp "$src" "$dest"
}

# Recursive directory sync
sync_directories() {
    local src="$1"
    local dest="$2"

    rsync -av --delete "$src/" "$dest/"
}
```

## Performance Considerations

1. **Minimize Subshells**
   ```bash
   # ✅ Fast: Use built-in parameter expansion
   filename="${path##*/}"

   # ❌ Slow: Spawn subshell
   filename=$(basename "$path")
   ```

2. **Batch Operations**
   ```bash
   # ✅ Fast: Single find command
   find . -name "*.log" -delete

   # ❌ Slow: Loop with multiple calls
   for file in $(find . -name "*.log"); do
       rm "$file"
   done
   ```

3. **Avoid Unnecessary Pipelines**
   ```bash
   # ✅ Fast: Direct grep with -c
   count=$(grep -c "pattern" file.txt)

   # ❌ Slow: Unnecessary pipeline
   count=$(grep "pattern" file.txt | wc -l)
   ```

## When to Use Shell Scripts vs Other Languages

### Use Shell Scripts For:
- ✅ File system operations (copying, moving, renaming)
- ✅ Process orchestration (running tools, chaining commands)
- ✅ Build automation (XcodeGen, CocoaPods, linting)
- ✅ CI/CD pipelines (simple deployment logic)
- ✅ Environment setup (configuration, dependencies)

### Consider Other Languages For:
- ❌ Complex data processing (use Python, Ruby)
- ❌ HTTP API interactions (use curl with scripts or Python)
- ❌ String manipulation heavy tasks (use awk, sed, or Python)
- ❌ Concurrent processing (use Go, Python)
- ❌ Cross-platform GUI tools (use Python, Node.js)

## References

- `Scripts/constitution.md` - Scripting standards (Article VI)
- `AGENTS.md` - Project-wide context
- Federal `constitution.md` - Automation principles (Article I)
