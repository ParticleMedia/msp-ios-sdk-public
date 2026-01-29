#!/usr/bin/env bash
set -euo pipefail

# Script: init-context.sh
# Purpose: Initialize context system by extracting release-related experience from commit history
# Usage: ./Scripts/context/init-context.sh [--domain DOMAIN] [--limit N]

# Get script directory and load common functions
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration
# shellcheck disable=SC2155
readonly REPO_ROOT=$(get_repo_root)
readonly CONTEXT_DIR="$REPO_ROOT/.context"

# Default values
DOMAIN_FILTER=""
LIMIT=20

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Initialize context system by extracting experience from commit history.

Options:
  --domain DOMAIN    Only extract commits for specific domain (release|ci|integration|compatibility)
  --limit N          Maximum number of commits to process (default: 20)
  -h, --help         Show this help message

Examples:
  $0                          # Extract up to 20 commits from all domains
  $0 --domain release         # Extract only release-related commits
  $0 --limit 50               # Process up to 50 commits

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)
                DOMAIN_FILTER="$2"
                validate_domain "$DOMAIN_FILTER" || exit 1
                shift 2
                ;;
            --limit)
                LIMIT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                echo "Run '$0 --help' for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# Extract commits from git history
# Returns: Array of commit hashes matching the filter criteria
extract_commits() {
    local pattern

    if [ -n "$DOMAIN_FILTER" ]; then
        # Specific domain filter
        pattern="^fix\\($DOMAIN_FILTER\\):"
    else
        # All supported domains
        pattern="^fix\\((release|ci|integration|compatibility)\\):"
    fi

    # Use git log to find commits matching the pattern
    # Format: hash|subject|body
    git log --all \
        --grep="$pattern" \
        --extended-regexp \
        --format="%H|%s|%b" \
        --max-count="$LIMIT" \
        2>/dev/null || {
            echo "ERROR: Failed to query git log" >&2
            return 1
        }
}

# Filter commits by relevance
# Filters out trivial commits (typos, formatting, minor tweaks)
# Keeps commits that indicate problem-solving (fix, resolve, address, prevent)
filter_candidate_commits() {
    local commits="$1"

    # Filter criteria:
    # - Include: commits with problem-solving keywords
    # - Exclude: trivial changes (typo, format, minor, tweak)

    echo "$commits" | while IFS='|' read -r hash subject body; do
        local text="$subject $body"
        local text_lower
        text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

        # Skip trivial commits
        if echo "$text_lower" | grep -qE '(typo|format|minor|tweak|cleanup|whitespace|indent)'; then
            continue
        fi

        # Keep problem-solving commits
        if echo "$text_lower" | grep -qE '(fix|resolve|address|prevent|crash|fail|error|bug|issue|problem)'; then
            echo "$hash|$subject|$body"
        fi
    done
}

# Extract domain from commit subject
# Input: fix(domain): message
# Output: domain
extract_domain_from_subject() {
    local subject="$1"
    echo "$subject" | sed -n 's/^fix(\([^)]*\)):.*/\1/p'
}

