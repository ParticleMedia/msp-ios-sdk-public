# Uncomment the next line to define a global platform for your project
 platform :ios, '13.0'

workspace 'msp-ios-sdk'

project 'PrebidAdapter/PrebidAdapter'
project 'GoogleAdapter/GoogleAdapter'
project 'MSPCore/MSPCore'
project 'MSPDemoApp/MSPDemoApp'
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

  #target 'GoogleAdapterTests' do
  #  pod 'Google-Mobile-Ads-SDK'
  #end
  
target 'MSPDemoApp' do
  project 'MSPDemoApp/MSPDemoApp'
  #pod 'GoogleAdapter',  :path => 'GoogleAdapter', :modular_headers => true
  
  pod 'MSPCore',  :path => 'MSPCore', :modular_headers => true
  pod 'GoogleAdapter',  :path => 'GoogleAdapter', :modular_headers => true
  pod 'MSPSharedLibraries', :path => 'MSPSharedLibraries', :modular_headers => true
 
end
