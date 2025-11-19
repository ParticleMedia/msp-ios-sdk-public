#!/usr/bin/env bash
# Wrapper script for building FBAudienceNetwork.xcframework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

"$SCRIPT_DIR/../builder.sh" \
  --scheme FBAudienceNetwork \
  --output FBAudienceNetworkWrapper \
  --sdk-name FBAudienceNetwork
