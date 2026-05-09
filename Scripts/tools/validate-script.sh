#!/usr/bin/env bash
# validate-script.sh
# Validates a shell script using shellcheck.
# Usage: ./Scripts/tools/validate-script.sh <script-path>
#
# Per Scripts/constitution.md, all shell scripts must pass shellcheck.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <script-path>" >&2
    exit 1
fi

SCRIPT_PATH="$1"

if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: Script not found: $SCRIPT_PATH" >&2
    exit 1
fi

if ! command -v shellcheck &> /dev/null; then
    echo "Error: shellcheck not installed. Install with: brew install shellcheck" >&2
    exit 1
fi

echo "Validating: $SCRIPT_PATH"

# Bash parser check first — catches syntax issues that shellcheck's parser
# tolerates (e.g., apostrophe inside heredoc-in-command-substitution that
# bash itself can't parse).
if ! bash -n "$SCRIPT_PATH"; then
    echo "Error: bash parse failed (script will not run)." >&2
    exit 1
fi

# Static analysis (style + common pitfalls).
shellcheck -x "$SCRIPT_PATH"

echo "Validation passed."
