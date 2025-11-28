#!/usr/bin/env bash

set -euo pipefail

# Test runner for release state test suite
# Discovers and runs all test cases in cases/ directory

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cases_dir="${script_dir}/cases"
helpers="${script_dir}/helpers.sh"
mock_dir="${script_dir}/mock"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "${helpers}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

main() {
    local failed=0
    local total=0
    local passed=0
    
    echo "========================================"
    echo "MSP Release State Test Suite"
    echo "========================================"
    echo ""
    
    # Find all test case scripts in numeric order
    local case_scripts
    case_scripts=$(find "${cases_dir}" -name "[0-9][0-9]_*.sh" | sort)
    
    if [[ -z "$case_scripts" ]]; then
        echo "No test cases found in ${cases_dir}" >&2
        exit 1
    fi
    
    for case_script in $case_scripts; do
        total=$((total + 1))
        if run_test_case "${case_script}"; then
            passed=$((passed + 1))
            echo -e "${GREEN}[PASS]${NC} $(basename "${case_script}")"
        else
            failed=$((failed + 1))
            echo -e "${RED}[FAIL]${NC} $(basename "${case_script}")"
        fi
        echo ""
    done
    
    echo "========================================"
    echo "Test Summary: ${passed}/${total} passed"
    echo "========================================"
    
    if [[ $failed -ne 0 ]]; then
        echo -e "${RED}Some tests FAILED.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All tests PASSED.${NC}"
    exit 0
}

run_test_case() {
    local case_script="$1"
    local case_name
    case_name="$(basename "${case_script}")"
    
    echo "========================================"
    echo "[RUNNING] ${case_name}"
    echo "========================================"
    
    # Create temporary directory for this test
    local tmpdir
    tmpdir="$(mktemp -d)"
    
    # Cleanup function
    cleanup() {
        rm -rf "$tmpdir"
    }
    trap cleanup EXIT
    
    (
        cd "$tmpdir"
        
        # Set up mock log
        export MOCK_LOG="${tmpdir}/mock_invocations.log"
        clear_mock_log
        
        # Copy Scripts directory structure
        # We need to copy the entire repo structure to have proper paths
        local repo_root
        repo_root="$(cd "${script_dir}/../../.." && pwd)"
        
        # Create minimal repo structure
        mkdir -p Scripts/release/{orchestrator,preflight,publish/{pods,spm},verify,utils,config}
        mkdir -p Scripts/lib
        
        # Copy essential scripts
        cp -R "${repo_root}/Scripts/lib"/* Scripts/lib/ 2>/dev/null || true
        cp -R "${repo_root}/Scripts/release/utils"/* Scripts/release/utils/ 2>/dev/null || true
        cp -R "${repo_root}/Scripts/release/orchestrator"/* Scripts/release/orchestrator/ 2>/dev/null || true
        cp -R "${repo_root}/Scripts/release/preflight"/* Scripts/release/preflight/ 2>/dev/null || true
        cp -R "${repo_root}/Scripts/release/publish"/* Scripts/release/publish/ 2>/dev/null || true
        cp -R "${repo_root}/Scripts/release/verify"/* Scripts/release/verify/ 2>/dev/null || true
        cp -R "${repo_root}/Scripts/release/config"/* Scripts/release/config/ 2>/dev/null || true
        
        # Copy main release script
        cp "${repo_root}/Scripts/msp-release.sh" Scripts/msp-release.sh 2>/dev/null || true
        
        # Make scripts executable
        find Scripts -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        
        # Set up mock PATH (mocks come first)
        export PATH="${mock_dir}:${PATH}"
        
        # Set up environment for tests
        export ROOT_DIR="${tmpdir}"
        export DRY_RUN="${DRY_RUN:-true}"
        export MSP_STATE_DISABLE="${MSP_STATE_DISABLE:-}"
        export NO_ANSI="${NO_ANSI:-true}"
        
        # Source the test case
        # shellcheck source=/dev/null
        source "${case_script}"
    )
    
    local exit_code=$?
    trap - EXIT
    cleanup
    
    return $exit_code
}

main "$@"

