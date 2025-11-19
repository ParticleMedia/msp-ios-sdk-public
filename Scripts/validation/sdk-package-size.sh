#!/usr/bin/env bash
#
# SDK Package Size Comparison Tool
#
# Computes and compares output archive sizes for CocoaPods and SwiftPM builds.
# Detects size regressions and produces machine-readable reports.
#
# Exit codes:
#   0 - All checks passed, no regressions
#   1 - Size regression detected (>25% increase)
#   2 - Build failure or missing artifacts
#

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=Scripts/lib/paths.sh
source "$ROOT_DIR/Scripts/lib/paths.sh"
# shellcheck source=Scripts/lib/colors.sh
source "$ROOT_DIR/Scripts/lib/colors.sh"

# Initialize paths
init_paths

# Additional colors
BLUE='\033[0;34m'

# Configuration
THRESHOLD_MB=30  # Warn if any xcframework > 30MB
REGRESSION_THRESHOLD_PCT=25  # Fail if size increases > 25%
OUTPUT_DIR="$SCRIPT_DIR/output"
JSON_REPORT="$OUTPUT_DIR/sdk-size.json"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$OUTPUT_DIR"

echo "📦 SDK Package Size Comparison Tool"
echo "===================================="
echo ""

# Function to get framework size in MB
get_framework_size() {
    local framework_path="$1"
    if [ -d "$framework_path" ]; then
        du -sm "$framework_path" | cut -f1
    else
        echo "0"
    fi
}

# Function to find all xcframeworks
find_xcframeworks() {
    local search_dir="$1"
    find "$search_dir" -name "*.xcframework" -type d 2>/dev/null || true
}

# Function to build CocoaPods archive
build_cocoapods_archive() {
    echo -e "${BLUE}🔨 Building CocoaPods archive...${NC}"
    
    local build_dir="$TEMP_DIR/cocoapods"
    mkdir -p "$build_dir"
    
    # Build for iOS Simulator
    xcodebuild -workspace "$ROOT_DIR/msp-ios-sdk.xcworkspace" \
        -scheme MSPDemoApp \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -configuration Release \
        -derivedDataPath "$build_dir/DerivedData" \
        clean build \
        > "$build_dir/build.log" 2>&1 || {
        echo -e "${RED}❌ CocoaPods build failed${NC}"
        cat "$build_dir/build.log" | tail -20
        return 1
    }
    
    # Find built frameworks
    local frameworks_dir="$build_dir/DerivedData/Build/Products/Release-iphonesimulator"
    if [ -d "$frameworks_dir" ]; then
        echo "$frameworks_dir"
    else
        echo ""
    fi
}

# Function to build SwiftPM archive
build_spm_archive() {
    echo -e "${BLUE}🔨 Building SwiftPM archive...${NC}"
    
    local build_dir="$TEMP_DIR/spm"
    mkdir -p "$build_dir"
    
    # Build for iOS Simulator
    xcodebuild -workspace "$ROOT_DIR/msp-ios-sdk.xcworkspace" \
        -scheme MSPDemoApp-SPM \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -configuration Release \
        -derivedDataPath "$build_dir/DerivedData" \
        clean build \
        > "$build_dir/build.log" 2>&1 || {
        echo -e "${RED}❌ SwiftPM build failed${NC}"
        cat "$build_dir/build.log" | tail -20
        return 1
    }
    
    # Find built frameworks
    local frameworks_dir="$build_dir/DerivedData/Build/Products/Release-iphonesimulator"
    if [ -d "$frameworks_dir" ]; then
        echo "$frameworks_dir"
    else
        echo ""
    fi
}

