#!/usr/bin/env bash
# Mock loader utility for MSP release system unit tests
# Provides utilities to load, configure, and manage mock objects for testing

# ============================================================================
# Mock Configuration
# ============================================================================

# Directory containing mock scripts (from release_state tests)
MOCK_SOURCE_DIR="${MOCK_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../release_state/mock" && pwd)}"

# Directory to install mocks during tests
MOCK_INSTALL_DIR="${TEST_TMPDIR:-$(mktemp -d)}/mocks"

# Log file for mock invocations
MOCK_LOG="${MOCK_LOG:-${TEST_TMPDIR:-/tmp}/mock_invocations.log}"

# ============================================================================
# Mock Management Functions
# ============================================================================

# @description Initialize the mock system
# @return 0 on success
mock_init() {
    # Create mock installation directory
    mkdir -p "$MOCK_INSTALL_DIR"

    # Clear mock log
    > "$MOCK_LOG" 2>/dev/null || true

    # Prepend mock directory to PATH
    export PATH="${MOCK_INSTALL_DIR}:${PATH}"
    export MOCK_LOG

    debug "Mock system initialized: $MOCK_INSTALL_DIR"
}

# @description Install a specific mock
# @param $1 mock_name - Name of the mock to install (git, curl, pod, etc.)
# @return 0 on success, 1 if mock not found
mock_install() {
    local mock_name="$1"
    local source_path="${MOCK_SOURCE_DIR}/${mock_name}"
    local install_path="${MOCK_INSTALL_DIR}/${mock_name}"

    if [[ ! -f "$source_path" ]]; then
        echo "Mock not found: $source_path" >&2
        return 1
    fi

    cp "$source_path" "$install_path"
    chmod +x "$install_path"

    debug "Installed mock: $mock_name"
}

# @description Install all available mocks
# @return 0 on success
mock_install_all() {
    if [[ ! -d "$MOCK_SOURCE_DIR" ]]; then
        echo "Mock source directory not found: $MOCK_SOURCE_DIR" >&2
        return 1
    fi

    local mocks
    mocks=$(find "$MOCK_SOURCE_DIR" -maxdepth 1 -type f -executable 2>/dev/null)

    while IFS= read -r mock; do
        local mock_name
        mock_name=$(basename "$mock")
        mock_install "$mock_name"
    done <<< "$mocks"

    debug "Installed all mocks from: $MOCK_SOURCE_DIR"
}

# @description Create a custom mock function
# @param $1 mock_name - Name of the mock command
# @param $2 behavior - Shell code defining the mock behavior
# @return 0 on success
mock_create() {
    local mock_name="$1"
    local behavior="$2"
    local install_path="${MOCK_INSTALL_DIR}/${mock_name}"

    cat > "$install_path" <<EOF
#!/usr/bin/env bash
# Auto-generated mock for: $mock_name
MOCK_LOG="\${MOCK_LOG:-./mock_invocations.log}"
echo "[mock_${mock_name}] \$@" >> "\$MOCK_LOG" 2>&1

${behavior}
EOF

    chmod +x "$install_path"
    debug "Created custom mock: $mock_name"
}

# @description Create a mock that always succeeds with optional output
# @param $1 mock_name - Name of the mock command
# @param $2 output - Optional output to print
mock_success() {
    local mock_name="$1"
    local output="${2:-}"

    local behavior=""
    if [[ -n "$output" ]]; then
        behavior="echo '${output}'"
    fi
    behavior="${behavior}
exit 0"

    mock_create "$mock_name" "$behavior"
}

# @description Create a mock that always fails
# @param $1 mock_name - Name of the mock command
# @param $2 exit_code - Exit code to return (default: 1)
# @param $3 error_msg - Error message to print
mock_failure() {
    local mock_name="$1"
    local exit_code="${2:-1}"
    local error_msg="${3:-Mock failure}"

    mock_create "$mock_name" "echo '${error_msg}' >&2; exit ${exit_code}"
}

