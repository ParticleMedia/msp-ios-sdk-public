#!/usr/bin/env bash
set -euo pipefail

# Script: list-context.sh
# Purpose: List and filter context entries, manage the context index
# Usage: ./Scripts/context/list-context.sh [OPTIONS]

# Get script directory and load common functions
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration
# shellcheck disable=SC2155
readonly REPO_ROOT=$(get_repo_root)
readonly CONTEXT_DIR="$REPO_ROOT/.context"
readonly INDEX_FILE="$CONTEXT_DIR/index.md"

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

List and filter context entries from the knowledge base.

Options:
  --domain DOMAIN    Filter by domain (release|ci|integration|compatibility)
  --layer LAYER      Filter by layer (business|experience|tech)
  --tag TAG          Filter by tag
  --search KEYWORD   Search in titles and content
  --view VIEW        Display view: by-layer|by-domain|all (default: all)
  --rebuild          Rebuild the index.md file
  -h, --help         Show this help message

Examples:
  $0                          # List all contexts
  $0 --domain release         # List only release contexts
  $0 --layer experience       # List only experience layer contexts
  $0 --tag pod                # List contexts tagged with 'pod'
  $0 --search crash           # Search for 'crash' in contexts
  $0 --rebuild                # Rebuild the index

EOF
    exit 0
}

# Parse command line arguments
DOMAIN_FILTER=""
LAYER_FILTER=""
TAG_FILTER=""
SEARCH_KEYWORD=""
VIEW="all"
REBUILD=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)
                DOMAIN_FILTER="$2"
                validate_domain "$DOMAIN_FILTER" || exit 1
                shift 2
                ;;
            --layer)
                LAYER_FILTER="$2"
                validate_layer "$LAYER_FILTER" || exit 1
                shift 2
                ;;
            --tag)
                TAG_FILTER="$2"
                shift 2
                ;;
            --search)
                SEARCH_KEYWORD="$2"
                shift 2
                ;;
            --view)
                VIEW="$2"
                if [[ ! "$VIEW" =~ ^(by-layer|by-domain|all)$ ]]; then
                    echo "ERROR: Invalid view: $VIEW" >&2
                    echo "Valid views: by-layer, by-domain, all" >&2
                    exit 1
                fi
                shift 2
                ;;
            --rebuild)
                REBUILD=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                usage
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR: Not a git repository" >&2
        return 1
    fi

    if [ ! -d "$CONTEXT_DIR" ]; then
        echo "ERROR: .context directory not found: $CONTEXT_DIR" >&2
        return 1
    fi

    return 0
}

# Main entry point
main() {
    parse_args "$@"

    if ! validate_prerequisites; then
        exit 1
    fi

    # T045: Rebuild index if requested
    if [ "$REBUILD" = true ]; then
        echo "🔄 Rebuilding index..."
        update_index
        echo "✅ Index rebuilt successfully"
        echo "   Location: $INDEX_FILE"
        exit 0
    fi

    # List contexts
    echo "📚 Context Library"
    echo ""

    # T040: Collect all contexts
    local all_contexts
    all_contexts=$(collect_all_contexts)

    if [ -z "$all_contexts" ]; then
        echo "ℹ️  No contexts found"
        exit 0
    fi

    # T041-T044: Apply filters
    local filtered_contexts
    filtered_contexts=$(apply_filters "$all_contexts")

    if [ -z "$filtered_contexts" ]; then
        echo "ℹ️  No contexts match the filter criteria"
        exit 0
    fi

    # Display results based on view
    display_contexts "$filtered_contexts" "$VIEW"
}

# Collect all context files
# Returns: filepath|id|domain|layer|title|tags|created|status format
collect_all_contexts() {
    local results=""

    for domain in release ci integration compatibility; do
        local domain_dir="$CONTEXT_DIR/$domain"

        if [ ! -d "$domain_dir" ]; then
            continue
        fi

        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                local id domain_val layer title tags created status

                id=$(grep "^id:" "$file" 2>/dev/null | sed 's/id: *//' || echo "")
                domain_val=$(grep "^domain:" "$file" 2>/dev/null | sed 's/domain: *//' || echo "")
                layer=$(grep "^layer:" "$file" 2>/dev/null | sed 's/layer: *//' || echo "")
                title=$(grep "^title:" "$file" 2>/dev/null | sed 's/title: *//' || echo "")
                tags=$(grep "^tags:" "$file" 2>/dev/null | sed 's/tags: *//' || echo "")
                created=$(grep "^created:" "$file" 2>/dev/null | sed 's/created: *//' || echo "")
                status=$(grep "^status:" "$file" 2>/dev/null | sed 's/status: *//' || echo "")

                # Only include active contexts by default
                if [ "$status" = "active" ] || [ -z "$status" ]; then
                    results="$results$file|$id|$domain_val|$layer|$title|$tags|$created|$status"$'\n'
                fi
            fi
        done < <(find "$domain_dir" -name "ctx-*.md" -type f -print0 2>/dev/null)
    done

    echo "$results"
}

