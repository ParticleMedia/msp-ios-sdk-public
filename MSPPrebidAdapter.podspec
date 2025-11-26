Pod::Spec.new do |spec|
  spec.name         = "MSPPrebidAdapter"
  spec.version      = "0.0.95"
  spec.summary      = "Prebid adapter for MSP SDK"
  spec.description  = "Adapter for PrebidMobile integration for MSP S2S"

  spec.homepage     = "https://github.com/ParticleMedia/msp-ios-sdk-public"
  spec.license      = "Copyright"
  spec.author       = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }
  spec.source       = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => "#{spec.version}" }

  spec.platform     = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.requires_arc  = true

  # PURE SWIFT SOURCE POD
  spec.source_files = "Sources/Adapters/MSPPrebidAdapter/**/*.{swift}"

  # DEPENDENCIES
  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'MSPiOSCore'
  # PrebidMobile is embedded in MSPSharedLibraries.xcframework

  spec.static_framework = true

  # PURE SWIFT MODULE — prevent Clang module generation
  spec.public_header_files = []
  spec.private_header_files = []

  # DISABLE SWIFT INTERFACE GENERATION - MSPCore uses @_implementationOnly import
  # Canonical paths synchronized with Package.swift (SPM)
  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'NO',
    'SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT' => 'NO',
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks $(PODS_ROOT)/../ThirdParty/PrebidMobile $(PODS_ROOT)/../ThirdParty/PrebidMobile/PrebidMobile.xcframework/$(PLATFORM_NAME)'
  }

  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks $(PODS_ROOT)/../ThirdParty/PrebidMobile'
  }
end