# @description Create a mock that returns specific output based on arguments
# @param $1 mock_name - Name of the mock command
# @param $2 arg_pattern - Pattern to match in arguments
# @param $3 output - Output to return when pattern matches
# @param $4 default_output - Default output when pattern doesn't match
mock_conditional() {
    local mock_name="$1"
    local arg_pattern="$2"
    local output="$3"
    local default_output="${4:-}"

    local behavior="
if [[ \"\$*\" == *\"${arg_pattern}\"* ]]; then
    echo '${output}'
else
    echo '${default_output}'
fi
exit 0"

    mock_create "$mock_name" "$behavior"
}

# ============================================================================
# Mock Verification Functions
# ============================================================================

# @description Check if a mock was called
# @param $1 mock_name - Name of the mock
# @param $2 message - Optional assertion message
assert_mock_called() {
    local mock_name="$1"
    local message="${2:-Mock should have been called: $mock_name}"

    if [[ ! -f "$MOCK_LOG" ]]; then
        echo "ASSERT FAILED: ${message} (mock log not found)" >&2
        exit 1
    fi

    if ! grep -q "\\[mock_${mock_name}\\]" "$MOCK_LOG" 2>/dev/null; then
        echo "ASSERT FAILED: ${message}" >&2
        echo "  Mock log contents:" >&2
        cat "$MOCK_LOG" >&2
        exit 1
    fi
}

# @description Check if a mock was called with specific arguments
# @param $1 mock_name - Name of the mock
# @param $2 args_pattern - Pattern to match in arguments
# @param $3 message - Optional assertion message
assert_mock_called_with() {
    local mock_name="$1"
    local args_pattern="$2"
    local message="${3:-Mock should have been called with: $args_pattern}"

    if [[ ! -f "$MOCK_LOG" ]]; then
        echo "ASSERT FAILED: ${message} (mock log not found)" >&2
        exit 1
    fi

    if ! grep "\\[mock_${mock_name}\\]" "$MOCK_LOG" 2>/dev/null | grep -q "$args_pattern"; then
        echo "ASSERT FAILED: ${message}" >&2
        echo "  Expected pattern: ${args_pattern}" >&2
        echo "  Actual calls:" >&2
        grep "\\[mock_${mock_name}\\]" "$MOCK_LOG" 2>/dev/null || echo "    (none)"
        exit 1
    fi
}

# @description Check that a mock was NOT called
# @param $1 mock_name - Name of the mock
# @param $2 message - Optional assertion message
assert_mock_not_called() {
    local mock_name="$1"
    local message="${2:-Mock should not have been called: $mock_name}"

    if [[ -f "$MOCK_LOG" ]] && grep -q "\\[mock_${mock_name}\\]" "$MOCK_LOG" 2>/dev/null; then
        echo "ASSERT FAILED: ${message}" >&2
        echo "  But it was called:" >&2
        grep "\\[mock_${mock_name}\\]" "$MOCK_LOG" >&2
        exit 1
    fi
}

# @description Get the number of times a mock was called
# @param $1 mock_name - Name of the mock
# @return Number of calls (printed to stdout)
mock_call_count() {
    local mock_name="$1"

    if [[ ! -f "$MOCK_LOG" ]]; then
        echo "0"
        return
    fi

    grep -c "\\[mock_${mock_name}\\]" "$MOCK_LOG" 2>/dev/null || echo "0"
}

# @description Assert mock was called exactly N times
# @param $1 mock_name - Name of the mock
# @param $2 expected_count - Expected number of calls
# @param $3 message - Optional assertion message
assert_mock_call_count() {
    local mock_name="$1"
    local expected_count="$2"
    local message="${3:-Mock should have been called $expected_count time(s)}"

    local actual_count
    actual_count=$(mock_call_count "$mock_name")

    if [[ "$actual_count" -ne "$expected_count" ]]; then
        echo "ASSERT FAILED: ${message}" >&2
        echo "  Expected: ${expected_count}" >&2
        echo "  Actual:   ${actual_count}" >&2
        exit 1
    fi
}

# @description Clear the mock log
clear_mock_log() {
    > "$MOCK_LOG" 2>/dev/null || true
}

# @description Get all mock calls as an array
# @param $1 mock_name - Optional: filter by mock name
get_mock_calls() {
    local mock_name="${1:-}"

    if [[ ! -f "$MOCK_LOG" ]]; then
        return
    fi

    if [[ -n "$mock_name" ]]; then
        grep "\\[mock_${mock_name}\\]" "$MOCK_LOG" 2>/dev/null || true
    else
        cat "$MOCK_LOG"
    fi
}

# ============================================================================
# Stub Functions for External Dependencies
# ============================================================================

# @description Create a stub for jq that returns predetermined values
# @param $1 expression - jq expression to match
# @param $2 value - Value to return
stub_jq_result() {
    local expression="$1"
    local value="$2"

    # Store stub in environment variable for the mock to use
    export "STUB_JQ_${expression//[^a-zA-Z0-9]/_}=${value}"
}

# @description Create a stub for yq that returns predetermined values
# @param $1 expression - yq expression to match
# @param $2 value - Value to return
stub_yq_result() {
    local expression="$1"
    local value="$2"

    # Store stub in environment variable for the mock to use
    export "STUB_YQ_${expression//[^a-zA-Z0-9]/_}=${value}"
}

# ============================================================================
# Environment Variable Stubs
# ============================================================================

# @description Set up a test environment with common variables
# @param $1 profile - Optional profile name (default: local-dev)
setup_test_env() {
    local profile="${1:-local-dev}"

    export DRY_RUN=true
    export MSP_RELEASE_MODE="cli"
    export MSP_LOG_LEVEL="info"
    export ROOT_DIR="${TEST_TMPDIR}"
    export NO_ANSI="true"

    # Create minimal .git structure
    mkdir -p "${TEST_TMPDIR}/.git"
    echo "ref: refs/heads/main" > "${TEST_TMPDIR}/.git/HEAD"

    debug "Test environment set up with profile: $profile"
}

# @description Clean up the test environment
cleanup_test_env() {
    unset DRY_RUN
    unset MSP_RELEASE_MODE
    unset MSP_LOG_LEVEL
    unset ROOT_DIR
    unset NO_ANSI

    debug "Test environment cleaned up"
}
