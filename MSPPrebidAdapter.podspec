Pod::Spec.new do |spec|
  spec.name         = "MSPPrebidAdapter"
  spec.version      = "0.0.95"
  spec.summary      = "Prebid adapter for MSP S2S"
  spec.description  = "Adapter for PrebidMobile integration for MSP S2S"

  spec.homepage     = "https://github.com/ParticleMedia/msp-ios-sdk-public"
  spec.license      = "Copyright"
  spec.author       = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }
  spec.source       = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => "#{spec.version}" }

  spec.platform     = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.requires_arc  = true

  spec.source_files = "Sources/Adapters/MSPPrebidAdapter/**/*.{swift}"

  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'MSPiOSCore'

  spec.static_framework = true

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'NO',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }

  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }
end
