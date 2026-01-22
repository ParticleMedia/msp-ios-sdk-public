#!/bin/bash

# Script to format all Swift files in the project
# This script finds all Swift files (excluding Pods, build directories, etc.) and formats them

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to find swift-format
find_swift_format() {
    # Check system PATH first
    if command -v swift-format &> /dev/null; then
        echo "$(which swift-format)"
        return 0
    fi
    
    # Check Xcode toolchain
    if [ -f "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format" ]; then
        echo "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format"
        return 0
    fi
    
    # Check Command Line Tools
    if [ -f "/Library/Developer/CommandLineTools/usr/bin/swift-format" ]; then
        echo "/Library/Developer/CommandLineTools/usr/bin/swift-format"
        return 0
    fi
    
    # Check if DEVELOPER_DIR is set
    if [ -n "$DEVELOPER_DIR" ] && [ -f "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format" ]; then
        echo "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format"
        return 0
    fi
    
    return 1
}

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../Scripts/tools
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"                  # .../Scripts
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"                # repo root

# Source exclusion patterns library
source "$SCRIPTS_DIR/lib/swift_format_exclusions.sh"


echo -e "${BLUE}🔍 Finding swift-format...${NC}"

# Find swift-format
SWIFT_FORMAT=$(find_swift_format)

if [ -z "$SWIFT_FORMAT" ] || [ ! -f "$SWIFT_FORMAT" ]; then
    echo -e "${RED}❌ swift-format not found${NC}"
    echo -e "${YELLOW}   Please install swift-format or ensure Xcode is properly installed.${NC}"
    echo -e "${YELLOW}   Install from: https://github.com/apple/swift-format${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found swift-format at: $SWIFT_FORMAT${NC}"
"$SWIFT_FORMAT" --version
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Read configuration file path from .swift-format if it exists
SWIFT_FORMAT_CONFIG_FILE="$PROJECT_ROOT/.swift-format"
CONFIG_FILE="$PROJECT_ROOT/swift-format.json"  # Default fallback

