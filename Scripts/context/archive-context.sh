#!/usr/bin/env bash
set -euo pipefail

# Script: archive-context.sh
# Purpose: Archive (soft-delete) a context entry by changing its status
# Usage: ./Scripts/context/archive-context.sh <context-id>

# Get script directory and load common functions
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration
# shellcheck disable=SC2155
readonly REPO_ROOT=$(get_repo_root)
readonly CONTEXT_DIR="$REPO_ROOT/.context"

# Usage information
usage() {
    cat <<EOF
Usage: $0 <context-id>

Archive a context entry (soft-delete by changing status to 'archived').

Arguments:
  context-id         The context ID to archive (e.g., ctx-release-001)

Options:
  -h, --help         Show this help message

Examples:
  $0 ctx-release-001              # Archive ctx-release-001
  $0 ctx-ci-005                   # Archive ctx-ci-005

Note: Archived contexts are not deleted, just marked as inactive.
They won't appear in list-context.sh but files remain in .context/

EOF
    exit 0
}

# Parse command line arguments
CONTEXT_ID=""

parse_args() {
    if [[ $# -eq 0 ]]; then
        echo "ERROR: Context ID required" >&2
        usage
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            *)
                if [ -z "$CONTEXT_ID" ]; then
                    CONTEXT_ID="$1"
                else
                    echo "ERROR: Multiple context IDs not supported" >&2
                    usage
                fi
                shift
                ;;
        esac
    done

    # Validate context ID format
    if ! validate_context_id "$CONTEXT_ID"; then
        exit 1
    fi
}

# Find context file by ID
find_context_file() {
    local context_id="$1"
    local domain
    domain=$(get_domain_from_id "$context_id")

    local context_file="$CONTEXT_DIR/$domain/$context_id.md"

    if [ ! -f "$context_file" ]; then
        echo "ERROR: Context file not found: $context_file" >&2
        return 1
    fi

    echo "$context_file"
}

# Archive context by changing status field
archive_context() {
    local context_file="$1"
    local context_id="$2"

    # Check current status
    local current_status
    current_status=$(grep "^status:" "$context_file" | sed 's/status: *//')

    if [ "$current_status" = "archived" ]; then
        echo "ℹ️  Context is already archived: $context_id"
        return 0
    fi

    # Show context info before archiving
    local title
    title=$(grep "^title:" "$context_file" | sed 's/title: *//')

    echo "📋 Context to archive:"
    echo "   ID: $context_id"
    echo "   Title: $title"
    echo "   Status: $current_status → archived"
    echo ""

    printf "Continue with archiving? [y/n]: "
    read -r response

    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "❌ Cancelled"
        return 1
    fi

    # Create backup
    cp "$context_file" "${context_file}.backup"

    # Change status to archived
    if sed -i.tmp 's/^status: *active/status: archived/' "$context_file"; then
        rm "${context_file}.tmp" 2>/dev/null || true
        echo "✅ Context archived successfully"
        echo "   File: $context_file"
        echo "   Backup: ${context_file}.backup"
        echo ""
        echo "To restore, manually change status back to 'active' in the file"
        return 0
    else
        # Restore from backup if sed failed
        mv "${context_file}.backup" "$context_file"
        echo "ERROR: Failed to archive context" >&2
        return 1
    fi
}

# Main entry point
main() {
    parse_args "$@"

    # Find context file
    local context_file
    if ! context_file=$(find_context_file "$CONTEXT_ID"); then
        exit 1
    fi

    # Archive the context
    if archive_context "$context_file" "$CONTEXT_ID"; then
        echo ""
        echo "💡 Tip: Rebuild index to update statistics:"
        echo "   ./Scripts/context/list-context.sh --rebuild"
    else
        exit 1
    fi
}

main "$@"
