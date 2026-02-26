#!/usr/bin/env bash
# Post-process protoc-generated .pb.swift files for MSPCore XCFramework compatibility.
# Ensures SwiftProtobuf is hidden from the public module interface via @_implementationOnly.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PB_DIR="$ROOT_DIR/Sources/Core/MSPCore/MSPCore/MESRawFiles"

# --- Validation ---

if [ ! -d "$PB_DIR" ]; then
    echo "ERROR: MESRawFiles directory not found: $PB_DIR" >&2
    exit 1
fi

# --- Main ---

fixed=0
already_ok=0
total=0

for file in "$PB_DIR"/*.pb.swift; do
    [ -f "$file" ] || continue
    total=$((total + 1))

    if grep -q '^@_implementationOnly import SwiftProtobuf' "$file"; then
        already_ok=$((already_ok + 1))
        continue
    fi

    if grep -q '^import SwiftProtobuf' "$file"; then
        # Atomic write: temp file + mv (HR-3, HR-12)
        tmp="$(mktemp)"
        sed 's/^import SwiftProtobuf$/@_implementationOnly import SwiftProtobuf/' "$file" > "$tmp"
        mv "$tmp" "$file"
        fixed=$((fixed + 1))
        echo "FIXED: $(basename "$file")"
    fi
done

echo ""
echo "Scanned $total .pb.swift files: $fixed fixed, $already_ok already correct."

if [ "$fixed" -gt 0 ]; then
    echo "⚠️  Remember to rebuild MSPCore.xcframework and verify .swiftinterface."
fi
