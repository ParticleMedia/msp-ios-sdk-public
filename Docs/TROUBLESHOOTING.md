# Troubleshooting

## Build Failures

### Missing XCFramework

**Symptom:** Build fails with "Missing required XCFramework: MSPCore.xcframework"

**Cause:** XCFrameworks not built before switching to release mode

**Fix:**
```bash
./Scripts/xcframeworks/build-core.sh
```

### Swift Module/Class Name Collision

**Symptom:** Compiler error: "Cannot extend struct 'X' that has the same name as its enclosing module"

**Cause:** Module name equals class name in Swift

**Fix:** The module should use MSP prefix (e.g., `MSPAmazonAdapter`) while the class uses simple name (e.g., `AmazonAdapter`). Verify `PRODUCT_NAME` and `PRODUCT_MODULE_NAME` in project.yml.template.

### SwiftVerifyEmittedModuleInterface Errors

**Symptom:** Build fails with module interface verification errors

**Cause:** Third-party pod built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`

**Fix:** Use MSPKingfisher wrapper instead of official Kingfisher pod, or ensure post_install hook disables verification.

## Mode Switching Failures

### Git Dirty After Switch

**Symptom:** Round-trip test fails with "Git is dirty after mode switch"

**Cause:** Generated files not matching templates

**Fix:**
```bash
git checkout -- .
./Scripts/switch-target.sh pods-dev
```

### XcodeGen Fails

**Symptom:** "xcodegen not found" or project generation errors

**Cause:** XcodeGen not installed or wrong version

**Fix:**
```bash
brew install xcodegen
# or
brew upgrade xcodegen
```

## Release Failures

### CocoaPods Trunk Authentication

**Symptom:** "You must be authenticated to push to CocoaPods Trunk"

**Cause:** Not logged into CocoaPods Trunk

**Fix:**
```bash
pod trunk register your.email@example.com
```

### GitHub Push Protection

**Symptom:** Tag push blocked by GitHub Push Protection

**Cause:** GitHub detects potential secret in commit

**Fix:**
```bash
# After resolving the protection (skip or allow)
./Scripts/msp-release.sh fix-public-tag <version>
```

### Tag SHA Mismatch

**Symptom:** "Tag SHA mismatch between origin and public"

**Cause:** Tag was modified after initial push

**Fix:**
```bash
# Delete and recreate tag
git tag -d <version>
git push origin :refs/tags/<version>
git tag <version>
git push origin <version>
./Scripts/msp-release.sh fix-public-tag <version>
```

### Pod Dependency Order

**Symptom:** Pod push fails with "Unable to find a specification for dependency"

**Cause:** Publishing pods out of dependency order

**Fix:** Verify modules are listed in correct order in Scripts/config/release.yaml. Dependencies must be published before dependents.

## SPM Failures

### Missing ThirdParty XCFrameworks

**Symptom:** SPM resolution fails with missing binaryTarget

**Cause:** ThirdParty XCFrameworks not synced from Pods

**Fix:**
```bash
./Scripts/spm/sync_thirdparty_pods.sh --force
```

### Checksum Mismatch

**Symptom:** SPM fails with checksum verification error

**Cause:** XCFramework was rebuilt after checksum was generated

**Fix:** Regenerate Package.swift with updated checksums after rebuilding XCFrameworks.

## DemoApp Failures

### Pods Not Found

**Symptom:** DemoApp build fails with "No such module 'MSPCore'"

**Cause:** Pods not installed or wrong mode

**Fix:**
```bash
./Scripts/switch-target.sh pods-dev
pod install
```

### Simulator Architecture

**Symptom:** Build fails for simulator with architecture errors

**Cause:** XCFramework missing simulator slice

**Fix:** Rebuild XCFrameworks with `build-core.sh` which includes both device and simulator architectures.
