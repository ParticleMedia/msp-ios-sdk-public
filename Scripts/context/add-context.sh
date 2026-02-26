#!/usr/bin/env bash
set -euo pipefail

# Script: add-context.sh
# Purpose: Manually add a new context entry to the knowledge base
# Usage: ./Scripts/context/add-context.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
readonly REPO_ROOT
readonly CONTEXT_DIR="$REPO_ROOT/.context"

# Colors for better UX (optional, fallback to plain text)
readonly BOLD='\033[1m'
readonly RESET='\033[0m'
readonly CYAN='\033[0;36m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'

# Print section header
print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}${BOLD}$1${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Print info message
print_info() {
    echo -e "${YELLOW}ℹ️  $1${RESET}"
}

# Print success message
print_success() {
    echo -e "${GREEN}✅ $1${RESET}"
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

# Collect domain selection
collect_domain() {
    print_header "1️⃣  选择领域 (Domain)"
    echo ""
    echo "请选择此上下文所属的领域："
    echo ""
    echo "  [1] release       - 发布系统: Pod 发布、版本管理、集成问题"
    echo "  [2] ci            - CI/CD: 构建、自动化流程"
    echo "  [3] integration   - 集成兼容: 编译链接、crash 问题"
    echo "  [4] compatibility - 版本兼容: 迁移升级、兼容性问题"
    echo "  [5] testing       - 测试策略: 单元测试、TDD、测试架构"
    echo "  [6] sources       - 源码开发: Swift 代码、架构、设计模式"
    echo "  [7] architecture  - 系统架构: 模块设计、组织结构"
    echo ""

    while true; do
        printf "选择 [1-7]: "
        read -r choice

        case "$choice" in
            1) echo "release"; return 0 ;;
            2) echo "ci"; return 0 ;;
            3) echo "integration"; return 0 ;;
            4) echo "compatibility"; return 0 ;;
            5) echo "testing"; return 0 ;;
            6) echo "sources"; return 0 ;;
            7) echo "architecture"; return 0 ;;
            *) echo "❌ 无效选择，请输入 1-7" ;;
        esac
    done
}

# Collect layer selection
collect_layer() {
    print_header "2️⃣  选择层级 (Layer)"
    echo ""
    echo "请选择此上下文的知识类型："
    echo ""
    echo "  [b] business    - 业务知识: 产品需求、业务规则、用户场景"
    echo "  [e] experience  - 经验教训: 调试过程、踩坑记录、解决方案"
    echo "  [t] tech        - 技术知识: API 用法、架构设计、设计模式"
    echo ""
    print_info "提示: 大多数问题修复应选择 'experience'"
    echo ""

    while true; do
        printf "选择 [b/e/t] (默认: e): "
        read -r choice

        # Default to experience
        if [ -z "$choice" ]; then
            choice="e"
        fi

        case "$choice" in
            b|B|business) echo "business"; return 0 ;;
            e|E|experience) echo "experience"; return 0 ;;
            t|T|tech) echo "tech"; return 0 ;;
            *) echo "❌ 无效选择，请输入 b, e, 或 t" ;;
        esac
    done
}

