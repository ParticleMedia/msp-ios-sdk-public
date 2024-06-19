# Create directories for output
mkdir -p "$PWD/outputNova/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "NovaAdapter" \
    -destination="iOS" \
    -archivePath "$PWD/outputNova/xcframework/NovaAdapter-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch arm64 \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "NovaAdapter" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/outputNova/xcframework/NovaAdapter-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch x86_64 \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/outputNova/xcframework/NovaAdapter-iOS.xcarchive/Products/Library/Frameworks/NovaAdapter.framework" \
    -framework "$PWD/outputNova/xcframework/NovaAdapter-Simulator.xcarchive/Products/Library/Frameworks/NovaAdapter.framework" \
    -output "$PWD/outputNova/xcframework/NovaAdapter.xcframework"
