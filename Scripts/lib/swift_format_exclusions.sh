#!/usr/bin/env bash

# Swift Format Exclusions Library
# Provides functions to read and apply exclusion rules from swift-format-exclusions.txt

get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "$script_dir/../.." && pwd)"
}

get_exclusions_config_file() {
    local project_root="${1:-$(get_project_root)}"
    echo "$project_root/swift-format-exclusions.txt"
}

# Read exclusion patterns from config file
# Returns: name patterns and path patterns as separate arrays (via global variables)
# Usage: read_exclusion_patterns [config_file]
# Sets global arrays: NAME_PATTERNS and PATH_PATTERNS
read_exclusion_patterns() {
    local config_file="${1:-$(get_exclusions_config_file)}"
    
    # Global variables, not local — intentional so callers can read the results
    NAME_PATTERNS=()
    PATH_PATTERNS=()

    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

        if [ -z "$line" ]; then
            continue
        fi

        if [[ "$line" =~ ^name:(.+)$ ]]; then
            NAME_PATTERNS+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^path:(.+)$ ]]; then
            PATH_PATTERNS+=("${BASH_REMATCH[1]}")
        fi
    done < "$config_file"
    
    return 0
}

# Generate find command exclusion arguments
# Usage: get_swift_format_find_exclusions [config_file]
# Output: Space-separated list of -not arguments for find command
get_swift_format_find_exclusions() {
    local config_file="${1:-$(get_exclusions_config_file)}"
    local name_patterns=()
    local path_patterns=()
    local exclusions=""
    
    if ! read_exclusion_patterns "$config_file"; then
        echo "-not -name \"*.pb.swift\" -not -path \"./Pods/*\" -not -path \"*/Pods/*\" -not -path \"./build/*\" -not -path \"*/build/*\" -not -path \"./DerivedData/*\" -not -path \"*/DerivedData/*\" -not -path \"./.build/*\" -not -path \"*/.build/*\" -not -path \"./output*/*\" -not -path \"*/output*/*\" -not -path \"*/xcframework/*\" -not -path \"./.git/*\" -not -path \"*/Pods.xcodeproj/*\" -not -path \"*/xcuserdata/*\" -not -path \"*/xcshareddata/*\""
        return 0
    fi

    for pattern in "${NAME_PATTERNS[@]}"; do
        exclusions="$exclusions -not -name \"$pattern\""
    done
    
    for pattern in "${PATH_PATTERNS[@]}"; do
        # Handle both ./path and */path patterns
        if [[ "$pattern" == ./* ]]; then
            exclusions="$exclusions -not -path \"$pattern\""
        else
            # Add both ./pattern and */pattern for flexibility
            local base_pattern="${pattern#*/}"  # Remove leading */
            exclusions="$exclusions -not -path \"./$base_pattern\" -not -path \"$pattern\""
        fi
    done
    
    echo "$exclusions"
}

# Check if a file should be excluded
# Usage: should_exclude_swift_file <file_path> [config_file]
# Returns: 0 if file should be excluded, 1 otherwise
should_exclude_swift_file() {
    local file_path="$1"
    local config_file="${2:-$(get_exclusions_config_file)}"
    
    if [ -z "$file_path" ]; then
        return 1
    fi
    
    if ! read_exclusion_patterns "$config_file"; then
        if [[ "$file_path" == *.pb.swift ]]; then
            return 0
        fi
        if [[ "$file_path" == *"/Pods/"* ]] || \
           [[ "$file_path" == *"/build/"* ]] || \
           [[ "$file_path" == *"/DerivedData/"* ]] || \
           [[ "$file_path" == *"/.build/"* ]] || \
           [[ "$file_path" == *"/output"* ]] || \
           [[ "$file_path" == *"/xcframework/"* ]] || \
           [[ "$file_path" == *"/.swiftpm/"* ]] || \
           [[ "$file_path" == *"/Package.resolved"* ]] || \
           [[ "$file_path" == *"/.git/"* ]] || \
           [[ "$file_path" == *"/xcuserdata/"* ]] || \
           [[ "$file_path" == *"/xcshareddata/"* ]] || \
           [[ "$file_path" == *"/Pods.xcodeproj/"* ]]; then
            return 0
        fi
        return 1
    fi
    
    local filename=$(basename "$file_path")
    for pattern in "${NAME_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done
    
    for pattern in "${PATH_PATTERNS[@]}"; do
        local match_pattern="$pattern"

        # Strip leading */ or ./ and trailing /* to get the bare segment to match against
        match_pattern="${match_pattern#*/}"
        match_pattern="${match_pattern%/*}"
        
        # For directory matching, we need to check if the path contains the directory
        # For example: */Pods/* should match any path containing /Pods/
        if [[ "$match_pattern" == *"/"* ]]; then
            # Pattern contains slashes (e.g., "Pods/SomeSubdir")
            # Match if file path contains this pattern
            if [[ "$file_path" == *"$match_pattern"* ]]; then
                return 0
            fi
        else
            # Single directory name (e.g., "Pods", ".build", "outputMSPiOSCore")
            # Match if path contains /DirectoryName/ or starts with DirectoryName/
            # Also handle special cases like .build (hidden directory) and output* (prefix match)
            if [[ "$match_pattern" == .* ]]; then
                # Hidden directory like .build
                # Match: .build/, ./.build/, /.build/, or any path containing /.build/
                if [[ "$file_path" == "$match_pattern/"* ]] || \
                   [[ "$file_path" == "./$match_pattern/"* ]] || \
                   [[ "$file_path" == *"/$match_pattern/"* ]] || \
                   [[ "$file_path" == "/$match_pattern/"* ]]; then
                    return 0
                fi
            elif [[ "$match_pattern" == output* ]]; then
                # Pattern like output* - match any path starting with output
                # For "output*", we want to match "outputMSPiOSCore/", "outputNova/", etc.
                # Use glob pattern matching
                if [[ "$file_path" == output* ]] || \
                   [[ "$file_path" == *"/output"* ]] || \
                   [[ "$file_path" == "./output"* ]]; then
                    return 0
                fi
            else
                # Regular directory - match with slashes
                # Check for /DirectoryName/ or DirectoryName/ at start
                # For "Pods", we want to match "Pods/", "/Pods/", "./Pods/"
                if [[ "$file_path" == *"/$match_pattern/"* ]] || \
                   [[ "$file_path" == "$match_pattern/"* ]] || \
                   [[ "$file_path" == "./$match_pattern/"* ]] || \
                   [[ "$file_path" == *"/$match_pattern" ]] || \
                   [[ "$file_path" == "$match_pattern" ]]; then
                    return 0
                fi
            fi
        fi
    done
    
    return 1
}