# Show commit details for review
show_commit_details() {
    local hash="$1"
    local subject="$2"
    local body="$3"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Commit: $hash"
    echo "📝 Subject: $subject"
    if [ -n "$body" ]; then
        echo ""
        echo "Details:"
        # Use while loop instead of sed for better shellcheck compatibility
        echo "$body" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
    echo ""
    echo "🔗 Files changed:"
    git diff-tree --no-commit-id --name-only -r "$hash" 2>/dev/null | head -5 | sed 's/^/  /'
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Prompt user for layer classification
# Returns: business, experience, or tech
prompt_for_layer() {
    local subject="$1"
    local body="$2"

    echo ""
    echo "🏷️  Please classify this context into a layer:"
    echo ""
    echo "  [b] business    - 业务知识: 产品需求、业务规则、用户场景"
    echo "  [e] experience  - 经验教训: 调试过程、踩坑记录、解决方案"
    echo "  [t] tech        - 技术知识: API 用法、架构设计、设计模式"
    echo ""

    # Auto-suggest based on keywords
    local text="$subject $body"
    local text_lower
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    local suggestion=""
    if echo "$text_lower" | grep -qE '(product|requirement|user|business|feature|spec)'; then
        suggestion="business"
    elif echo "$text_lower" | grep -qE '(debug|investigate|fix|resolve|crash|error|issue|problem|troubleshoot)'; then
        suggestion="experience"
    elif echo "$text_lower" | grep -qE '(api|architecture|design|pattern|refactor|implement|algorithm)'; then
        suggestion="tech"
    else
        suggestion="experience"  # Default to experience for fixes
    fi

    echo "💡 Suggested: $suggestion"
    echo ""

    while true; do
        printf "Select layer [b/e/t] (default: %s): " "${suggestion:0:1}"
        read -r choice

        # Use suggestion if empty
        if [ -z "$choice" ]; then
            choice="${suggestion:0:1}"
        fi

        case "$choice" in
            b|B|business)
                echo "business"
                return 0
                ;;
            e|E|experience)
                echo "experience"
                return 0
                ;;
            t|T|tech)
                echo "tech"
                return 0
                ;;
            *)
                echo "❌ Invalid choice. Please enter b, e, or t."
                ;;
        esac
    done
}

# Interactive confirmation for a single commit
# Returns: 0 if user wants to create context, 1 if skip
confirm_commit() {
    local hash="$1"
    local subject="$2"
    local body="$3"

    show_commit_details "$hash" "$subject" "$body"

    echo ""
    printf "Create context for this commit? [y/n/q] (q=quit): "
    read -r response

    case "$response" in
        y|Y|yes)
            return 0
            ;;
        q|Q|quit)
            echo "⏹️  Quitting..."
            exit 0
            ;;
        *)
            echo "⏭️  Skipping..."
            return 1
            ;;
    esac
}

# Generate context file from commit
# Args: hash, subject, body, domain, layer
# Returns: 0 on success, 1 on failure
generate_context_file() {
    local hash="$1"
    local subject="$2"
    local body="$3"
    local domain="$4"
    local layer="$5"

    # Validate inputs
    if [ -z "$hash" ] || [ -z "$subject" ] || [ -z "$domain" ] || [ -z "$layer" ]; then
        echo "ERROR: Missing required arguments for generate_context_file" >&2
        return 1
    fi

    # Validate domain
    if ! validate_domain "$domain"; then
        echo "ERROR: Invalid domain: $domain" >&2
        return 1
    fi

    # Validate layer
    if ! validate_layer "$layer"; then
        echo "ERROR: Invalid layer: $layer" >&2
        return 1
    fi

    # Verify commit exists
    if ! git cat-file -e "$hash" 2>/dev/null; then
        echo "ERROR: Commit not found: $hash" >&2
        return 1
    fi

    # Generate context ID
    local context_id
    context_id=$(generate_context_id "$domain")
    if [ -z "$context_id" ]; then
        echo "ERROR: Failed to generate context ID" >&2
        return 1
    fi

    # Extract title from subject (remove fix(domain): prefix)
    local title
    # Use sed to extract title, fallback to full subject if pattern doesn't match
    title=$(echo "$subject" | sed -n 's/^fix([^)]*): *//p')
    if [ -z "$title" ]; then
        title="$subject"
    fi

    # Get current date
    local created_date
    created_date=$(get_current_date)

    # Create context file
    local context_file="$CONTEXT_DIR/$domain/$context_id.md"

    # Generate content
    cat > "$context_file" <<EOF
---
id: $context_id
title: $title
layer: $layer
domain: $domain
tags: [fix, $domain]
created: $created_date
source: commit:$hash
status: active
confidence: high
---

# $title

## 问题描述

${body:-从 commit $hash 提取的修复}

## 根因分析

_需要补充: 分析问题的根本原因_

## 解决方案

参见 commit $hash 的修改。

## 适用场景

描述什么情况下这个上下文是相关的。

## 相关资源

- 相关 commit: $hash
- 相关文件: $(git diff-tree --no-commit-id --name-only -r "$hash" 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')
EOF

    # Check if file was created successfully
    if [ -f "$context_file" ]; then
        echo "✅ Created: $context_file"
        return 0
    else
        echo "ERROR: Failed to create context file: $context_file" >&2
        return 1
    fi
}

# Validate prerequisites
validate_prerequisites() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR: Not a git repository" >&2
        echo "Please run this script from within a git repository" >&2
        return 1
    fi

    # Check if .context directory exists
    if [ ! -d "$CONTEXT_DIR" ]; then
        echo "ERROR: .context directory not found: $CONTEXT_DIR" >&2
        echo "Please run setup first" >&2
        return 1
    fi

    # Check if common.sh functions are available
    if ! command -v generate_context_id >/dev/null 2>&1; then
        echo "ERROR: common.sh functions not loaded" >&2
        return 1
    fi

    return 0
}

