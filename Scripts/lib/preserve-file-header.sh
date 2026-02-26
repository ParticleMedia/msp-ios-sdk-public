#!/usr/bin/env bash

# Script to preserve file header comments when formatting Swift files
# This script moves import statements back after file header comments
# Handles cases where swift-format moves imports before file headers

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <swift-file>"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    exit 0
fi

# Create temporary files for each section
TEMP_HEADER=$(mktemp)
TEMP_IMPORTS=$(mktemp)
TEMP_REST=$(mktemp)
TEMP_FILE=$(mktemp)

cleanup() {
    rm -f "$TEMP_HEADER" "$TEMP_IMPORTS" "$TEMP_REST" "$TEMP_FILE"
}
trap cleanup EXIT

FIRST_LINE=true
IN_HEADER=false
IN_IMPORTS=false
HEADER_FOUND=false

while IFS= read -r line || [ -n "$line" ]; do
    if [ "$FIRST_LINE" = true ]; then
        FIRST_LINE=false
        if [[ "$line" =~ ^[[:space:]]*import ]]; then
            IN_IMPORTS=true
            echo "$line" >> "$TEMP_IMPORTS"
        elif [[ "$line" =~ ^[[:space:]]*// ]] || [[ -z "${line// }" ]]; then
            IN_HEADER=true
            HEADER_FOUND=true
            echo "$line" >> "$TEMP_HEADER"
        else
            echo "$line" >> "$TEMP_REST"
        fi
    elif [ "$IN_IMPORTS" = true ]; then
        if [[ "$line" =~ ^[[:space:]]*import ]]; then
            echo "$line" >> "$TEMP_IMPORTS"
        elif [[ -z "${line// }" ]]; then
            echo "$line" >> "$TEMP_IMPORTS"
        elif [[ "$line" =~ ^[[:space:]]*// ]]; then
            IN_IMPORTS=false
            IN_HEADER=true
            HEADER_FOUND=true
            echo "$line" >> "$TEMP_HEADER"
        else
            IN_IMPORTS=false
            echo "$line" >> "$TEMP_REST"
        fi
    elif [ "$IN_HEADER" = true ]; then
        if [[ "$line" =~ ^[[:space:]]*// ]] || [[ -z "${line// }" ]]; then
            echo "$line" >> "$TEMP_HEADER"
        elif [[ "$line" =~ ^[[:space:]]*import ]]; then
            IN_HEADER=false
            IN_IMPORTS=true
            echo "$line" >> "$TEMP_IMPORTS"
        else
            IN_HEADER=false
            echo "$line" >> "$TEMP_REST"
        fi
    else
        echo "$line" >> "$TEMP_REST"
    fi
done < "$FILE"

# Reconstruct file: header first (if found), then imports, then rest
if [ "$HEADER_FOUND" = true ]; then
    cat "$TEMP_HEADER" "$TEMP_IMPORTS" "$TEMP_REST" > "$TEMP_FILE"
else
    cat "$TEMP_IMPORTS" "$TEMP_REST" > "$TEMP_FILE"
fi

# Only update if file changed
if ! cmp -s "$FILE" "$TEMP_FILE"; then
    cp "$TEMP_FILE" "$FILE"
fi
