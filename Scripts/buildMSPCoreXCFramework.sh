# Create directories for output
mkdir -p "$PWD/outputMSPCore/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "MSPCore" \
    -destination="iOS" \
    -archivePath "$PWD/outputMSPCore/xcframework/MSPCore-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch arm64 \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-ios-sdk.xcworkspace \
    -scheme "MSPCore" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/outputMSPCore/xcframework/MSPCore-Simulator" \
    -archivePath "$PWD/outputMSPCore/xcframework/MSPCore-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch x86_64 \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/outputMSPCore/xcframework/MSPCore-iOS.xcarchive/Products/Library/Frameworks/MSPCore.framework" \
    -framework "$PWD/outputMSPCore/xcframework/MSPCore-Simulator.xcarchive/Products/Library/Frameworks/MSPCore.framework" \
    -output "$PWD/outputMSPCore/xcframework/MSPCore.xcframework"
