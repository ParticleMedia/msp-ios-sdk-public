#!/bin/bash

# Fix Unicode encoding issues for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

rm -rf "$PWD/outputNova/xcframework"
# Create directories for output
mkdir -p "$PWD/outputNova/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
# Try pod install with retry logic and GitHub source backup
if ! pod install --repo-update; then
    echo -e "${YELLOW}⚠️  Primary pod install failed, trying with GitHub source backup...${NC}"
    
    # Create temporary Podfile with GitHub source
    cp Podfile Podfile.backup
    cat > Podfile.temp << 'EOF'
# Fallback Podfile with GitHub source
source 'https://github.com/CocoaPods/Specs.git'
source 'https://cdn.cocoapods.org/'

EOF
    # Append original Podfile content (excluding source lines)
    grep -v "^source " Podfile.backup >> Podfile.temp
    
    if pod install --podfile=Podfile.temp --no-repo-update; then
        echo -e "${GREEN}✅ Pod install succeeded with GitHub source backup${NC}"
        mv Podfile.temp Podfile
    else
        echo -e "${RED}❌ Pod install failed even with GitHub source backup${NC}"
        mv Podfile.backup Podfile
        rm -f Podfile.temp
        exit 1
    fi
fi

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

SWIFT_VERSION=5.0
# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "NovaCore" \
    -destination="iOS" \
    -archivePath "$PWD/outputNova/xcframework/NovaCore-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "NovaCore" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/outputNova/xcframework/NovaCore-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/outputNova/xcframework/NovaCore-iOS.xcarchive/Products/Library/Frameworks/NovaCore.framework" \
    -framework "$PWD/outputNova/xcframework/NovaCore-Simulator.xcarchive/Products/Library/Frameworks/NovaCore.framework" \
    -output "$PWD/outputNova/xcframework/NovaCore.xcframework"

# Define source and destination paths
SOURCE_XCFRAMEWORK="$PWD/outputNova/xcframework/NovaCore.xcframework"
DESTINATION_DIR="$PWD/NovaAdapter"

# Remove the previous xcframework if it exists
rm -rf "$DESTINATION_DIR/NovaCore.xcframework"

# Copy the new xcframework
cp -R "$SOURCE_XCFRAMEWORK" "$DESTINATION_DIR/"

# Success message
echo -e "\n${GREEN}✅ NovaCore.xcframework has been replaced in NovaAdapter.${NC}\n"
