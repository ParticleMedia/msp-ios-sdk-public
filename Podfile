# Uncomment the next line to define a global platform for your project
 platform :ios, '13.0'

workspace 'msp-ios-sdk'

project 'PrebidAdapter/PrebidAdapter'
project 'GoogleAdapter/GoogleAdapter'
project 'MSPCore/MSPCore'
project 'MSPDemoApp/MSPDemoApp'
project 'NovaAdapter/NovaAdapter'
project 'MSPSharedLibraries/MSPSharedLibraries'
project 'FacebookAdapter/FacebookAdapter'

project 'InmobiAdapter/InmobiAdapter'
project 'MintegralAdapter/MintegralAdapter'
project 'MobilefuseAdapter/MobilefuseAdapter'
project 'PubmaticAdapter/PubmaticAdapter'
project 'UnityAdapter/UnityAdapter'


target 'PrebidAdapter' do
  project 'PrebidAdapter/PrebidAdapter'
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PrebidAdapter

  target 'PrebidAdapterTests' do
    # Pods for testing
  end

end

target 'MSPCore' do
  project 'MSPCore/MSPCore'
  # Comment the next line if you don't want to use dynamic frameworks
  # use_frameworks!

  # Pods for MSPCore
  # use_frameworks! :linkage => :static
  #pod 'Google-Mobile-Ads-SDK', "10.14.0", :modular_headers => true
  #pod 'GoogleAdapter',  :path => 'GoogleAdapter', :modular_headers => true

  pod 'SnapKit', '~> 5.6.0', :modular_headers => true

  #target 'MSPUtilityTests' do
    # Pods for testing
  #end

end

target 'MSPSharedLibraries' do
  project 'MSPSharedLibraries/MSPSharedLibraries'
  
end

target 'MSPOMSDK' do
  project 'MSPOMSDK/MSPOMSDK'
  
end


target 'GoogleAdapter' do
  project 'GoogleAdapter/GoogleAdapter'
  # Comment the next line if you don't want to use dynamic frameworks
  # use_frameworks!

  # Pods for GoogleAdapter
  # pod 'Google-Mobile-Ads-SDK', "10.14.0", :modular_headers => true
end

target 'NovaAdapter' do
  project 'NovaAdapter/NovaAdapter'
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!

  # Pods for NovaAdapter
  #pod 'SDWebImage', '5.18.8', :modular_headers => true
  #pod 'SDWebImageWebPCoder', '0.14.2', :modular_headers => true
  #pod 'SnapKit', '~> 5.6.0', :modular_headers => true
  #pod 'Shimmer', :modular_headers => true
  #pod 'DeviceKit', :modular_headers => true
  #pod 'NBDesignSystem', :git => 'https://github.com/ParticleMedia/LAFoundation', :branch => 'main', :commit => 'b94a948', :modular_headers => true
  #pod 'MSPSharedLibraries', :path => './', :modular_headers => true
end

target 'FacebookAdapter' do
  project 'FacebookAdapter/FacebookAdapter'
  
end

target 'AmazonAdapter' do
  project 'AmazonAdapter/AmazonAdapter'
  
end

target 'NovaCore' do
  project 'NovaCore/NovaCore'
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!

  # Pods for NovaAdapter
  #pod 'SDWebImage', '5.18.8', :modular_headers => true
  #pod 'SDWebImageWebPCoder', '0.14.2', :modular_headers => true
  #pod 'SnapKit', '~> 5.6.0', :modular_headers => true
  pod 'Shimmer', :modular_headers => true
  pod 'MSPOMSDK', :path => './', :modular_headers => true
  #pod 'DeviceKit', :modular_headers => true
  #pod 'NBDesignSystem', :git => 'https://github.com/ParticleMedia/LAFoundation', :branch => 'main', :commit => 'b94a948', :modular_headers => true
  #pod 'MSPSharedLibraries', :path => './', :modular_headers => true
end

  #target 'GoogleAdapterTests' do
  #  pod 'Google-Mobile-Ads-SDK'
  #end
  
target 'MSPDemoApp' do
  project 'MSPDemoApp/MSPDemoApp'
  #pod 'GoogleAdapter',  :path => 'GoogleAdapter', :modular_headers => true
  #use_frameworks!
  #pod 'MSPCore', '0.0.59', :modular_headers => true
  pod 'MSPCore', :path => './', :modular_headers => true
  pod 'NovaAdapter', :path => './', :modular_headers => true
  pod 'PrebidAdapter', :path => './', :modular_headers => true
  pod 'GoogleAdapter', :path => './', :modular_headers => true
  pod 'FacebookAdapter', :path => './', :modular_headers => true
  #pod 'IronSourceSDK','8.6.0.0', :modular_headers => true
  pod 'UnityAdapter', :path => './', :modular_headers => true
  pod 'InmobiAdapter', :path => './', :modular_headers => true
  pod 'MobilefuseAdapter', :path => './', :modular_headers => true
  pod 'MintegralAdapter', :path => './', :modular_headers => true
  pod 'PubmaticAdapter', :path => './', :modular_headers => true
  pod 'AmazonAdapter', :path => './', :modular_headers => true
  #pod 'GoogleMobileAds', :modular_headers => true
  #pod 'NovaAdapter', :path => './', :modular_headers => true
  #pod 'MetaAdapter', :path => './', :modular_headers => true
  #pod 'SDWebImage', '5.18.8', :modular_headers => true
  #pod 'SDWebImageWebPCoder', '0.14.2', :modular_headers => true
  #pod 'NBDesignSystem', :git => 'https://github.com/ParticleMedia/LAFoundation', :branch => 'main', :commit => 'b94a948', :modular_headers => true
  pod 'MSPSharedLibraries', :path => './', :modular_headers => true
 
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      #config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['OTHER_SWIFT_FLAGS'] = '-no-verify-emitted-module-interface'
    end
  end
end




