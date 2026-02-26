#!/usr/bin/env bash
set -euo pipefail

# @description Unit test runner for MSP release system
# @description Discovers and runs all unit tests in cases/ directory
# @return 0 on success, 1 if any tests fail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../../.." && pwd)"
cases_dir="${script_dir}/cases"
helpers="${script_dir}/helpers.sh"

# shellcheck source=Scripts/tests/unit/helpers.sh
source "${helpers}"
if [[ -f "$root_dir/Scripts/lib/common.sh" ]]; then
    # shellcheck source=Scripts/lib/common.sh
    source "$root_dir/Scripts/lib/common.sh" 2>/dev/null || true
fi

# Fallback colors if common.sh not available
: "${RED:='\033[0;31m'}"
: "${GREEN:='\033[0;32m'}"
: "${YELLOW:='\033[1;33m'}"
: "${BLUE:='\033[0;34m'}"
: "${NC:='\033[0m'}"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# @description Print usage information
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [FILTER]

Run unit tests for MSP release system bash scripts.

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -f, --filter    Run only tests matching pattern
    --list          List available tests without running
    --coverage      Show coverage summary (requires test markers)

Arguments:
    FILTER          Optional pattern to filter test files (e.g., "state" or "config")

Examples:
    $(basename "$0")                    # Run all tests
    $(basename "$0") state              # Run only state-related tests
    $(basename "$0") --verbose config   # Run config tests with verbose output
    $(basename "$0") --list             # List all available tests
EOF
}

# @description Print test header
# @param $1 title - The title to display
print_header() {
    local title="$1"
    echo "════════════════════════════════════════════════════════════════"
    echo " ${title}"
    echo "════════════════════════════════════════════════════════════════"
}

# @description Print test summary
print_summary() {
    echo ""
    print_header "Test Summary"
    echo ""
    echo -e "  Total:   ${TOTAL_TESTS}"
    echo -e "  ${GREEN}Passed:  ${PASSED_TESTS}${NC}"
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "  ${RED}Failed:  ${FAILED_TESTS}${NC}"
    else
        echo -e "  Failed:  ${FAILED_TESTS}"
    fi
    if [[ $SKIPPED_TESTS -gt 0 ]]; then
        echo -e "  ${YELLOW}Skipped: ${SKIPPED_TESTS}${NC}"
    fi
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}All tests passed.${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# @description Run a single test file
# @param $1 test_file - Path to the test file
# @return 0 on success, 1 on failure
run_test_file() {
    local test_file="$1"
    local test_name
    test_name="$(basename "${test_file}" .sh)"

    # Create temporary directory for test isolation
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Cleanup function
    cleanup() {
        rm -rf "$tmpdir"
    }
    trap cleanup EXIT

    echo -e "${BLUE}[RUN]${NC} ${test_name}"

    # Run test in completely isolated bash process
    local exit_code=0
    TEST_TMPDIR="$tmpdir" TEST_NAME="$test_name" VERBOSE="${VERBOSE:-false}" \
        bash "${test_file}" || exit_code=$?

    trap - EXIT
    cleanup

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ $exit_code -eq 0 ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "${GREEN}[PASS]${NC} ${test_name}"
        return 0
    elif [[ $exit_code -eq 77 ]]; then
        # Exit code 77 is used to indicate skipped tests
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        echo -e "${YELLOW}[SKIP]${NC} ${test_name}"
        return 0
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "${RED}[FAIL]${NC} ${test_name} (exit code: ${exit_code})"
        return 1
    fi
}

# @description List available tests
list_tests() {
    local filter="${1:-}"

    print_header "Available Unit Tests"
    echo ""

    if [[ ! -d "$cases_dir" ]]; then
        echo "No test cases directory found at: $cases_dir"
        return 1
    fi

    local test_files
    if [[ -n "$filter" ]]; then
        test_files=$(find "${cases_dir}" -name "*${filter}*_test.sh" -type f 2>/dev/null | sort)
    else
        test_files=$(find "${cases_dir}" -name "*_test.sh" -type f 2>/dev/null | sort)
    fi

    if [[ -z "$test_files" ]]; then
        echo "No test files found matching pattern: *${filter}*_test.sh"
        return 0
    fi

    local count=0
    while IFS= read -r test_file; do
        count=$((count + 1))
        local test_name
        test_name="$(basename "${test_file}" .sh)"
        echo "  ${count}. ${test_name}"
    done <<< "$test_files"

    echo ""
    echo "Total: ${count} test file(s)"
}

# @description Main entry point
main() {
    local filter=""
    local list_only=false
    local show_coverage=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                export VERBOSE=true
                shift
                ;;
            -f|--filter)
                filter="$2"
                shift 2
                ;;
            --list)
                list_only=true
                shift
                ;;
            --coverage)
                show_coverage=true
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                filter="$1"
                shift
                ;;
        esac
    done

    # List tests if requested
    if [[ "$list_only" == "true" ]]; then
        list_tests "$filter"
        exit 0
    fi

    print_header "MSP Release System Unit Tests"
    echo ""

    # Check for test cases directory
    if [[ ! -d "$cases_dir" ]]; then
        echo -e "${YELLOW}Warning: No test cases directory found at: $cases_dir${NC}"
        echo "Creating empty cases directory..."
        mkdir -p "$cases_dir"
        echo "No tests to run."
        exit 0
    fi

    # Find test files
    local test_files
    if [[ -n "$filter" ]]; then
        test_files=$(find "${cases_dir}" -name "*${filter}*_test.sh" -type f 2>/dev/null | sort)
    else
        test_files=$(find "${cases_dir}" -name "*_test.sh" -type f 2>/dev/null | sort)
    fi

    if [[ -z "$test_files" ]]; then
        echo -e "${YELLOW}No test files found matching pattern: *${filter}*_test.sh${NC}"
        exit 0
    fi

    # Run each test file
    local has_failures=false
    while IFS= read -r test_file; do
        run_test_file "${test_file}" || has_failures=true
    done <<< "$test_files"

    # Print summary
    echo ""
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
