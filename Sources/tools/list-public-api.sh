#!/bin/bash
# list-public-api.sh
# Lists all public/open declarations in a module.
# Usage: ./Sources/tools/list-public-api.sh <ModulePath>
#
# Example: ./Sources/tools/list-public-api.sh Sources/Core/MSPCore
#
# Per Sources/constitution.md, public APIs must be documented and stable.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <ModulePath>" >&2
    echo "Example: $0 Sources/Core/MSPCore" >&2
    exit 1
fi

MODULE_PATH="$1"

if [[ ! -d "$MODULE_PATH" ]]; then
    echo "Error: Module path not found: $MODULE_PATH" >&2
    exit 1
fi

echo "=== Public API in $MODULE_PATH ==="
echo ""

echo "--- Types (class/struct/protocol/enum) ---"
grep -rn \
    -E "^[[:space:]]*(public|open)[[:space:]]+(final[[:space:]]+)?(class|struct|protocol|enum|actor)[[:space:]]+" \
    "$MODULE_PATH" \
    --include="*.swift" \
    2>/dev/null | sed 's/^/  /' || echo "  (none)"

echo ""
echo "--- Functions ---"
grep -rn \
    -E "^[[:space:]]*(public|open)[[:space:]]+(static[[:space:]]+)?func[[:space:]]+" \
    "$MODULE_PATH" \
    --include="*.swift" \
    2>/dev/null | sed 's/^/  /' || echo "  (none)"

echo ""
echo "--- Properties ---"
grep -rn \
    -E "^[[:space:]]*(public|open)[[:space:]]+(static[[:space:]]+)?(var|let)[[:space:]]+" \
    "$MODULE_PATH" \
    --include="*.swift" \
    2>/dev/null | sed 's/^/  /' || echo "  (none)"
