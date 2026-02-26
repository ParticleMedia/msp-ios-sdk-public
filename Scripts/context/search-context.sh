#!/usr/bin/env bash
set -euo pipefail

# Script: search-context.sh
# Purpose: Search for relevant context entries based on keywords
# Usage: ./Scripts/context/search-context.sh <keywords...>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
readonly REPO_ROOT
readonly CONTEXT_DIR="$REPO_ROOT/.context"

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <keywords...>

Search for relevant context entries based on keywords.

Arguments:
  keywords...        One or more keywords to search for

Options:
  --domain DOMAIN    Limit search to specific domain (release|ci|integration|compatibility)
  --layer LAYER      Limit search to specific layer (business|experience|tech)
  --limit N          Maximum number of results to return (default: 5)
  --format FORMAT    Output format: summary|full|ids (default: summary)
  -h, --help         Show this help message

Examples:
  $0 pod release                    # Search for "pod" and "release"
  $0 --domain release crash         # Search "crash" in release domain only
  $0 --layer experience build fail  # Search in experience layer only
  $0 --format ids pod               # Output only context IDs

EOF
    exit 0
}

# Parse command line arguments
DOMAIN_FILTER=""
LAYER_FILTER=""
LIMIT=5
FORMAT="summary"
KEYWORDS=()

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
            --limit)
                LIMIT="$2"
                shift 2
                ;;
            --format)
                FORMAT="$2"
                if [[ ! "$FORMAT" =~ ^(summary|full|ids)$ ]]; then
                    echo "ERROR: Invalid format: $FORMAT" >&2
                    echo "Valid formats: summary, full, ids" >&2
                    exit 1
                fi
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo "ERROR: Unknown option: $1" >&2
                usage
                ;;
            *)
                KEYWORDS+=("$1")
                shift
                ;;
        esac
    done

    # Validate we have at least one keyword
    if [ ${#KEYWORDS[@]} -eq 0 ]; then
        echo "ERROR: At least one keyword is required" >&2
        usage
    fi
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

    echo "🔍 Searching for: ${KEYWORDS[*]}"
    if [ -n "$DOMAIN_FILTER" ]; then
        echo "   Domain: $DOMAIN_FILTER"
    fi
    if [ -n "$LAYER_FILTER" ]; then
        echo "   Layer: $LAYER_FILTER"
    fi
    echo ""

    # T034: Determine relevant domains from keywords
    local relevant_domains
    if [ -n "$DOMAIN_FILTER" ]; then
        relevant_domains="$DOMAIN_FILTER"
    else
        relevant_domains=$(map_keywords_to_domains "${KEYWORDS[@]}")
    fi

    if [ -z "$relevant_domains" ]; then
        echo "ℹ️  No matching domains found. Searching all domains..."
        relevant_domains="release ci integration compatibility"
    fi

    # T035: Search context files using grep
    local search_results
    search_results=$(search_contexts "$relevant_domains" "${KEYWORDS[@]}")

    if [ -z "$search_results" ]; then
        echo "ℹ️  No matching contexts found."
        exit 0
    fi

    # T036: Sort by relevance (match count)
    local sorted_results
    sorted_results=$(sort_by_relevance "$search_results" "${KEYWORDS[@]}")

    # Display results based on format
    display_results "$sorted_results" "$FORMAT" "$LIMIT"
}

# Map keywords to relevant domains based on _domain.md configurations
# Returns: Space-separated list of domain names
map_keywords_to_domains() {
    local keywords=("$@")
    local domains=""

    for domain in release ci integration compatibility; do
        local domain_config="$CONTEXT_DIR/$domain/_domain.md"

        if [ ! -f "$domain_config" ]; then
            continue
        fi

        # Extract keywords from domain config
        local domain_keywords
        domain_keywords=$(grep "^keywords:" "$domain_config" | sed 's/keywords: *\[//' | sed 's/\]//' | tr ',' '\n' | tr -d ' ')

        # Check if any search keyword matches domain keywords
        for search_kw in "${keywords[@]}"; do
            local search_lower
            search_lower=$(echo "$search_kw" | tr '[:upper:]' '[:lower:]')

            if echo "$domain_keywords" | grep -qi "$search_lower"; then
                # Add domain if not already added
                if ! echo "$domains" | grep -qw "$domain"; then
                    domains="$domains $domain"
                fi
                break
            fi
        done
    done

    # Trim leading spaces
    echo "${domains# }"
}

# Search context files for keywords
# Args: domains (space-separated), keywords...
# Returns: Lines with format: filepath|match_count
search_contexts() {
    local domains="$1"
    shift
    local keywords=("$@")

    # Build a regex pattern from keywords (case insensitive)
    local pattern=""
    for kw in "${keywords[@]}"; do
        if [ -z "$pattern" ]; then
            pattern="$kw"
        else
            pattern="$pattern|$kw"
        fi
    done

    # Search in each domain
    # shellcheck disable=SC2086 -- intentional word-splitting: domains is a space-delimited name list
    for domain in $domains; do
        local domain_dir="$CONTEXT_DIR/$domain"

        if [ ! -d "$domain_dir" ]; then
            continue
        fi

        # Find all context files
        while IFS= read -r -d '' file; do
            # Apply layer filter if specified
            if [ -n "$LAYER_FILTER" ]; then
                local file_layer
                file_layer=$(grep "^layer:" "$file" 2>/dev/null | sed 's/layer: *//' || echo "")
                if [ "$file_layer" != "$LAYER_FILTER" ]; then
                    continue
                fi
            fi

            # Count matches (case insensitive)
            local match_count
            match_count=$(grep -i -o -E "$pattern" "$file" 2>/dev/null | wc -l | tr -d ' ')

            if [ "$match_count" -gt 0 ]; then
                echo "$file|$match_count"
            fi
        done < <(find "$domain_dir" -name "ctx-*.md" -type f -print0 2>/dev/null)
    done
}

# Sort results by match count (descending)
# Args: search_results (filepath|count format), keywords...
# Returns: Sorted results
sort_by_relevance() {
    local results="$1"
    shift

    # Sort by match count (second field, numeric, descending)
    echo "$results" | sort -t'|' -k2 -n -r
}

# Display search results based on format
# Args: sorted_results, format, limit
display_results() {
    local results="$1"
    local format="$2"
    local limit="$3"

    local count=0

    while IFS='|' read -r filepath match_count; do
        if [ "$count" -ge "$limit" ]; then
            break
        fi

        case "$format" in
            ids)
                # Extract context ID from filename
                basename "$filepath" .md
                ;;
            summary)
                # Display summary: ID, title, match count
                local context_id
                local title
                local domain
                local layer

                context_id=$(basename "$filepath" .md)
                title=$(grep "^title:" "$filepath" | sed 's/title: *//')
                domain=$(grep "^domain:" "$filepath" | sed 's/domain: *//')
                layer=$(grep "^layer:" "$filepath" | sed 's/layer: *//')

                echo "[$context_id] $title"
                echo "  Domain: $domain | Layer: $layer | Matches: $match_count"
                echo ""
                ;;
            full)
                # Display full context
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                cat "$filepath"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                ;;
        esac

        count=$((count + 1))
    done <<< "$results"

    if [ "$count" -eq 0 ]; then
        echo "ℹ️  No results to display"
    else
        echo "📊 Showing $count result(s)"
    fi
}

main "$@"
