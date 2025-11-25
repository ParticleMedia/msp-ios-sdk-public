#
#  Be sure to run `pod spec lint NovaCore.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "NovaCore"
  spec.version      = "0.0.95"
  spec.summary      = "Nova Core Framework"
  spec.description  = "Core framework for Nova SDK"

  spec.ios.deployment_target = '15.0'
  spec.swift_version = '5.0'

  spec.homepage     = "https://github.com/aimsp/msp-ios-sdk/NovaCore"
  spec.license      = "Copyright"
  spec.author       = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }

  spec.source       = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => "#{spec.version}" }

  spec.platform     = :ios, '15.0'
  spec.requires_arc  = true

  spec.vendored_frameworks = "Build/XCFrameworks/NovaCore.xcframework"
  spec.module_name = 'NovaCore'

  spec.dependency 'MSPiOSCore'

  spec.static_framework = true

  spec.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }
  spec.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) $(PODS_ROOT)/../Build/XCFrameworks'
  }

end

