# Create directories for output
mkdir -p "$PWD/outputNova/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

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
