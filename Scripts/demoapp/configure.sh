#!/bin/bash
# DemoApp configuration script
set -e

MODE="${1:---mode=pods-dev}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Configuring DemoApp"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode: $MODE"

# Parse mode
if [[ "$MODE" == "--mode=pods-dev" ]]; then
    echo "Using pods-dev mode (all source pods)"
    # Podfile should use source pods
elif [[ "$MODE" == "--mode=pods-release" ]]; then
    echo "Using pods-release mode (binary core + source adapters)"
    # Podfile should use binary XCFrameworks for core, source for adapters
else
    echo "❌ Unknown mode: $MODE"
    echo "Usage: $0 --mode=pods-dev|--mode=pods-release"
    exit 1
fi

# Check if Podfile exists
if [ ! -f "Podfile" ]; then
    echo "❌ Podfile not found in DemoApp directory"
    exit 1
fi

echo "✅ DemoApp configured for $MODE"

