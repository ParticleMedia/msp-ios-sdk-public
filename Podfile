# Uncomment the next line to define a global platform for your project
 platform :ios, '13.0'

workspace 'msp-ios-sdk'

project 'PrebidAdapter/PrebidAdapter'
project 'GoogleAdapter/GoogleAdapter'
project 'MSPCore/MSPCore'
project 'MSPDemoApp/MSPDemoApp'
project 'NovaAdapter/NovaAdapter'
project 'MSPSharedLibraries/MSPSharedLibraries'

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

  #target 'MSPUtilityTests' do
    # Pods for testing
  #end

end

target 'MSPSharedLibraries' do
  project 'MSPSharedLibraries/MSPSharedLibraries'
  
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
  # use_frameworks!

  # Pods for NovaAdapter
  pod 'SDWebImage', '5.18.8', :modular_headers => true
  pod 'SDWebImageWebPCoder', '0.14.2', :modular_headers => true
  pod 'SnapKit', '~> 5.6.0', :modular_headers => true
  pod 'NBDesignSystem', :git => 'https://github.com/ParticleMedia/LAFoundation', :branch => 'main', :commit => $local_ai_version, :modular_headers => true
end

  #target 'GoogleAdapterTests' do
  #  pod 'Google-Mobile-Ads-SDK'
  #end
  
target 'MSPDemoApp' do
  project 'MSPDemoApp/MSPDemoApp'
  #pod 'GoogleAdapter',  :path => 'GoogleAdapter', :modular_headers => true
  
  pod 'MSPCore', :path => './', :modular_headers => true
  pod 'GoogleAdapter', :path => './', :modular_headers => true
  pod 'MSPSharedLibraries', :path => './', :modular_headers => true
 
end
