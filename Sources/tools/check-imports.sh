#!/bin/bash
# check-imports.sh
# Checks for forbidden imports in Core modules per constitution.md Article III.
# Usage: ./Sources/tools/check-imports.sh [ModulePath]
#
# If no path provided, checks Sources/Core/
#
# Article III.1: Core modules must not import third-party SDK headers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODULE_PATH="${1:-$PROJECT_ROOT/Sources/Core}"

if [[ ! -d "$MODULE_PATH" ]]; then
    echo "Error: Path not found: $MODULE_PATH" >&2
    exit 1
fi

# Known third-party SDKs that should not be imported in Core
# Per Article III.1: Core modules must not import third-party SDK headers
# Note: NovaCore is part of this SDK, not a third-party SDK
FORBIDDEN_IMPORTS=(
    "MolocoSDK"
    "VungleAdsSDK"
    "GoogleMobileAds"
    "FBAudienceNetwork"
    "AppLovinSDK"
    "UnityAds"
    "IronSource"
    "AmazonPublisherServicesSDK"
    "InMobiSDK"
    "MintegralAdSDK"
    "MobileFuseSDK"
)

echo "=== Import Check: $MODULE_PATH ==="
echo "Checking for forbidden third-party imports..."
echo ""

VIOLATIONS_FOUND=0

for sdk in "${FORBIDDEN_IMPORTS[@]}"; do
    MATCHES=$(grep -rn "^import ${sdk}" "$MODULE_PATH" --include="*.swift" 2>/dev/null || true)
    if [[ -n "$MATCHES" ]]; then
        echo "[VIOLATION] Found import of '$sdk':"
        echo "$MATCHES" | sed 's/^/  /'
        echo ""
        VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
    fi
done

if [[ $VIOLATIONS_FOUND -eq 0 ]]; then
    echo "No forbidden imports found."
    exit 0
else
    echo "=== $VIOLATIONS_FOUND violation(s) found ==="
    echo "Per Article III.1: Core modules must not import third-party SDK headers."
    exit 1
fi
