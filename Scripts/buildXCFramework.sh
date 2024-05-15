# Create directories for output
mkdir -p "$PWD/output/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "PrebidAdapter" \
    -destination="iOS" \
    -archivePath "$PWD/output/xcframework/PrebidAdapter-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch arm64 \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "PrebidAdapter" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/output/xcframework/PrebidAdapter-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch x86_64 \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/output/xcframework/PrebidAdapter-iOS.xcarchive/Products/Library/Frameworks/PrebidAdapter.framework" \
    -framework "$PWD/output/xcframework/PrebidAdapter-Simulator.xcarchive/Products/Library/Frameworks/PrebidAdapter.framework" \
    -output "$PWD/output/xcframework/PrebidAdapter.xcframework"
