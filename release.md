# Release 0.3.0-rc.13

## Changes

### Architecture Improvements

1. **Decoupled Release Order and Distribution Method**
   - Renamed `CORE_MODULES` → `BINARY_DISTRIBUTION_PODS`
   - Renamed `is_core_module()` → `is_binary_distribution()`
   - Clarified two independent dimensions:
     - Release Order (based on dependencies)
     - Distribution Method (implementation detail)

2. **Fixed Slack Notifications**
   - Replaced `notify_release_failure()` → `notify::module_error()`
   - Failure notifications now DM-only (no channel spam)
   - Uses templates from `slack_mapping.yaml`
   - Smart Routing automatically finds release author

3. **NovaAdapter Correct Positioning**
   - Uses binary distribution (includes private NovaCore.xcframework)
   - Released in Adapters phase (Step 2), not with MSPiOSCore
   - Correct release order based on dependencies

### Bug Fixes

- Unified test/release tier GitHub Release creation logic
- Fixed NovaAdapter GitHub Release creation (was missing zip upload)
- Improved MSPiOSCore failure handling
- Allowed test tier to continue after CocoaPods failure

### Technical Details

- Release Order: MSPiOSCore → MSPSharedLibraries → Adapters → MSPCore
- Binary Distribution: MSPiOSCore, MSPSharedLibraries, MSPCore, NovaAdapter
- Source Distribution: MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter, AmazonAdapter
