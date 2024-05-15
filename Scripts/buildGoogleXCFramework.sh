# Create directories for output
mkdir -p "$PWD/outputGoogle/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-adapter-demo.xcworkspace \
    -scheme "GoogleAdapter" \
    -destination="iOS" \
    -archivePath "$PWD/outputGoogle/xcframework/GoogleAdapter-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch arm64 \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-adapter-demo.xcworkspace \
    -scheme "GoogleAdapter" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/outputGoogle/xcframework/GoogleAdapter-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch x86_64 \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/outputGoogle/xcframework/GoogleAdapter-iOS.xcarchive/Products/Library/Frameworks/GoogleAdapter.framework" \
    -framework "$PWD/outputGoogle/xcframework/GoogleAdapter-Simulator.xcarchive/Products/Library/Frameworks/GoogleAdapter.framework" \
    -output "$PWD/outputGoogle/xcframework/GoogleAdapter.xcframework"
