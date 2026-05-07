Pod::Spec.new do |spec|
  spec.name         = "MSPApplovinMaxAdapter"
  spec.version      = "0.0.92"
  spec.summary      = "an adapter for AppLovin MAX SDK"
  spec.description  = "an adapter for AppLovin MAX SDK for MSP C2S"
  spec.homepage     = "https://github.com/ParticleMedia/msp-ios-sdk-public"
  spec.license      = "Copyright"
  spec.author       = { "MingmingLuo" => "mingming.luo@newsbreak.com" }
  spec.platform     = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.requires_arc  = true

  # ═══════════════════════════════════════════════════════════════════════════
  # DUAL-MODE SUPPORT: Development (source) vs Release (binary)
  # ═══════════════════════════════════════════════════════════════════════════
  msp_release = ENV['MSP_RELEASE'] == '1'

  if msp_release
    # RELEASE MODE: Binary XCFramework for external distribution
    spec.source = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => spec.version.to_s }
    spec.vendored_frameworks = "Binary/MSPApplovinMaxAdapter.xcframework"
  else
    # DEVELOPMENT MODE: Source files for internal development
    spec.source = { :path => '.' }
    spec.source_files = "Sources/Adapters/ApplovinMaxAdapter/ApplovinMaxAdapter/**/*.{swift}"
  end

  spec.dependency 'AppLovinSDK'
  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'MSPiOSCore'
  spec.dependency 'MSPSnapKit'

  spec.static_framework = true

  # PURE SWIFT MODULE — prevent Clang module generation
  spec.public_header_files = []
  spec.private_header_files = []

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'NO',
    'SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT' => 'NO',
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks'
  }
  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks'
  }
end