# Function to analyze wrapper xcframeworks
analyze_wrapper_frameworks() {
    local wrapper_dir="$ROOT_DIR"
    local frameworks=()
    
    # Find all wrapper directories
    for wrapper in ShimmerWrapper FBAudienceNetworkWrapper IronSourceSDKWrapper \
                   OpenWrapSDKWrapper MintegralAdSDKWrapper MobileFuseSDKWrapper \
                   InMobiSDKWrapper; do
        # Use safe glob expansion to avoid errors when no files match
        for xcframework in "$wrapper_dir/$wrapper/Frameworks"/*.xcframework; do
            # Check if glob matched actual files (not literal *)
            if [ -d "$xcframework" ] && [ "$xcframework" != "$wrapper_dir/$wrapper/Frameworks/*.xcframework" ]; then
                frameworks+=("$xcframework")
            fi
        done
    done
    
    # Safe expansion: return empty string if array is empty
    if [ ${#frameworks[@]} -eq 0 ]; then
        echo ""
    else
        echo "${frameworks[@]}"
    fi
}

# Function to format size
format_size() {
    local size_mb="$1"
    if [ "$size_mb" -ge 1024 ]; then
        printf "%.2f GB" "$(echo "scale=2; $size_mb / 1024" | bc)"
    else
        printf "%d MB" "$size_mb"
    fi
}

# Main analysis
echo "Analyzing SDK package sizes..."
echo ""

# Analyze wrapper xcframeworks
echo -e "${BLUE}📊 Analyzing wrapper xcframeworks...${NC}"
WRAPPER_FRAMEWORKS_RESULT=$(analyze_wrapper_frameworks)
WRAPPER_TOTAL_SIZE=0
LARGE_FRAMEWORKS=()

# Safely handle empty result
if [ -z "$WRAPPER_FRAMEWORKS_RESULT" ]; then
    echo -e "  ${YELLOW}⚠️  No wrapper xcframeworks found${NC}"
else
    # Convert space-separated string to array safely
    set +u  # Temporarily disable unbound variable check for array expansion
    WRAPPER_FRAMEWORKS=($WRAPPER_FRAMEWORKS_RESULT)
    set -u  # Re-enable unbound variable check
    
    for framework in "${WRAPPER_FRAMEWORKS[@]}"; do
        if [ -d "$framework" ]; then
            size_mb=$(get_framework_size "$framework")
            framework_name=$(basename "$framework" .xcframework)
            WRAPPER_TOTAL_SIZE=$((WRAPPER_TOTAL_SIZE + size_mb))
            
            if [ "$size_mb" -gt "$THRESHOLD_MB" ]; then
                LARGE_FRAMEWORKS+=("$framework_name:$size_mb")
                echo -e "  ${YELLOW}⚠️  $framework_name: $(format_size $size_mb)${NC}"
            else
                echo -e "  ${GREEN}✓  $framework_name: $(format_size $size_mb)${NC}"
            fi
        fi
    done
fi

echo ""
echo -e "${BLUE}Total wrapper frameworks size: $(format_size $WRAPPER_TOTAL_SIZE)${NC}"
echo ""

# Build and analyze CocoaPods archive
COCOAPODS_DIR=$(build_cocoapods_archive)
COCOAPODS_SIZE=0

if [ -n "$COCOAPODS_DIR" ] && [ -d "$COCOAPODS_DIR" ]; then
    COCOAPODS_SIZE=$(du -sm "$COCOAPODS_DIR" | cut -f1)
    echo -e "${GREEN}✓ CocoaPods build size: $(format_size $COCOAPODS_SIZE)${NC}"
else
    echo -e "${RED}❌ CocoaPods build artifacts not found${NC}"
    exit 2
fi

echo ""

# Build and analyze SwiftPM archive
SPM_DIR=$(build_spm_archive)
SPM_SIZE=0

if [ -n "$SPM_DIR" ] && [ -d "$SPM_DIR" ]; then
    SPM_SIZE=$(du -sm "$SPM_DIR" | cut -f1)
    echo -e "${GREEN}✓ SwiftPM build size: $(format_size $SPM_SIZE)${NC}"
else
    echo -e "${RED}❌ SwiftPM build artifacts not found${NC}"
    exit 2
fi

echo ""

# Calculate delta
if [ "$COCOAPODS_SIZE" -gt 0 ]; then
    DELTA=$((SPM_SIZE - COCOAPODS_SIZE))
    DELTA_PCT=$(echo "scale=2; ($DELTA * 100) / $COCOAPODS_SIZE" | bc)
    
    echo "=============================="
    echo "📊 Size Comparison"
    echo "=============================="
    echo ""
    echo "CocoaPods:  $(format_size $COCOAPODS_SIZE)"
    echo "SwiftPM:    $(format_size $SPM_SIZE)"
    echo "Delta:      $(format_size $DELTA) ($DELTA_PCT%)"
    echo ""
    
    # Check for regression
    if (( $(echo "$DELTA_PCT > $REGRESSION_THRESHOLD_PCT" | bc -l) )); then
        echo -e "${RED}❌ Size regression detected: SwiftPM is $DELTA_PCT% larger than CocoaPods${NC}"
        echo -e "${RED}   Threshold: $REGRESSION_THRESHOLD_PCT%${NC}"
        REGRESSION=1
    else
        echo -e "${GREEN}✅ No size regression detected${NC}"
        REGRESSION=0
    fi
else
    DELTA=0
    DELTA_PCT=0
    REGRESSION=0
fi

# Generate JSON report
{
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"cocoapods\": {"
    echo "    \"size_mb\": $COCOAPODS_SIZE,"
    echo "    \"size_formatted\": \"$(format_size $COCOAPODS_SIZE)\""
    echo "  },"
    echo "  \"swiftpm\": {"
    echo "    \"size_mb\": $SPM_SIZE,"
    echo "    \"size_formatted\": \"$(format_size $SPM_SIZE)\""
    echo "  },"
    echo "  \"delta\": {"
    echo "    \"size_mb\": $DELTA,"
    echo "    \"size_formatted\": \"$(format_size $DELTA)\","
    echo "    \"percentage\": $DELTA_PCT"
    echo "  },"
    echo "  \"wrapper_frameworks\": {"
    echo "    \"total_size_mb\": $WRAPPER_TOTAL_SIZE,"
    echo "    \"total_size_formatted\": \"$(format_size $WRAPPER_TOTAL_SIZE)\","
    echo "    \"large_frameworks\": ["
    if [ ${#LARGE_FRAMEWORKS[@]} -gt 0 ]; then
        set +u  # Temporarily disable for array access
        for i in "${!LARGE_FRAMEWORKS[@]}"; do
            IFS=':' read -r name size <<< "${LARGE_FRAMEWORKS[$i]}"
            echo "      {"
            echo "        \"name\": \"$name\","
            echo "        \"size_mb\": $size,"
            echo "        \"size_formatted\": \"$(format_size $size)\""
            if [ $i -lt $((${#LARGE_FRAMEWORKS[@]} - 1)) ]; then
                echo "      },"
            else
                echo "      }"
            fi
        done
        set -u  # Re-enable
    fi
    echo "    ]"
    echo "  },"
    echo "  \"regression_detected\": $REGRESSION,"
    echo "  \"regression_threshold_pct\": $REGRESSION_THRESHOLD_PCT"
    echo "}"
} > "$JSON_REPORT"

echo ""
echo "📄 JSON report saved to: $JSON_REPORT"
echo ""

if [ "$REGRESSION" -eq 1 ]; then
    exit 1
else
    exit 0
fi

