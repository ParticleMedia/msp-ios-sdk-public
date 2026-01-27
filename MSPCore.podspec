#
#  Be sure to run `pod spec lint MSPCore.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "MSPCore"
  spec.version      = "2.7.1"
  spec.summary      = "An utility helper for MSP"

  spec.ios.deployment_target = '15.0'
  spec.swift_version = '5.0'

  spec.description  = "An utility for MSP settings"
  spec.homepage     = "https://github.com/ParticleMedia/msp-ios-sdk-public"

  spec.license      = "Copyright"

  spec.author             = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }

  # ═══════════════════════════════════════════════════════════════════════════
  # DUAL-MODE SUPPORT: Development (source) vs Release (binary)
  # ═══════════════════════════════════════════════════════════════════════════
  msp_release = ENV['MSP_RELEASE'] == '1'

  if msp_release
    # RELEASE MODE: Binary XCFramework for external distribution
    spec.source = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => spec.version.to_s }
    spec.vendored_frameworks = "Binary/MSPCore.xcframework"
  else
    # DEVELOPMENT MODE: Source files for internal development
    spec.source = { :path => '.' }
    spec.source_files = "Sources/Core/MSPCore/MSPCore/**/*.{swift,h,m}"
    spec.resources = "Sources/Core/MSPCore/MSPCore/Resources/**/*"
  end

  spec.platform     = :ios, '15.0'
  spec.requires_arc  = true

  spec.module_name = 'MSPCore'

  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'MSPPrebidAdapter'
  spec.dependency 'SwiftProtobuf'   # Protocol Buffers for MES events
  spec.dependency 'MSPSnapKit'         # Auto Layout DSL

  spec.static_framework = true

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks'
  }
  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/ReleaseArtifacts/XCFrameworks'
  }

end