# Apply filters to context list
# Args: all_contexts (pipe-delimited format)
# Returns: filtered contexts
apply_filters() {
    local contexts="$1"
    local result="$contexts"

    # T041: Domain filter
    if [ -n "$DOMAIN_FILTER" ]; then
        result=$(echo "$result" | grep "|$DOMAIN_FILTER|" || true)
    fi

    # T042: Layer filter
    if [ -n "$LAYER_FILTER" ]; then
        result=$(echo "$result" | awk -F'|' -v layer="$LAYER_FILTER" '$4 == layer' || true)
    fi

    # T043: Tag filter
    if [ -n "$TAG_FILTER" ]; then
        result=$(echo "$result" | grep -i "$TAG_FILTER" || true)
    fi

    # T044: Search keyword
    if [ -n "$SEARCH_KEYWORD" ]; then
        result=$(echo "$result" | grep -i "$SEARCH_KEYWORD" || true)
    fi

    echo "$result"
}

# Display contexts based on view
# Args: contexts (pipe-delimited format), view type
display_contexts() {
    local contexts="$1"
    local view="$2"

    case "$view" in
        by-layer)
            display_by_layer "$contexts"
            ;;
        by-domain)
            display_by_domain "$contexts"
            ;;
        all)
            display_by_layer "$contexts"
            echo ""
            display_by_domain "$contexts"
            ;;
    esac
}

# Display contexts grouped by layer
display_by_layer() {
    local contexts="$1"

    echo "## By Layer"
    echo ""

    for layer in business experience tech; do
        local layer_contexts
        layer_contexts=$(echo "$contexts" | awk -F'|' -v layer="$layer" '$4 == layer')

        local count
        count=$(echo "$layer_contexts" | grep -c "^" || echo "0")
        if [ "$count" -eq 1 ] && [ -z "$layer_contexts" ]; then
            count=0
        fi

        case "$layer" in
            business)
                echo "### Business ($count)"
                echo "业务知识：产品需求、业务规则、用户场景"
                ;;
            experience)
                echo "### Experience ($count)"
                echo "经验教训：调试过程、踩坑记录、解决方案"
                ;;
            tech)
                echo "### Tech ($count)"
                echo "技术知识：API 用法、架构设计、设计模式"
                ;;
        esac
        echo ""

        if [ "$count" -gt 0 ]; then
            echo "| ID | Title | Domain | Created |"
            echo "|----|-------|--------|---------|"

            echo "$layer_contexts" | while IFS='|' read -r _filepath id domain _layer title _tags created _status; do
                if [ -n "$id" ]; then
                    echo "| $id | $title | $domain | $created |"
                fi
            done
        else
            echo "_No entries_"
        fi
        echo ""
    done
}

# Display contexts grouped by domain
display_by_domain() {
    local contexts="$1"

    echo "## By Domain"
    echo ""

    for domain in release ci integration compatibility; do
        local domain_contexts
        domain_contexts=$(echo "$contexts" | grep "|$domain|" || true)

        local count
        count=$(echo "$domain_contexts" | grep -c "^" || echo "0")
        if [ "$count" -eq 1 ] && [ -z "$domain_contexts" ]; then
            count=0
        fi

        case "$domain" in
            release)
                echo "### Release ($count)"
                ;;
            ci)
                echo "### CI ($count)"
                ;;
            integration)
                echo "### Integration ($count)"
                ;;
            compatibility)
                echo "### Compatibility ($count)"
                ;;
        esac
        echo ""

        if [ "$count" -gt 0 ]; then
            echo "| ID | Title | Layer | Created |"
            echo "|----|-------|-------|---------|"

            echo "$domain_contexts" | while IFS='|' read -r _filepath id _domain layer title _tags created _status; do
                if [ -n "$id" ]; then
                    echo "| $id | $title | $layer | $created |"
                fi
            done
        else
            echo "_No entries_"
        fi
        echo ""
    done
}

main "$@"
