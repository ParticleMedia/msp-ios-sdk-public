
#!/bin/bash

# Source colors for output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

# Default to skip code signing (1 = skip, 0 = use code signing)
SKIP_CODE_SIGN=${SKIP_CODE_SIGN:-1}

# Show usage if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
    echo -e "${CYAN}MSP iOS SDK Legacy Build Script${NC}"
    echo -e "${CYAN}================================${NC}"
    echo -e ""
    echo -e "${GREEN}Usage:${NC}"
    echo -e "  ./Scripts/legacy/makeBuild.sh [OPTIONS]"
    echo -e ""
    echo -e "${GREEN}Options:${NC}"
    echo -e "  SKIP_CODE_SIGN=0    Enable code signing (requires certificates)"
    echo -e "  SKIP_CODE_SIGN=1    Skip code signing (default, no certificates needed)"
    echo -e ""
    echo -e "${GREEN}Examples:${NC}"
    echo -e "  ./Scripts/legacy/makeBuild.sh                    # Build without code signing (default)"
    echo -e "  SKIP_CODE_SIGN=0 ./Scripts/legacy/makeBuild.sh   # Build with code signing"
    echo -e "  SKIP_CODE_SIGN=1 ./Scripts/legacy/makeBuild.sh   # Build without code signing"
    echo -e ""
    echo -e "${GREEN}Note:${NC} Code signing requires valid iOS Development certificates"
    echo -e ""
    exit 0
fi

echo -e "${GREEN}🚀 Starting MSP iOS SDK Legacy Build Process${NC}"
echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}Code signing: ${SKIP_CODE_SIGN == 1 ? "SKIPPED" : "ENABLED"}${NC}"
echo -e ""

# build MSPiOSCore.xcframework and add it to dependency
echo -e "${BLUE}🔧 Building MSPiOSCore.xcframework...${NC}"
SKIP_CODE_SIGN="$SKIP_CODE_SIGN" "$SCRIPT_DIR/buildiOSCoreXCFramework.sh"

# build NovaCore.xcframework and add it to dependency
echo -e "${BLUE}🔧 Building NovaCore.xcframework...${NC}"
SKIP_CODE_SIGN="$SKIP_CODE_SIGN" "$SCRIPT_DIR/buildNovaXCFramework.sh"

echo -e "${GREEN}✅ Legacy build process completed successfully!${NC}"
