#!/bin/bash
# find-class.sh
# Finds the definition of a class, struct, protocol, or enum in Sources/.
# Usage: ./Sources/tools/find-class.sh <TypeName>
#
# Returns: file:line for each match

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <TypeName>" >&2
    exit 1
fi

TYPE_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Searching for: $TYPE_NAME ==="
echo ""

# Search for class, struct, protocol, enum, or actor definitions
echo "--- Type Definitions ---"
grep -rn \
    -E "^[[:space:]]*(public |open |internal |private |fileprivate )?(final )?(class|struct|protocol|enum|actor)[[:space:]]+${TYPE_NAME}[[:space:]:<{]" \
    "$SOURCES_DIR" \
    --include="*.swift" \
    2>/dev/null || echo "  (none)"

# Search for extensions
echo ""
echo "--- Extensions ---"
grep -rn \
    -E "^[[:space:]]*(public |internal |private |fileprivate )?extension[[:space:]]+${TYPE_NAME}[[:space:]:<{]" \
    "$SOURCES_DIR" \
    --include="*.swift" \
    2>/dev/null || echo "  (none)"
