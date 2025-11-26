Pod::Spec.new do |spec|
  spec.name         = "AmazonAdapter"
  spec.version      = "0.0.92"
  spec.summary      = "an adapter for Amazon SDK"
  spec.description  = "an adapter for Amazon SDK for MSP S2S"
  spec.homepage     = "https://github.com/aimsp/msp-ios-sdk/AmazonAdapter"
  spec.license      = "Copyright"
  spec.author       = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }
  spec.source       = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => "#{spec.version}" }
  spec.platform     = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.requires_arc  = true

  # PURE SWIFT SOURCE POD
  spec.source_files = "Sources/Adapters/AmazonAdapter/**/*.{swift}"

  spec.dependency 'MSPGoogleAdsTypes'
  spec.dependency "AmazonPublisherServicesSDK", "4.5.5"
  spec.dependency "AmazonPublisherServicesAdMobAdapter", "2.2.0"
  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'MSPiOSCore'

  spec.static_framework = true

  # PURE SWIFT MODULE — prevent Clang module generation
  spec.public_header_files = []
  spec.private_header_files = []

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'NO',
    'SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT' => 'NO',
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }
  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }
end
