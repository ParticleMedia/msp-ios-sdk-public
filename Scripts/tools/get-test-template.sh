#!/bin/bash
# get-test-template.sh
# Prints the Quick/Nimble unit test template content.
# Usage: ./Scripts/tools/get-test-template.sh
#
# This is the single source of truth for test boilerplate.
# All agents should use this script to retrieve the template.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_PATH="$PROJECT_ROOT/Tests/templates/unit_test_spec.swift.template"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
    echo "Error: Template not found at $TEMPLATE_PATH" >&2
    exit 1
fi

cat "$TEMPLATE_PATH"
