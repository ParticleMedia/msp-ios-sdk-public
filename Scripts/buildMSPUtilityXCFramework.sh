# Create directories for output
mkdir -p "$PWD/outputMSPUtility/xcframework"

echo -e "\n\n${GREEN}INSTALL PODS${NC}\n\n"

#gem install cocoapods --user-install
pod install --repo-update

echo -e "\n\n${GREEN}BUILD ADAPTERS${NC}\n\n"

# Build for simulator and device architectures
xcodebuild archive \
    -workspace msp-adapter-demo.xcworkspace \
    -scheme "MSPUtility" \
    -destination="iOS" \
    -archivePath "$PWD/outputMSPUtility/xcframework/MSPUtility-iOS" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch arm64 \
    -sdk "iphoneos" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
    -workspace msp-adapter-demo.xcworkspace \
    -scheme "MSPUtility" \
    -destination="iOS Simulator" \
    -archivePath "$PWD/outputMSPUtility/xcframework/MSPUtility-Simulator" \
    SKIP_INSTALL=NO \
    -configuration Release \
    -arch x86_64 \
    -sdk "iphonesimulator" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create xcframework
xcodebuild -create-xcframework \
    -framework "$PWD/outputMSPUtility/xcframework/MSPUtility-iOS.xcarchive/Products/Library/Frameworks/MSPUtility.framework" \
    -framework "$PWD/outputMSPUtility/xcframework/MSPUtility-Simulator.xcarchive/Products/Library/Frameworks/MSPUtility.framework" \
    -output "$PWD/outputMSPUtility/xcframework/MSPUtility.xcframework"
