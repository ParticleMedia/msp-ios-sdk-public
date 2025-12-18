

Pod::Spec.new do |spec|

  

  spec.name         = "LiftoffAdapter"
  spec.version      = "0.0.1"
  spec.summary      = "an adapter for Liftoff SDK"
  spec.description  = "an adapter for Liftoff SDK"

  spec.homepage     = "https://github.com/aimsp/msp-ios-sdk/MetaAdapter"
 
  spec.license      = "Copyright"

  spec.author             = { "Mingming Luo" => "mingming.luo@newsbreak.com" }

  spec.source       = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => "#{spec.version}" }

  spec.ios.deployment_target = '15.0'


  spec.source_files  = "LiftoffAdapter/LiftoffAdapter/**/*.{h,m,swift}"
  spec.exclude_files = "Classes/Exclude"

  spec.dependency 'VungleAds'
  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'SnapKit'

  spec.pod_target_xcconfig = { 'VALID_ARCHS' => 'x86_64 armv7 arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  spec.static_framework = true

end
