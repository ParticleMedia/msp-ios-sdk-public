#!/usr/bin/env bash
set -euo pipefail

# Script: validate-context.sh
# Purpose: Validate context file integrity and format
# Usage: ./Scripts/context/validate-context.sh [context-id]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
readonly REPO_ROOT
readonly CONTEXT_DIR="$REPO_ROOT/.context"

# Validation error count
ERROR_COUNT=0
WARNING_COUNT=0

# Usage information
usage() {
    cat <<EOF
Usage: $0 [context-id]

Validate context file integrity and format.

Arguments:
  context-id         Optional: Validate specific context (e.g., ctx-release-001)
                     If not specified, validates all contexts

Options:
  -h, --help         Show this help message

Examples:
  $0                          # Validate all contexts
  $0 ctx-release-001          # Validate specific context

Validation checks:
  - YAML front matter format
  - Required fields present
  - Field value validity (domain, layer, status)
  - Markdown structure
  - File naming conventions

EOF
    exit 0
}

# Log error
log_error() {
    echo "  ❌ ERROR: $*"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

# Log warning
log_warning() {
    echo "  ⚠️  WARNING: $*"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

# Log success
log_success() {
    echo "  ✅ $*"
}

# Validate a single context file
validate_context_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    echo ""
    echo "📄 Validating: $filename"

    # Check file exists and is readable
    if [ ! -f "$file" ]; then
        log::error "CONTEXT" "File not found"
        return 1
    fi

    if [ ! -r "$file" ]; then
        log::error "CONTEXT" "File not readable"
        return 1
    fi

    # Validate YAML front matter exists
    if ! grep -q "^---$" "$file"; then
        log::error "CONTEXT" "Missing YAML front matter"
        return 1
    fi

    # Extract YAML fields
    local id domain layer title tags created source status confidence

    id=$(grep "^id:" "$file" 2>/dev/null | sed 's/id: *//' || echo "")
    domain=$(grep "^domain:" "$file" 2>/dev/null | sed 's/domain: *//' || echo "")
    layer=$(grep "^layer:" "$file" 2>/dev/null | sed 's/layer: *//' || echo "")
    title=$(grep "^title:" "$file" 2>/dev/null | sed 's/title: *//' || echo "")
    tags=$(grep "^tags:" "$file" 2>/dev/null | sed 's/tags: *//' || echo "")
    created=$(grep "^created:" "$file" 2>/dev/null | sed 's/created: *//' || echo "")
    source=$(grep "^source:" "$file" 2>/dev/null | sed 's/source: *//' || echo "")
    status=$(grep "^status:" "$file" 2>/dev/null | sed 's/status: *//' || echo "")
    confidence=$(grep "^confidence:" "$file" 2>/dev/null | sed 's/confidence: *//' || echo "")

    # Validate required fields
    [ -z "$id" ] && log::error "CONTEXT" "Missing required field: id"
    [ -z "$domain" ] && log::error "CONTEXT" "Missing required field: domain"
    [ -z "$layer" ] && log::error "CONTEXT" "Missing required field: layer"
    [ -z "$title" ] && log::error "CONTEXT" "Missing required field: title"
    [ -z "$created" ] && log::error "CONTEXT" "Missing required field: created"
    [ -z "$status" ] && log::error "CONTEXT" "Missing required field: status"

    # Validate ID format
    if [ -n "$id" ]; then
        if ! validate_context_id "$id" 2>/dev/null; then
            log::error "CONTEXT" "Invalid ID format: $id (expected: ctx-{domain}-{3-digit-number})"
        else
            log::success "CONTEXT" "ID format valid: $id"
        fi
    fi

    # Validate domain
    if [ -n "$domain" ]; then
        if ! validate_domain "$domain" 2>/dev/null; then
            log::error "CONTEXT" "Invalid domain: $domain (expected: release|ci|integration|compatibility)"
        else
            log::success "CONTEXT" "Domain valid: $domain"
        fi
    fi

    # Validate layer
    if [ -n "$layer" ]; then
        if ! validate_layer "$layer" 2>/dev/null; then
            log::error "CONTEXT" "Invalid layer: $layer (expected: business|experience|tech)"
        else
            log::success "CONTEXT" "Layer valid: $layer"
        fi
    fi

    # Validate status
    if [ -n "$status" ]; then
        case "$status" in
            active|archived|deprecated)
                log::success "CONTEXT" "Status valid: $status"
                ;;
            *)
                log::error "CONTEXT" "Invalid status: $status (expected: active|archived|deprecated)"
                ;;
        esac
    fi

    # Validate confidence (optional field)
    if [ -n "$confidence" ]; then
        case "$confidence" in
            high|medium|low)
                log::success "CONTEXT" "Confidence valid: $confidence"
                ;;
            *)
                log::warn "CONTEXT" "Invalid confidence: $confidence (expected: high|medium|low)"
                ;;
        esac
    fi

    # Validate title length
    if [ -n "$title" ]; then
        if [ ${#title} -lt 10 ]; then
            log::warn "CONTEXT" "Title too short (< 10 characters): $title"
        fi
    fi

    # Validate date format (YYYY-MM-DD)
    if [ -n "$created" ]; then
        if ! echo "$created" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            log::error "CONTEXT" "Invalid date format: $created (expected: YYYY-MM-DD)"
        else
            log::success "CONTEXT" "Date format valid: $created"
        fi
    fi

    # Validate filename matches ID
    local expected_filename="${id}.md"
    if [ "$filename" != "$expected_filename" ]; then
        log::error "CONTEXT" "Filename mismatch: $filename (expected: $expected_filename based on ID)"
    fi

    # Check for required sections
    if ! grep -q "^## 问题描述$" "$file" && ! grep -q "^## Problem Description$" "$file"; then
        log::warn "CONTEXT" "Missing section: 问题描述 / Problem Description"
    fi

    if ! grep -q "^## 根因分析$" "$file" && ! grep -q "^## Root Cause" "$file"; then
        log::warn "CONTEXT" "Missing section: 根因分析 / Root Cause Analysis"
    fi

    if ! grep -q "^## 解决方案$" "$file" && ! grep -q "^## Solution$" "$file"; then
        log::warn "CONTEXT" "Missing section: 解决方案 / Solution"
    fi
}

# Main entry point
main() {
    if [[ $# -eq 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi

    echo "🔍 Context Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $# -eq 1 ]]; then
        # Validate specific context
        local context_id="$1"
        local domain
        domain=$(get_domain_from_id "$context_id")
        local context_file="$CONTEXT_DIR/$domain/$context_id.md"

        if [ ! -f "$context_file" ]; then
            echo "ERROR: Context not found: $context_file" >&2
            exit 1
        fi

        validate_context_file "$context_file"
    else
        # Validate all contexts
        local total=0

        for domain in release ci integration compatibility; do
            local domain_dir="$CONTEXT_DIR/$domain"

            if [ ! -d "$domain_dir" ]; then
                continue
            fi

            while IFS= read -r -d '' file; do
                validate_context_file "$file"
                total=$((total + 1))
            done < <(find "$domain_dir" -name "ctx-*.md" -type f -print0 2>/dev/null)
        done

        if [ "$total" -eq 0 ]; then
            echo ""
            echo "ℹ️  No context files found"
        fi
    fi

    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Validation Summary"
    echo ""
    echo "  Errors:   $ERROR_COUNT"
    echo "  Warnings: $WARNING_COUNT"
    echo ""

    if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
        echo "✅ All validations passed!"
        exit 0
    elif [ "$ERROR_COUNT" -eq 0 ]; then
        echo "⚠️  Validation passed with warnings"
        exit 0
    else
        echo "❌ Validation failed with errors"
        exit 1
    fi
}

main "$@"
