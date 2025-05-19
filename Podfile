# Uncomment the next line to define a global platform for your project
 platform :ios, '13.0'

workspace 'msp-ios-sdk'

#project 'PrebidAdapter/PrebidAdapter'
project 'GoogleAdapter/GoogleAdapter'
project 'FacebookAdapter/FacebookAdapter'
project 'MSPCore/MSPCore'

project 'MSPDemoApp'
#project 'MSPSharedLibraries/MSPSharedLibraries'

#target 'PrebidAdapter' do
#  project 'PrebidAdapter/PrebidAdapter'
  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!

  # Pods for PrebidAdapter

#  target 'PrebidAdapterTests' do
    # Pods for testing
#  end

#end

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

#target 'MSPSharedLibraries' do
#  project 'MSPSharedLibraries/MSPSharedLibraries'
  
#end


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
  project 'MSPDemoApp'
  
  pod 'MSPCore', '0.0.116', :modular_headers => true
  pod 'NovaAdapter', '0.0.116', :modular_headers => true
#pod 'PrebidAdapter', '0.0.116', :modular_headers => true
  pod 'GoogleAdapter', '0.0.116', :modular_headers => true
  pod 'FacebookAdapter', '0.0.116', :modular_headers => true
  #pod 'MSPSharedLibraries', :path => './', :modular_headers => true
  #pod 'FBAudienceNetwork', '6.17.1'
end