# Collect title
collect_title() {
    print_header "3️⃣  问题标题 (Title)"
    echo ""
    echo "请输入简短的问题标题 (一行，清晰描述问题):"
    echo "示例: Pod 发布后使用方编译失败 - FB SDK 静态链接冲突"
    echo ""

    while true; do
        printf "标题: "
        read -r title

        if [ -z "$title" ]; then
            echo "❌ 标题不能为空"
            continue
        fi

        if [ ${#title} -lt 10 ]; then
            echo "❌ 标题太短，请提供更详细的描述 (至少 10 个字符)"
            continue
        fi

        echo "$title"
        return 0
    done
}

# Collect problem description
collect_problem() {
    print_header "4️⃣  问题描述 (Problem Description)"
    echo ""
    echo "描述遇到的问题，包括症状和触发条件。"
    echo "可以输入多行，输入空行结束："
    echo ""

    local problem=""
    local line_count=0

    while true; do
        read -r line
        if [ -z "$line" ] && [ "$line_count" -gt 0 ]; then
            break
        fi
        if [ -n "$line" ]; then
            if [ -z "$problem" ]; then
                problem="$line"
            else
                problem="$problem"$'\n'"$line"
            fi
            line_count=$((line_count + 1))
        fi
    done

    if [ -z "$problem" ]; then
        echo "❌ 问题描述不能为空"
        collect_problem
        return
    fi

    echo "$problem"
}

# Collect root cause analysis
collect_root_cause() {
    print_header "5️⃣  根因分析 (Root Cause Analysis)"
    echo ""
    echo "分析问题的根本原因，解释\"为什么\"会发生。"
    echo "可以输入多行，输入空行结束："
    echo ""

    local root_cause=""
    local line_count=0

    while true; do
        read -r line
        if [ -z "$line" ] && [ "$line_count" -gt 0 ]; then
            break
        fi
        if [ -n "$line" ]; then
            if [ -z "$root_cause" ]; then
                root_cause="$line"
            else
                root_cause="$root_cause"$'\n'"$line"
            fi
            line_count=$((line_count + 1))
        fi
    done

    if [ -z "$root_cause" ]; then
        echo "❌ 根因分析不能为空"
        collect_root_cause
        return
    fi

    echo "$root_cause"
}

# Collect solution
collect_solution() {
    print_header "6️⃣  解决方案 (Solution)"
    echo ""
    echo "描述具体的解决步骤或修复方法。"
    echo "可以输入多行，输入空行结束："
    echo ""

    local solution=""
    local line_count=0

    while true; do
        read -r line
        if [ -z "$line" ] && [ "$line_count" -gt 0 ]; then
            break
        fi
        if [ -n "$line" ]; then
            if [ -z "$solution" ]; then
                solution="$line"
            else
                solution="$solution"$'\n'"$line"
            fi
            line_count=$((line_count + 1))
        fi
    done

    if [ -z "$solution" ]; then
        echo "❌ 解决方案不能为空"
        collect_solution
        return
    fi

    echo "$solution"
}

# Collect tags
collect_tags() {
    print_header "7️⃣  标签 (Tags)"
    echo ""
    echo "输入相关标签，用逗号分隔 (可选):"
    echo "示例: pod, facebook, static-linking, xcframework"
    echo ""
    printf "标签 (按 Enter 跳过): "
    read -r tags_input

    # Default tags based on domain
    local domain="$1"
    local default_tags="fix, $domain"

    if [ -z "$tags_input" ]; then
        echo "$default_tags"
    else
        # Combine with default tags
        echo "$default_tags, $tags_input"
    fi
}

# Check for duplicate or similar contexts
check_duplicates() {
    local domain="$1"
    local title="$2"

    echo ""
    print_info "搜索相似的现有上下文..."

    # Extract key words from title (简单实现：取前3个有意义的词)
    local keywords
    keywords=$(echo "$title" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z0-9一-龥]{3,}' | head -5)

    if [ -z "$keywords" ]; then
        print_info "未找到相似条目"
        return 0
    fi

    # Search for similar titles in the domain
    local similar_contexts=""
    local domain_dir="$CONTEXT_DIR/$domain"

    if [ -d "$domain_dir" ]; then
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                local existing_title
                existing_title=$(grep "^title:" "$file" | sed 's/title: *//')

                # Check if any keyword matches (case insensitive)
                local existing_lower
                existing_lower=$(echo "$existing_title" | tr '[:upper:]' '[:lower:]')

                # shellcheck disable=SC2086 -- intentional word-splitting: keywords is a space-delimited name list
                for keyword in $keywords; do
                    if echo "$existing_lower" | grep -q "$keyword"; then
                        similar_contexts="$similar_contexts\n  - $existing_title ($(basename "$file" .md))"
                        break
                    fi
                done
            fi
        done < <(find "$domain_dir" -name "ctx-*.md" -print0 2>/dev/null)
    fi

    if [ -n "$similar_contexts" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  找到可能相似的上下文:${RESET}"
        echo -e "$similar_contexts"
        echo ""
        print_info "建议检查这些条目，避免重复内容"
        echo ""
        printf "仍要继续创建新条目吗？[y/n]: "
        read -r response

        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo "❌ 取消创建"
            exit 0
        fi
    else
        print_success "未找到重复条目"
    fi

    return 0
}

# Main entry point
main() {
    # Validate prerequisites
    if ! validate_prerequisites; then
        exit 1
    fi

    print_header "📝 添加新的上下文条目"
    echo ""
    echo "这个工具将引导您创建一条新的上下文记录。"
    echo "请准备好以下信息：问题描述、根因分析、解决方案。"
    echo ""
    printf "准备好了吗？按 Enter 继续，或 Ctrl+C 取消..."
    read -r

    # Collect all information
    local domain layer title problem root_cause solution tags

    domain=$(collect_domain)
    layer=$(collect_layer)
    title=$(collect_title)
    problem=$(collect_problem)
    root_cause=$(collect_root_cause)
    solution=$(collect_solution)
    tags=$(collect_tags "$domain")

    # T028: Check for duplicates
    print_header "🔍 检查重复条目"
    check_duplicates "$domain" "$title"

    # Summary
    print_header "📋 确认信息"
    echo ""
    echo "Domain: $domain"
    echo "Layer: $layer"
    echo "Title: $title"
    echo "Tags: $tags"
    echo ""
    printf "信息正确吗？[y/n]: "
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "❌ 取消创建"
        exit 0
    fi

    print_success "开始创建上下文..."
    echo ""

    # T026: Generate context ID and validate
    print_info "生成上下文 ID..."
    local context_id
    if ! context_id=$(generate_context_id "$domain"); then
        echo "ERROR: Failed to generate context ID" >&2
        exit 1
    fi

    # Validate layer (from common.sh)
    if ! validate_layer "$layer"; then
        echo "ERROR: Invalid layer: $layer" >&2
        exit 1
    fi

    print_success "Context ID: $context_id"

    # T027: Create context file
    print_info "创建上下文文件..."
    if ! create_context_file "$context_id" "$domain" "$layer" "$title" "$problem" "$root_cause" "$solution" "$tags"; then
        echo "ERROR: Failed to create context file" >&2
        exit 1
    fi

    # T029: Update index
    print_info "更新索引..."
    update_index

    print_header "✨ 完成！"
    echo ""
    print_success "上下文已成功创建: $context_id"
    echo ""
    echo "文件位置: $CONTEXT_DIR/$domain/$layer/$context_id.md"
    echo ""
}

# Create context file from collected information
# Args: context_id, domain, layer, title, problem, root_cause, solution, tags
create_context_file() {
    local context_id="$1"
    local domain="$2"
    local layer="$3"
    local title="$4"
    local problem="$5"
    local root_cause="$6"
    local solution="$7"
    local tags="$8"

    # Validate inputs
    if [ -z "$context_id" ] || [ -z "$domain" ] || [ -z "$layer" ] || [ -z "$title" ]; then
        echo "ERROR: Missing required arguments for create_context_file" >&2
        return 1
    fi

    # Get current date
    local created_date
    created_date=$(get_current_date)

    # Create context file path (layered: domain/layer/id.md)
    local context_dir_path="$CONTEXT_DIR/$domain/$layer"
    mkdir -p "$context_dir_path"
    local context_file="$context_dir_path/$context_id.md"

    # Check if file already exists
    if [ -f "$context_file" ]; then
        echo "ERROR: Context file already exists: $context_file" >&2
        return 1
    fi

    # Create context file
    cat > "$context_file" <<EOF
---
id: $context_id
title: $title
layer: $layer
domain: $domain
tags: [$tags]
created: $created_date
source: manual
status: active
confidence: high
---

# $title

## 问题描述

$problem

## 根因分析

$root_cause

## 解决方案

$solution

## 适用场景

描述什么情况下这个上下文是相关的，包括关键词和条件。

## 相关资源

- 相关文件: (待补充)
- 相关文档: (待补充)
EOF

    # Verify file was created
    if [ ! -f "$context_file" ]; then
        echo "ERROR: Failed to create context file: $context_file" >&2
        return 1
    fi

    print_success "文件已创建: $context_file"
    return 0
}

main "$@"
