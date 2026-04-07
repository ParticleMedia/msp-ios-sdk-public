#!/usr/bin/env bash
# Unit test helpers for MSP release system
# Provides assertion utilities, test fixtures, and isolation functions

# ============================================================================
# Test Context Variables
# ============================================================================

# Set by run_all.sh
TEST_TMPDIR="${TEST_TMPDIR:-$(mktemp -d)}"
TEST_NAME="${TEST_NAME:-unknown}"
VERBOSE="${VERBOSE:-false}"

# Colors (disable if NO_COLOR is set)
if [[ -z "${NO_COLOR:-}" ]]; then
    _RED='\033[0;31m'
    _GREEN='\033[0;32m'
    _YELLOW='\033[1;33m'
    _BLUE='\033[0;34m'
    _NC='\033[0m'
else
    _RED=''
    _GREEN=''
    _YELLOW=''
    _BLUE=''
    _NC=''
fi

# ============================================================================
# Assertion Functions
# ============================================================================

# @description Assert two values are equal
# @param $1 expected - Expected value
# @param $2 actual - Actual value
# @param $3 message - Optional failure message
# @return 0 on success, exits with 1 on failure
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [[ "$expected" != "$actual" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Expected: '${expected}'" >&2
        echo "  Actual:   '${actual}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert two values are not equal
# @param $1 unexpected - Value that should not match
# @param $2 actual - Actual value
# @param $3 message - Optional failure message
assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"

    if [[ "$unexpected" == "$actual" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Should not be: '${unexpected}'" >&2
        echo "  Actual:        '${actual}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert string contains substring
# @param $1 haystack - String to search in
# @param $2 needle - Substring to find
# @param $3 message - Optional failure message
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Expected to find: '${needle}'" >&2
        echo "  In string:        '${haystack}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert string does not contain substring
# @param $1 haystack - String to search in
# @param $2 needle - Substring that should not exist
# @param $3 message - Optional failure message
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Should not find: '${needle}'" >&2
        echo "  In string:       '${haystack}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert string matches regex pattern
# @param $1 string - String to test
# @param $2 pattern - Regex pattern
# @param $3 message - Optional failure message
assert_matches() {
    local string="$1"
    local pattern="$2"
    local message="${3:-String should match pattern}"

    if [[ ! "$string" =~ $pattern ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Pattern: '${pattern}'" >&2
        echo "  String:  '${string}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert file exists
# @param $1 path - Path to file
# @param $2 message - Optional failure message
assert_file_exists() {
    local path="$1"
    local message="${2:-File should exist}"

    if [[ ! -f "$path" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  File not found: '${path}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert file does not exist
# @param $1 path - Path to file
# @param $2 message - Optional failure message
assert_file_not_exists() {
    local path="$1"
    local message="${2:-File should not exist}"

    if [[ -f "$path" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  File should not exist: '${path}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert directory exists
# @param $1 path - Path to directory
# @param $2 message - Optional failure message
assert_dir_exists() {
    local path="$1"
    local message="${2:-Directory should exist}"

    if [[ ! -d "$path" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Directory not found: '${path}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert condition is true
# @param $1 condition_result - Exit code (0 for true)
# @param $2 message - Failure message
assert_true() {
    local condition_result="$1"
    local message="${2:-Condition should be true}"

    if [[ "$condition_result" -ne 0 ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert condition is false
# @param $1 condition_result - Exit code (non-0 for false)
# @param $2 message - Failure message
assert_false() {
    local condition_result="$1"
    local message="${2:-Condition should be false}"

    if [[ "$condition_result" -eq 0 ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# @description Assert command exits with expected code
# @param $1 expected_code - Expected exit code
# @param $@ command - Command to run
assert_exit_code() {
    local expected_code="$1"
    shift
    local actual_code=0

    # Run command and capture exit code
    "$@" || actual_code=$?

    if [[ "$actual_code" -ne "$expected_code" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: Exit code mismatch" >&2
        echo "  Expected: ${expected_code}" >&2
        echo "  Actual:   ${actual_code}" >&2
        echo "  Command:  $*" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: Exit code is ${expected_code}"
    fi
}

# @description Assert JSON field has expected value
# @param $1 json - JSON string
# @param $2 jq_expr - jq expression
# @param $3 expected - Expected value
# @param $4 message - Optional failure message
assert_json_field() {
    local json="$1"
    local jq_expr="$2"
    local expected="$3"
    local message="${4:-JSON field should match}"

    local actual
    actual=$(echo "$json" | jq -r "$jq_expr" 2>/dev/null) || {
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Invalid JSON or jq expression" >&2
        echo "  Expression: ${jq_expr}" >&2
        exit 1
    }

    if [[ "$actual" != "$expected" ]]; then
        echo -e "${_RED}ASSERT FAILED${_NC}: ${message}" >&2
        echo "  Expression: ${jq_expr}" >&2
        echo "  Expected:   '${expected}'" >&2
        echo "  Actual:     '${actual}'" >&2
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_GREEN}ASSERT OK${_NC}: ${message}"
    fi
}

# ============================================================================
# Test Utility Functions
# ============================================================================

# @description Skip the current test with a reason
# @param $1 reason - Reason for skipping
skip_test() {
    local reason="${1:-No reason provided}"
    echo -e "${_YELLOW}SKIPPED${_NC}: ${reason}"
    exit 77
}

# @description Fail the test with a message
# @param $1 message - Failure message
fail_test() {
    local message="${1:-Test failed}"
    echo -e "${_RED}FAILED${_NC}: ${message}" >&2
    exit 1
}

# @description Log a debug message (only in verbose mode)
# @param $@ message - Message to log
debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${_BLUE}[DEBUG]${_NC} $*"
    fi
}

# @description Log an info message
# @param $@ message - Message to log
info() {
    echo -e "${_BLUE}[INFO]${_NC} $*"
}

# ============================================================================
# Fixture Functions
# ============================================================================

# @description Create a temporary file with content
# @param $1 filename - Name of the file
# @param $2 content - Content to write
# @return Path to the created file
create_temp_file() {
    local filename="$1"
    local content="${2:-}"
    local filepath="${TEST_TMPDIR}/${filename}"

    # Create parent directories if needed
    mkdir -p "$(dirname "$filepath")"

    # Write content
    echo "$content" > "$filepath"

    echo "$filepath"
}

# @description Create a temporary directory
# @param $1 dirname - Name of the directory
# @return Path to the created directory
create_temp_dir() {
    local dirname="${1:-subdir}"
    local dirpath="${TEST_TMPDIR}/${dirname}"

    mkdir -p "$dirpath"
    echo "$dirpath"
}

# @description Create a mock YAML config file
# @param $1 profile - Profile name (local-dev, production, etc.)
# @return Path to the created config file
create_mock_config() {
    local profile="${1:-local-dev}"
    local config_path="${TEST_TMPDIR}/release.yaml"

    cat > "$config_path" <<EOF
schema_version: 2
version: ""
release_branch: ""
base_branch: "main"
default_profile: ${profile}

profiles:
  local-dev:
    dry_run: true
    validation:
      preflight: basic
    logging:
      level: info
      format: pretty
    safety:
      allow_existing_tag: true
      allow_existing_release: true

  production:
    dry_run: false
    validation:
      preflight: full
    logging:
      level: info
      format: pretty
    safety:
      allow_existing_tag: false
      allow_existing_release: false

pods:
  enabled: true
  modules:
    - MSPiOSCore
    - MSPSharedLibraries
    - MSPCore

spm:
  enabled: true
  packages:
    - MSPiOSCore
    - MSPSharedLibraries
    - MSPCore

verify:
  sandbox_dir: "/tmp/msp-verify-sandbox"
  cleanup_on_success: true
  types:
    local: true
    remote_pods: true
    remote_spm: true
EOF

    echo "$config_path"
}

# @description Create a mock state file
# @param $1 version - Release version
# @param $2 mode - run or resume
# @param $3 release_mode - simple or full
# @return Path to the created state file
create_mock_state() {
    local version="${1:-1.0.0}"
    local mode="${2:-run}"
    local release_mode="${3:-simple}"
    local state_path="${TEST_TMPDIR}/.msp-release-state.json"

    cat > "$state_path" <<EOF
{
  "schema_version": 2,
  "run_id": "test-$(date +%s)-$$",
  "mode": "${mode}",
  "release_mode": "${release_mode}",
  "version": "${version}",
  "profile": "local-dev",
  "base_branch": "main",
  "release_branch": "release/${version}",
  "dry_run": true,
  "phases": {
    "preflight": {
      "status": "pending",
      "steps": {}
    },
    "publish_pods": {
      "status": "pending",
      "steps": {}
    },
    "publish_spm": {
      "status": "pending",
      "steps": {}
    },
    "verify": {
      "status": "pending",
      "steps": {}
    }
  },
  "git": {
    "tag_created": false,
    "tag_name": null,
    "release_branch_pushed": false,
    "pr_branch_name": null,
    "pr_branch_pushed": false,
    "github_release_created": false
  },
  "timestamps": {
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "completed_at": null
  },
  "last_error": {
    "phase": null,
    "step": null,
    "message": null,
    "exit_code": null,
    "occurred_at": null
  }
}
EOF

    echo "$state_path"
}

# ============================================================================
# Function Isolation Helpers
# ============================================================================

# @description Source a script file and extract specific functions
# @param $1 script_path - Path to the script to source
# @param $@ function_names - Names of functions to extract (optional, sources all if not specified)
source_functions() {
    local script_path="$1"
    shift

    if [[ ! -f "$script_path" ]]; then
        echo "Error: Script not found: $script_path" >&2
        return 1
    fi

    # If no specific functions requested, source the entire file
    if [[ $# -eq 0 ]]; then
        # shellcheck source=/dev/null
        source "$script_path"
        return 0
    fi

    # Otherwise, extract only the specified functions
    local func_names=("$@")
    local temp_script="${TEST_TMPDIR}/extracted_functions.sh"

    # Extract each requested function
    for func_name in "${func_names[@]}"; do
        # Use awk to extract the function definition
        awk "/^${func_name}\\s*\\(\\)\\s*\\{/,/^\\}/" "$script_path" >> "$temp_script"
        echo "" >> "$temp_script"
    done

    # Source the extracted functions
    # shellcheck source=/dev/null
    source "$temp_script"
}

# @description Run a command with captured output
# @param $@ command - Command to run
# @return Sets CAPTURED_STDOUT and CAPTURED_STDERR variables
capture_output() {
    local stdout_file="${TEST_TMPDIR}/stdout.txt"
    local stderr_file="${TEST_TMPDIR}/stderr.txt"

    local exit_code=0
    "$@" > "$stdout_file" 2> "$stderr_file" || exit_code=$?

    CAPTURED_STDOUT="$(cat "$stdout_file")"
    CAPTURED_STDERR="$(cat "$stderr_file")"
    CAPTURED_EXIT_CODE="$exit_code"

    return "$exit_code"
}
