# MSPGoogleAdsTypes.podspec
# Abstraction layer for GoogleMobileAds SDK - provides unified API for CocoaPods and SPM

Pod::Spec.new do |spec|
  spec.name         = "MSPGoogleAdsTypes"
  spec.version      = "0.0.95"
  spec.summary      = "Abstraction layer for GoogleMobileAds SDK types"
  spec.description  = "Provides unified typealias abstraction for GoogleMobileAds SDK types across CocoaPods and SPM"
  spec.homepage     = "https://github.com/ParticleMedia/msp-ios-sdk-public"
  spec.license      = "Copyright"
  spec.author       = { "MSP Team" => "msp@newsbreak.com" }

  spec.platform     = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.requires_arc = true

  # ═══════════════════════════════════════════════════════════════════════════
  # DUAL-MODE SUPPORT: Development (source) vs Release (binary)
  # ═══════════════════════════════════════════════════════════════════════════
  msp_release = ENV['MSP_RELEASE'] == '1'

  if msp_release
    # RELEASE MODE: Binary XCFramework for external distribution
    spec.source = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => spec.version.to_s }
    spec.vendored_frameworks = "Binary/MSPGoogleAdsTypes.xcframework"
  else
    # DEVELOPMENT MODE: Source files for internal development
    spec.source = { :path => '.' }
    spec.source_files = "Sources/Common/MSPGoogleAdsTypes/**/*.{swift}"
  end

  # Google Mobile Ads SDK dependency
  spec.dependency 'Google-Mobile-Ads-SDK', '~> 12.0'

  spec.static_framework = true

  # No header files - pure Swift module
  spec.public_header_files = []
  spec.private_header_files = []
  spec.module_map = nil

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'NO',
    'SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT' => 'NO',
    'DEFINES_MODULE' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => '',
    'SWIFT_OBJC_BRIDGING_HEADER' => ''
  }

  spec.user_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'NO',
    'SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT' => 'NO'
  }
end
