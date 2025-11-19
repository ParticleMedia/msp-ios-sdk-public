#!/bin/bash
# Validation helper functions for MSP iOS SDK build system
# Provides standardized print functions for validators

# Source colors if not already sourced
if [[ -z "${RED:-}" ]] || [[ -z "${GREEN:-}" ]] || [[ -z "${YELLOW:-}" ]] || [[ -z "${NC:-}" ]]; then
    # Try to source colors.sh
    local colors_path
    colors_path="$(dirname "${BASH_SOURCE[0]}")/colors.sh"
    if [[ -f "$colors_path" ]]; then
        # shellcheck source=Scripts/lib/colors.sh
        source "$colors_path"
    else
        # Fallback color definitions
        export RED='\033[0;31m'
        export GREEN='\033[0;32m'
        export YELLOW='\033[1;33m'
        export NC='\033[0m'
    fi
fi

# Initialize counters if not already set
init_validation_counters() {
    : "${FAIL_COUNT:=0}"
    : "${WARN_COUNT:=0}"
    : "${OK_COUNT:=0}"
    export FAIL_COUNT WARN_COUNT OK_COUNT
}

# Print OK message
# Usage: print_ok "message"
print_ok() {
    printf "${GREEN}✓${NC} %s\n" "$1"
    ((OK_COUNT++)) || true
}

# Print warning message
# Usage: print_warn "message"
print_warn() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
    ((WARN_COUNT++)) || true
}

# Print failure message
# Usage: print_fail "message"
print_fail() {
    printf "${RED}✗${NC} %s\n" "$1"
    ((FAIL_COUNT++)) || true
}

# Print section header
# Usage: print_section "Section Title"
print_section() {
    echo ""
    echo "============================================================================"
    echo "$1"
    echo "============================================================================"
}

# Print validation summary
# Usage: print_validation_summary
print_validation_summary() {
    echo ""
    echo "============================================================================"
    echo "Summary"
    echo "============================================================================"
    echo ""
    printf "${GREEN}✓ OK:${NC}     %d\n" "${OK_COUNT:-0}"
    printf "${YELLOW}⚠ WARN:${NC}  %d\n" "${WARN_COUNT:-0}"
    printf "${RED}✗ FAIL:${NC}  %d\n" "${FAIL_COUNT:-0}"
    echo ""
}

# Determine exit code based on validation results
# Usage: get_validation_exit_code
# Returns: 0 if no failures, 1 if failures
get_validation_exit_code() {
    if [[ "${FAIL_COUNT:-0}" -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Print final validation result
# Usage: print_validation_result
print_validation_result() {
    if [[ "${FAIL_COUNT:-0}" -gt 0 ]]; then
        echo -e "${RED}Validation FAILED${NC} - Fix errors before proceeding"
        return 1
    elif [[ "${WARN_COUNT:-0}" -gt 0 ]]; then
        echo -e "${YELLOW}Validation PASSED with warnings${NC} - Review warnings above"
        return 0
    else
        echo -e "${GREEN}Validation PASSED${NC} - All checks passed"
        return 0
    fi
}

