#!/bin/bash

# Demo App Build Script for Local Development
# This script now uses the shared demo app builder library

set -e
set -o pipefail

# Source the shared demo app builder library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/demo_app_builder.sh"

# Build the demo app using the shared library
build_demo_app
