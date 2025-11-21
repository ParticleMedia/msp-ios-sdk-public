# NovaCore XcodeGen Migration - Validation Checklist

## Migration Status
- ✅ Phase 1: Analysis Complete
- ✅ Phase 2: NovaCore/project.yml Created
- ✅ Phase 3: build-nova.sh Updated
- ✅ Phase 4: generate_workspace.sh Updated
- ⏳ Phase 5: Validation (To Be Performed)
- ⏳ Phase 6: Manual .xcodeproj Removal (Pending Validation)

## Validation Steps

### Pods Mode Validation

1. **Switch to Pods Mode**
   ```bash
   ./Scripts/target-switching/switch-target.sh pods
   ```
   - [ ] Command completes without errors
   - [ ] workspace.yml includes `NovaCore/project.yml` (not `.xcodeproj`)
   - [ ] XcodeGen generates NovaCore.xcodeproj successfully

2. **Install Pods**
   ```bash
   LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
   ```
   - [ ] `pod install` completes successfully
   - [ ] `Pods/Target Support Files/Pods-NovaCore/` directory exists
   - [ ] xcconfig files are generated correctly

3. **Build NovaCore (Archive)**
   ```bash
   SKIP_CODE_SIGN=1 ./Scripts/xcframeworks/internal/build-nova.sh
   ```
   - [ ] Build completes without errors
   - [ ] "[CP] Check Pods Manifest.lock" script phase succeeds
   - [ ] No errors about `NovaCore/Pods/Manifest.lock` missing
   - [ ] NovaCore.xcframework is created successfully
   - [ ] XCFramework contains both device and simulator slices

4. **Build MSPDemoApp (Pods Mode)**
   ```bash
   xcodebuild -workspace msp-ios-sdk.xcworkspace -scheme MSPDemoApp -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build
   ```
   - [ ] Build completes successfully
   - [ ] No NovaCore-related errors

### SPM Mode Validation

1. **Switch to SPM Mode**
   ```bash
   ./Scripts/target-switching/switch-target.sh spm
   ```
   - [ ] Command completes without errors
   - [ ] workspace.yml includes `NovaCore/project.yml` (not `.xcodeproj`)
   - [ ] workspace.yml does NOT include `Pods/Pods.xcodeproj`

2. **Verify XCFramework Exists**
   ```bash
   test -d NovaAdapter/NovaCore.xcframework && echo "✅ Found" || echo "❌ Missing"
   ```
   - [ ] NovaCore.xcframework exists (built in Pods mode)

3. **Build MSPDemoApp-SPM**
   ```bash
   xcodebuild -workspace msp-ios-sdk.xcworkspace -scheme MSPDemoApp-SPM -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build
   ```
   - [ ] Build completes successfully
   - [ ] No NovaCore build errors (SPM mode should NOT rebuild NovaCore)
   - [ ] SPM mode correctly consumes NovaCore.xcframework

### Round-Trip Validation

1. **Pods → SPM → Pods**
   ```bash
   ./Scripts/target-switching/switch-target.sh pods
   # Build NovaCore.xcframework
   ./Scripts/target-switching/switch-target.sh spm
   # Build MSPDemoApp-SPM
   ./Scripts/target-switching/switch-target.sh pods
   # Build MSPDemoApp
   ```
   - [ ] All switches complete without errors
   - [ ] No mode pollution (clean state after each switch)
   - [ ] All builds succeed

## Critical Validations

### PODS_ROOT Validation
- [ ] NovaCore target has `PODS_ROOT = $(SRCROOT)/../Pods` (not `$(SRCROOT)/Pods`)
- [ ] "[CP] Check Pods Manifest.lock" uses correct paths
- [ ] No errors about `NovaCore/Pods/Manifest.lock` missing

### XCFramework Validation
- [ ] NovaCore.xcframework contains `Info.plist`
- [ ] Both slices present: `ios-arm64` and `ios-arm64_x86_64-simulator`
- [ ] Framework structure is correct
- [ ] No duplicate symbols

### Build Settings Validation
- [ ] `BUILD_LIBRARY_FOR_DISTRIBUTION = YES`
- [ ] `DEFINES_MODULE = YES`
- [ ] `CLANG_ENABLE_MODULES = YES`
- [ ] `SWIFT_VERSION = 5.0`
- [ ] `IPHONEOS_DEPLOYMENT_TARGET = 15.0`

## Removal Criteria for Manual NovaCore.xcodeproj

**DO NOT DELETE** `NovaCore/NovaCore.xcodeproj` until ALL of the following are true:

1. ✅ All Pods mode validations pass
2. ✅ All SPM mode validations pass
3. ✅ Round-trip switching works correctly
4. ✅ XCFramework generation works reliably
5. ✅ CI builds succeed with XcodeGen-generated project
6. ✅ No manual PODS_ROOT fixes needed in Podfile
7. ✅ No errors in build logs related to NovaCore project structure

## Post-Removal Steps (After Validation Passes)

1. Delete `NovaCore/NovaCore.xcodeproj` directory
2. Update `.gitignore` if needed (to ignore generated project)
3. Update any documentation referencing manual NovaCore project
4. Verify no scripts reference `NovaCore/NovaCore.xcodeproj` directly

