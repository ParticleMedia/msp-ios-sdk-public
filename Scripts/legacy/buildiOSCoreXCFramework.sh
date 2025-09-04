rm -rf "$PWD/outputMSPiOSCore/xcframework"
# Create directories for output
mkdir -p "$PWD/outputMSPiOSCore/xcframework"

# echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
# pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

SWIFT_VERSION=5.0

# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "MSPiOSCore" \
    -destination="iOS" \
    -archivePath "$PWD/outputMSPiOSCore/xcframework/MSPiOSCore-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "MSPiOSCore" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/outputMSPiOSCore/xcframework/MSPiOSCore-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/outputMSPiOSCore/xcframework/MSPiOSCore-iOS.xcarchive/Products/Library/Frameworks/MSPiOSCore.framework" \
    -framework "$PWD/outputMSPiOSCore/xcframework/MSPiOSCore-Simulator.xcarchive/Products/Library/Frameworks/MSPiOSCore.framework" \
    -output "$PWD/outputMSPiOSCore/xcframework/MSPiOSCore.xcframework"

# Define source and destination paths
SOURCE_XCFRAMEWORK="$PWD/outputMSPiOSCore/xcframework/MSPiOSCore.xcframework"
DESTINATION_DIR="$PWD/MSPSharedLibraries"

# Remove the previous xcframework if it exists
rm -rf "$DESTINATION_DIR/MSPiOSCore.xcframework"

# Copy the new xcframework
cp -R "$SOURCE_XCFRAMEWORK" "$DESTINATION_DIR/"

# Success message
echo -e "\n${GREEN}✅ MSPiOSCore.xcframework has been replaced in MSPSharedLibraries.${NC}\n"