# Main entry point
main() {
    parse_args "$@"

    # Validate prerequisites
    if ! validate_prerequisites; then
        exit 1
    fi

    echo "🔍 Scanning commit history for release-related fixes..."
    echo "Domain filter: ${DOMAIN_FILTER:-all}"
    echo "Limit: $LIMIT"
    echo ""

    # Extract commits
    local commits
    if ! commits=$(extract_commits); then
        echo "ERROR: Failed to extract commits from git history" >&2
        exit 1
    fi

    if [ -z "$commits" ]; then
        echo "ℹ️  No matching commits found."
        echo ""
        echo "Tips:"
        echo "  - Ensure commit messages follow Conventional Commits format: fix(domain): message"
        echo "  - Supported domains: release, ci, integration, compatibility"
        exit 0
    fi

    local raw_count
    raw_count=$(echo "$commits" | wc -l | tr -d ' ')
    echo "📝 Found $raw_count commit(s) matching pattern"

    # Filter candidates
    echo "🔎 Filtering for substantial problem-solving commits..."
    local filtered_commits
    filtered_commits=$(filter_candidate_commits "$commits")

    if [ -z "$filtered_commits" ]; then
        echo "ℹ️  No substantial commits found after filtering."
        echo "All commits appear to be trivial changes (typos, formatting, etc.)"
        exit 0
    fi

    local filtered_count
    filtered_count=$(echo "$filtered_commits" | wc -l | tr -d ' ')
    echo "✅ $filtered_count candidate commit(s) after filtering"
    echo ""

    # Display first few commits for verification
    echo "Sample candidates:"
    echo "$filtered_commits" | head -5 | while IFS='|' read -r hash subject body; do
        echo "  - $hash: ${subject:0:60}..."
    done
    echo ""

    # Interactive processing
    echo "🎯 Starting interactive review..."
    echo "For each commit, you'll be asked to:"
    echo "  1. Review commit details"
    echo "  2. Decide whether to create context"
    echo "  3. Classify the context layer (business/experience/tech)"
    echo ""

    local created_count=0
    echo "$filtered_commits" | while IFS='|' read -r hash subject body; do
        if confirm_commit "$hash" "$subject" "$body"; then
            # Get domain from subject
            local domain
            domain=$(extract_domain_from_subject "$subject")

            # Prompt for layer
            local layer
            layer=$(prompt_for_layer "$subject" "$body")

            echo ""
            echo "✅ Creating context..."
            echo "   Domain: $domain"
            echo "   Layer: $layer"
            echo "   Commit: $hash"
            echo ""

            # Generate context file
            if generate_context_file "$hash" "$subject" "$body" "$domain" "$layer"; then
                # Update index
                echo "📇 Updating index..."
                update_index
                created_count=$((created_count + 1))
            else
                echo "❌ Failed to create context for commit $hash"
            fi
            echo ""
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✨ Initialization complete!"
    echo "   Created: $created_count context(s)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
