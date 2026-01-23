# ═══════════════════════════════════════════════════════════════════════════════
# NovaCore.podspec
# Nova ad format engine for MSP SDK
# ═══════════════════════════════════════════════════════════════════════════════

Pod::Spec.new do |spec|

  spec.name         = "NovaCore"
  spec.module_name  = "NovaCore"
  spec.version      = "0.0.95"
  spec.summary      = "Nova ad format engine"
  spec.description  = "Core rendering and logic for Nova ad format."
  spec.homepage     = "https://github.com/ParticleMedia/msp-ios-sdk-public"
  spec.license      = "Copyright"
  spec.author       = { "pengyu.gou" => "pengyu.gou@newsbreak.com" }

  spec.ios.deployment_target = "15.0"
  spec.swift_version = "5.0"
  spec.platform     = :ios, "15.0"
  spec.static_framework = true
  spec.requires_arc = true

  # ═══════════════════════════════════════════════════════════════════════════
  # DUAL-MODE SUPPORT: Development (source) vs Release (binary)
  # ═══════════════════════════════════════════════════════════════════════════
  msp_release = ENV['MSP_RELEASE'] == '1'

  if msp_release
    # RELEASE MODE: Binary XCFramework for external distribution
    # OMSDK is embedded in NovaCore.xcframework
    spec.source = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public", :tag => "#{spec.version}" }
    spec.vendored_frameworks = "Binary/NovaCore.xcframework"
  else
    # DEVELOPMENT MODE: Source files for internal development
    # OMSDK_Newsbreak1.xcframework is vendored directly (no MSPOMSDK wrapper)
    spec.source = { :path => '.' }
    spec.source_files = "Sources/Core/NovaCore/NovaCore/**/*.{swift,h,m}"
    spec.resources = [
      "Sources/Core/NovaCore/NovaCore/NBResourceBundle.bundle",
      "Sources/Core/NovaCore/NovaCore/Resources/**/*"
    ]
    spec.vendored_frameworks = [
      "Sources/Core/MSPOMSDK/OMSDK_Newsbreak1.xcframework",
      "ThirdParty/Shimmer/Shimmer.xcframework"
    ]
  end

  # Dependencies
  spec.dependency 'MSPiOSCore'     # Ad protocols and interfaces
  spec.dependency 'MSPKingfisher'  # Image loading (forked Kingfisher)
  spec.dependency 'lottie-ios'     # Animation support
  spec.dependency 'SnapKit'        # Auto Layout DSL
  # Shimmer is provided via vendored_frameworks (XCFramework) in development mode
  # No spec.dependency needed to avoid duplicate linking

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks $(PODS_ROOT)/../ThirdParty/Shimmer',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }
  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }

end
