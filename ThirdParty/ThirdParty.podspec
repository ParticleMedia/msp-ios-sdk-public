Pod::Spec.new do |s|
  s.name             = 'MSPThirdParty'
  s.version          = '1.0.0'
  s.summary          = 'Third-party XCFramework bundle for MSP pods-dev mode'
  s.description      = 'Embeds XCFramework dependencies NOT provided by CocoaPods.'
  s.homepage         = 'https://newsbreak.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'MSP Team' => 'pengyu.gou@newsbreak.com' }

  s.source           = { :path => '.' }
  s.ios.deployment_target = '12.0'

  # ONLY include XCFrameworks that are NOT provided by CocoaPods
  # The following are already provided by Pods:
  #   - FBAudienceNetwork (FBAudienceNetwork pod)
  #   - InMobiSDK (InMobiSDK pod)
  #   - Lottie (lottie-ios pod)
  #   - MintegralAdSDK/MTGSDK* (MintegralAdSDK pod)
  #   - MobileFuseSDK (MobileFuseSDK pod)
  #   - OpenWrapSDK (OpenWrapSDK pod)
  #   - Shimmer (Shimmer pod)
  #   - SwiftProtobuf (SwiftProtobuf pod)
  #   - IronSourceSDK (IronSourceSDK pod)
  #   - AmazonPublisherServicesSDK (AmazonPublisherServicesSDK pod)
  #   - SnapKit (SnapKit pod)
  #   - Kingfisher (MSPKingfisher custom pod)
  #
  # Only PrebidMobile is NOT provided by any CocoaPod:
  s.vendored_frameworks = 'PrebidMobile/PrebidMobile.xcframework'
end

