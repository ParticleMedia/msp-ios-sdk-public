Pod::Spec.new do |spec|
  spec.name         = "MSPiOSCore"
  spec.version      = "1.0.0"
  spec.summary      = "MSP iOS Core SDK"
  spec.description  = "Core SDK for MSP iOS advertising platform"
  spec.homepage     = "https://github.com/aimsp/msp-ios-sdk"
  spec.license      = "Copyright"
  spec.author       = { "MSP Team" => "msp@newsbreak.com" }
  spec.source       = { :git => "https://github.com/aimsp/msp-ios-sdk.git", :tag => "#{spec.version}" }
  spec.platform     = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.requires_arc = true
  spec.vendored_frameworks = 'build/XCFrameworks/MSPiOSCore.xcframework'
  spec.static_framework = true
end