if [ -f "$SWIFT_FORMAT_CONFIG_FILE" ]; then
    # Parse .swift-format file to extract --configuration path
    # Format: --configuration swift-format.json
    config_path=$(grep -E "^--configuration" "$SWIFT_FORMAT_CONFIG_FILE" | sed 's/^--configuration[[:space:]]*//' | tr -d '[:space:]')
    
    if [ -n "$config_path" ]; then
        # If path is relative, make it relative to project root
        if [[ "$config_path" != /* ]]; then
            CONFIG_FILE="$PROJECT_ROOT/$config_path"
        else
            CONFIG_FILE="$config_path"
        fi
    fi
fi

# Verify config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}   Checked .swift-format file: $SWIFT_FORMAT_CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Using configuration file: $CONFIG_FILE${NC}"

echo -e "${BLUE}🔍 Finding Swift files...${NC}"

# Get exclusion arguments from config file
EXCLUSIONS=$(get_swift_format_find_exclusions "$PROJECT_ROOT/swift-format-exclusions.txt")

# Find all Swift files (excluding patterns from config file)
swift_files=$(eval "find . -name \"*.swift\" $EXCLUSIONS | sort")

if [ -z "$swift_files" ]; then
    echo -e "${YELLOW}ℹ️  No Swift files found to format${NC}"
    exit 0
fi

# Count files
file_count=$(echo "$swift_files" | wc -l | tr -d ' ')
echo -e "${GREEN}📝 Found $file_count Swift file(s) to format${NC}"
echo ""

# Ask for confirmation if not in CI mode
if [ -z "$CI" ]; then
    echo -e "${YELLOW}⚠️  This will format all Swift files in the project.${NC}"
    echo -e "${YELLOW}   Make sure you have committed or stashed your changes.${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

# Format files
formatted_count=0
error_count=0
error_files=""

echo -e "${BLUE}🔧 Formatting files...${NC}"
echo ""

for file in $swift_files; do
    # Skip if file doesn't exist
    if [ ! -f "$file" ]; then
        continue
    fi
    
    # Check if file needs formatting (lint returns non-zero if formatting is needed)
    lint_output=$("$SWIFT_FORMAT" lint --configuration "$CONFIG_FILE" "$file" 2>&1)
    lint_exit_code=$?
    
    # Format the file regardless (swift-format is idempotent)
    echo -e "${YELLOW}📝 Formatting: $file${NC}"
    if "$SWIFT_FORMAT" -i --configuration "$CONFIG_FILE" "$file" 2>&1; then
        # Preserve file header comments (move imports back after header)
        if [ -f "$SCRIPTS_DIR/lib/preserve-file-header.sh" ]; then
            "$SCRIPTS_DIR/lib/preserve-file-header.sh" "$file" > /dev/null 2>&1 || true
        fi
        
        # Verify the formatted file has no syntax errors
        if command -v swiftc &> /dev/null; then
            if ! swiftc -parse "$file" &> /dev/null; then
                error_count=$((error_count + 1))
                error_files="$error_files $file"
                echo -e "${RED}   ❌ Syntax error after formatting${NC}"
                echo -e "${YELLOW}   ⚠️  File may have been corrupted by formatter. Please check manually.${NC}"
                # Try to restore from git if possible
                if [ -d .git ] && git diff "$file" &> /dev/null; then
                    echo -e "${YELLOW}   💡 You can restore with: git checkout -- $file${NC}"
                fi
                continue
            fi
        fi
        
        # Check if file was actually changed
        if [ -d .git ] && git diff --quiet "$file" 2>/dev/null; then
            # File wasn't changed (in git repo and no diff)
            echo -e "${GREEN}   ✓ Already formatted${NC}"
        elif [ ! -d .git ]; then
            # Not in git repo, can't check diff - assume formatted if lint passed
            if [ $lint_exit_code -eq 0 ] && [ -z "$lint_output" ]; then
                echo -e "${GREEN}   ✓ Already formatted${NC}"
            else
                formatted_count=$((formatted_count + 1))
                echo -e "${GREEN}   ✅ Formatted${NC}"
            fi
        else
            # File was changed
            formatted_count=$((formatted_count + 1))
            echo -e "${GREEN}   ✅ Formatted (changed)${NC}"
        fi
    else
        error_count=$((error_count + 1))
        error_files="$error_files $file"
        echo -e "${RED}   ❌ Error formatting${NC}"
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Calculate statistics
already_formatted=$((file_count - formatted_count - error_count))
changed_files=0

# Count actually changed files if in git repo
if [ -d .git ]; then
    changed_files=$(git diff --name-only --diff-filter=M 2>/dev/null | grep -c '\.swift$' || echo "0")
fi

# Print summary
echo -e "${GREEN}✅ Formatting Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Total files scanned:${NC}     $file_count"
echo -e "${GREEN}   Files formatted:${NC}         $formatted_count"
if [ $already_formatted -gt 0 ]; then
    echo -e "${GREEN}   Already formatted:${NC}       $already_formatted"
fi
if [ $changed_files -gt 0 ] && [ -d .git ]; then
    echo -e "${GREEN}   Files changed:${NC}           $changed_files"
fi

if [ $error_count -gt 0 ]; then
    echo -e "${RED}   Errors:${NC}                   $error_count"
    echo ""
    echo -e "${RED}❌ Files with errors:${NC}"
    for file in $error_files; do
        echo -e "${RED}   - $file${NC}"
    done
    echo ""
    echo -e "${YELLOW}💡 Some files could not be formatted. Please check the errors above.${NC}"
    exit 1
else
    echo -e "${GREEN}   Errors:${NC}                  0"
    echo ""
    
    if [ $changed_files -gt 0 ] && [ -d .git ]; then
        echo -e "${GREEN}📊 Code Statistics:${NC}"
        git_diff_stat=$(git diff --shortstat 2>/dev/null)
        if [ -n "$git_diff_stat" ]; then
            echo -e "${GREEN}   $git_diff_stat${NC}"
        fi
        echo ""
        echo -e "${GREEN}💡 Next steps:${NC}"
        echo -e "${GREEN}   1. Review changes:${NC}     git diff"
        echo -e "${GREEN}   2. Review specific file:${NC} git diff <file>"
        echo -e "${GREEN}   3. Stage all changes:${NC}   git add ."
        echo -e "${GREEN}   4. Commit changes:${NC}      git commit -m \"chore: format Swift files\""
    else
        echo -e "${GREEN}💡 All files are properly formatted!${NC}"
    fi
    exit 0
fi

