#!/bin/bash

# Source colors for output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

# Default to skip code signing (1 = skip, 0 = use code signing)
SKIP_CODE_SIGN=${SKIP_CODE_SIGN:-1}

echo -e "${BLUE}🔧 Building NovaCore.xcframework...${NC}"
echo -e "${CYAN}Code signing: ${SKIP_CODE_SIGN == 1 ? "SKIPPED" : "ENABLED"}${NC}"

rm -rf "$PWD/outputNova/xcframework"
# Create directories for output
mkdir -p "$PWD/outputNova/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

SWIFT_VERSION=5.0

# Build for simulator and device architectures
if [ "$SKIP_CODE_SIGN" = "1" ]; then
    # Build without code signing
    xcodebuild archive \
        -workspace msp-ios-sdk.xcworkspace \
        -scheme "NovaCore" \
        -destination="iOS" \
        -archivePath "$PWD/outputNova/xcframework/NovaCore-iOS" \
        SKIP_INSTALL=NO \
        -configuration Release \
        -sdk "iphoneos" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO

    xcodebuild archive \
        -workspace msp-ios-sdk.xcworkspace \
        -scheme "NovaCore" \
        -destination="iOS Simulator" \
        -archivePath "$PWD/outputNova/xcframework/NovaCore-Simulator" \
        SKIP_INSTALL=NO \
        -configuration Release \
        -sdk "iphonesimulator" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
else
    # Build with code signing
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
fi

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
