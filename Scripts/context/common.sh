#!/usr/bin/env bash
# Common functions for context management scripts
# This file should be sourced by other scripts: source "$(dirname "$0")/common.sh"

# Get repository root directory
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Get current date in YYYY-MM-DD format
get_current_date() {
    date +%Y-%m-%d
}

# Generate next context ID for a given domain
# Usage: generate_context_id <domain>
generate_context_id() {
    local domain="$1"
    local repo_root
    repo_root=$(get_repo_root)
    local context_dir="$repo_root/.context/$domain"

    # Find highest sequence number
    local max_seq=0
    if [ -d "$context_dir" ]; then
        for file in "$context_dir"/ctx-"$domain"-*.md; do
            if [ -f "$file" ]; then
                # Extract sequence number from filename
                local seq
                seq=$(basename "$file" .md | sed "s/ctx-$domain-//")
                # Remove leading zeros for arithmetic comparison
                seq=$((10#$seq 2>/dev/null || echo 0))
                if [ "$seq" -gt "$max_seq" ]; then
                    max_seq=$seq
                fi
            fi
        done
    fi

    # Increment and format with leading zeros
    local next_seq=$((max_seq + 1))
    printf "ctx-%s-%03d" "$domain" "$next_seq"
}

# Validate domain exists
# Usage: validate_domain <domain>
validate_domain() {
    local domain="$1"
    local repo_root
    repo_root=$(get_repo_root)
    local domain_config="$repo_root/.context/$domain/_domain.md"

    if [ ! -f "$domain_config" ]; then
        echo "ERROR: Domain '$domain' is not configured" >&2
        echo "Available domains: release, ci, integration, compatibility" >&2
        return 1
    fi
    return 0
}

# Validate layer value
# Usage: validate_layer <layer>
validate_layer() {
    local layer="$1"
    case "$layer" in
        business|experience|tech)
            return 0
            ;;
        *)
            echo "ERROR: Invalid layer '$layer'" >&2
            echo "Valid layers: business, experience, tech" >&2
            return 1
            ;;
    esac
}

# Validate context ID format
# Usage: validate_context_id <id>
validate_context_id() {
    local id="$1"

    # Check format: ctx-{domain}-{3-digit-number}
    if ! echo "$id" | grep -qE '^ctx-[a-z]+-[0-9]{3}$'; then
        echo "ERROR: Invalid context ID format: $id" >&2
        echo "Expected format: ctx-{domain}-{3-digit-number}" >&2
        return 1
    fi
    return 0
}

# Extract domain from context ID
# Usage: get_domain_from_id <id>
get_domain_from_id() {
    local id="$1"
    echo "$id" | sed 's/^ctx-\([^-]*\)-.*$/\1/'
}

# Update index.md after adding/modifying context
# Usage: update_index
update_index() {
    local repo_root
    repo_root=$(get_repo_root)
    local index_file="$repo_root/.context/index.md"
    local temp_file
    temp_file=$(mktemp)

    # Header
    echo "# Context Index" > "$temp_file"
    echo "" >> "$temp_file"
    echo "> **Last Updated**: $(get_current_date)" >> "$temp_file"

    # Count total entries
    local total=0
    for domain in release ci integration compatibility; do
        local count
        count=$(find "$repo_root/.context/$domain" -name "ctx-*.md" 2>/dev/null | wc -l | tr -d ' ')
        total=$((total + count))
    done
    echo "> **Total Entries**: $total" >> "$temp_file"
    echo "" >> "$temp_file"

    # Count by layer
    local business_count=0
    local experience_count=0
    local tech_count=0
    for domain in release ci integration compatibility; do
        for file in "$repo_root/.context/$domain"/ctx-*.md; do
            if [ -f "$file" ]; then
                local layer
                layer=$(grep "^layer:" "$file" | sed 's/layer: *//')
                case "$layer" in
                    business) business_count=$((business_count + 1)) ;;
                    experience) experience_count=$((experience_count + 1)) ;;
                    tech) tech_count=$((tech_count + 1)) ;;
                esac
            fi
        done
    done

    echo "## By Layer" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "### Business ($business_count)" >> "$temp_file"
    echo "业务知识：产品需求、业务规则、用户场景" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "### Experience ($experience_count)" >> "$temp_file"
    echo "经验教训：调试过程、踩坑记录、解决方案" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "### Tech ($tech_count)" >> "$temp_file"
    echo "技术知识：API 用法、架构设计、设计模式" >> "$temp_file"
    echo "" >> "$temp_file"

    echo "## By Domain" >> "$temp_file"
    echo "" >> "$temp_file"

    # Generate tables for each domain
    for domain in release ci integration compatibility; do
        local domain_name
        case "$domain" in
            release) domain_name="Release" ;;
            ci) domain_name="CI" ;;
            integration) domain_name="Integration" ;;
            compatibility) domain_name="Compatibility" ;;
        esac

        local count
        count=$(find "$repo_root/.context/$domain" -name "ctx-*.md" 2>/dev/null | wc -l | tr -d ' ')
        echo "### $domain_name ($count)" >> "$temp_file"
        echo "| ID | Title | Layer | Tags | Created | Status |" >> "$temp_file"
        echo "|----|-------|-------|------|---------|--------|" >> "$temp_file"

        if [ "$count" -eq 0 ]; then
            echo "| - | No entries yet | - | - | - | - |" >> "$temp_file"
        else
            # List all context files
            for file in "$repo_root/.context/$domain"/ctx-*.md; do
                if [ -f "$file" ]; then
                    local id title layer tags created status
                    id=$(grep "^id:" "$file" | sed 's/id: *//')
                    title=$(grep "^title:" "$file" | sed 's/title: *//')
                    layer=$(grep "^layer:" "$file" | sed 's/layer: *//')
                    tags=$(grep "^tags:" "$file" | sed 's/tags: *//')
                    created=$(grep "^created:" "$file" | sed 's/created: *//')
                    status=$(grep "^status:" "$file" | sed 's/status: *//')

                    echo "| $id | $title | $layer | $tags | $created | $status |" >> "$temp_file"
                fi
            done
        fi
        echo "" >> "$temp_file"
    done

    # Recent updates section (placeholder)
    echo "## Recent Updates" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "| ID | Title | Updated | Change |" >> "$temp_file"
    echo "|----|-------|---------|--------|" >> "$temp_file"
    echo "| - | Run with --rebuild to regenerate | - | - |" >> "$temp_file"

    # Atomic replace
    mv "$temp_file" "$index_file"
}

# Escape special characters for sed
escape_sed() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}
