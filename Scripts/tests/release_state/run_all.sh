#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

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
    
    echo "[DEBUG] Test sandbox: $tmpdir"
    
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
        # Use ONLY the real repository Scripts/ directory (single source)
        local repo_root
        repo_root="$(cd "${script_dir}/../../.." && pwd)"
        
        # Fully clean sandbox Scripts directory before copying
        rm -rf "$tmpdir/Scripts"
        mkdir -p "$tmpdir/Scripts"
        
        # ONE AND ONLY ONE copy command - copy entire Scripts/ directory from repository
        cp -R "${repo_root}/Scripts"/* "$tmpdir/Scripts/" 2>/dev/null || {
            echo "[FATAL TEST ERROR] Failed to copy Scripts directory from ${repo_root}/Scripts" >&2
            exit 99
        }
        
        # Strict verification of required files
        REQUIRED_FILES=(
            "$tmpdir/Scripts/msp-release.sh"
            "$tmpdir/Scripts/lib/colors.sh"
            "$tmpdir/Scripts/lib/logging.sh"
            "$tmpdir/Scripts/release/utils/state.sh"
            "$tmpdir/Scripts/release/orchestrator/modular.sh"
        )
        
        for f in "${REQUIRED_FILES[@]}"; do
            if [[ ! -f "$f" ]]; then
                echo "[FATAL TEST ERROR] Missing required file: $f" >&2
                exit 99
            fi
        done
        
        echo "[DEBUG] Dumping directory tree after copy:"
        find "$tmpdir/Scripts" -maxdepth 4 -type f | sed "s|$tmpdir||" | sort
        
        echo "[DEBUG] msp-release.sh location: $tmpdir/Scripts/msp-release.sh"
        
        # Make scripts executable
        find Scripts -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        
        # Create minimal .git directory for git commands
        mkdir -p .git
        if [[ ! -f .git/HEAD ]]; then
            echo "ref: refs/heads/main" > .git/HEAD
        fi
        if [[ ! -f .git/config ]]; then
            cat > .git/config <<'EOF'
[core]
    repositoryformatversion = 0
EOF
        fi
        
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

