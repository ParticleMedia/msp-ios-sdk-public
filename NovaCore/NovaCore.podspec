Pod::Spec.new do |spec|
  spec.name         = "NovaCore"
  spec.version      = "0.0.95"
  spec.summary      = "NovaCore framework for MSP"
  spec.description  = "NovaCore framework for MSP SDK"
  spec.homepage     = "https://github.com/aimsp/msp-ios-sdk/NovaCore"
  spec.license      = "Copyright"
  spec.author       = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }
  spec.ios.deployment_target = '15.0'
  spec.dependency 'MSPSharedLibraries'
  spec.dependency 'Shimmer'
  spec.dependency 'SnapKit'
  spec.dependency 'SDWebImage'
  spec.static_framework = true

  # Support for local development and binary distribution
  if ENV['NOVA_CORE_LOCAL_DEVELOPMENT']
    spec.source       = { :path => '.' }
    spec.source_files  = "NovaCore/**/*.{h,m,swift}"
    # Only include resource bundles if not already included by other pods
    unless ENV['NOVA_CORE_SKIP_RESOURCES']
      spec.resource_bundles = {
        'IconResourceBundle' => ['NovaCore/IconResourceBundle.bundle/**/*'],
        'ImageResourceBundle' => ['NovaCore/ImageResourceBundle.bundle/**/*'],
        'NBResourceBundle' => ['NovaCore/NBResourceBundle.bundle/**/*']
      }
    end
  else
    spec.source       = { :git => "https://github.com/ParticleMedia/msp-ios-sdk-public.git", :tag => "#{spec.version}" }
    spec.vendored_frameworks = "outputNova/xcframework/NovaCore.xcframework"
  end

  # For Objective-C
  spec.pod_target_xcconfig = {
    'OTHER_CFLAGS' => '-Werror'
  }

  # For Swift
  spec.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-warnings-as-errors'
  }
end
