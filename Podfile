# Uncomment the next line to define a global platform for your project
 platform :ios, '15.0'

workspace 'msp-ios-sdk'
install! 'cocoapods',
         :generate_multiple_pod_projects => true,
         :integrate_targets => false

project 'PrebidAdapter/PrebidAdapter'
project 'MSPGoogleAdapter/MSPGoogleAdapter'
project 'MSPCore/MSPCore'
project 'MSPDemoApp/MSPDemoApp', 'Debug' => :debug, 'Release' => :release
project 'NovaAdapter/NovaAdapter'
project 'MSPSharedLibraries/MSPSharedLibraries'
project 'MSPFacebookAdapter/MSPFacebookAdapter'

project 'InmobiAdapter/InmobiAdapter'
project 'MintegralAdapter/MintegralAdapter'
project 'MobilefuseAdapter/MobilefuseAdapter'
project 'PubmaticAdapter/PubmaticAdapter'
project 'UnityAdapter/UnityAdapter'

# MSP DemoApp integration mode: cocoapods (default) or spm
demoapp_pod_configs = %w[Debug Release]
puts "[MSPDemoApp] Integrating CocoaPods dependencies for DemoApp target"


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

  pod 'SnapKit', :modular_headers => true

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


target 'MSPGoogleAdapter' do
  project 'MSPGoogleAdapter/MSPGoogleAdapter'
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
  #pod 'MSPSharedLibraries', :path => './MSPSharedLibraries', :modular_headers => true
end

target 'MSPFacebookAdapter' do
  project 'MSPFacebookAdapter/MSPFacebookAdapter'
  
end

target 'AmazonAdapter' do
  project 'AmazonAdapter/AmazonAdapter'
  
end

target 'NovaCore' do
  project 'NovaCore/NovaCore'
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!

  # Pods for NovaAdapter
  pod 'lottie-ios', :modular_headers => true
  pod 'Kingfisher', '~> 7.0', :modular_headers => true
  pod 'SnapKit', :modular_headers => true
  #pod 'SDWebImage', '5.18.8', :modular_headers => true
  #pod 'SDWebImageWebPCoder', '0.14.2', :modular_headers => true
  #pod 'SnapKit', '~> 5.6.0', :modular_headers => true
  pod 'Shimmer', :modular_headers => true
  pod 'MSPOMSDK', :path => './', :modular_headers => true
  #pod 'DeviceKit', :modular_headers => true
  #pod 'NBDesignSystem', :git => 'https://github.com/ParticleMedia/LAFoundation', :branch => 'main', :commit => 'b94a948', :modular_headers => true
  #pod 'MSPSharedLibraries', :path => './MSPSharedLibraries', :modular_headers => true
end

  #target 'GoogleAdapterTests' do
  #  pod 'Google-Mobile-Ads-SDK'
  #end
  
target 'MSPDemoApp' do
  project 'MSPDemoApp/MSPDemoApp'

  pod 'MSPCore', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'NovaAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'PrebidAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'MSPGoogleAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'MSPFacebookAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'UnityAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'InmobiAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'MobilefuseAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'MintegralAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'PubmaticAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'AmazonAdapter', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'SwiftProtobuf', '1.30.0', :modular_headers => true, :configurations => demoapp_pod_configs
  pod 'MSPSharedLibraries', :path => './', :modular_headers => true, :configurations => demoapp_pod_configs
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      
      # Disable Swift module interface verification for Pods targets only
      # This fixes archive-time errors: "SwiftVerifyEmittedModuleInterface: underlying Objective-C module 'SnapKit' not found"
      # MSP modules keep verification enabled (they are not in installer.pods_project.targets)
      # 
      # Approach: Disable module interface emission and remove verification build phases
      # This is safe because Pods are pre-built or built separately, and MSP modules don't need Pod interfaces
      config.build_settings['SWIFT_EMIT_MODULE_INTERFACE'] = 'NO'
      config.build_settings['SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT'] = 'NO'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
      config.build_settings['OTHER_SWIFT_FLAGS'] ||= ''
      # Remove any existing -no-verify-emitted-module-interface if present, then add it
      config.build_settings['OTHER_SWIFT_FLAGS'] = config.build_settings['OTHER_SWIFT_FLAGS'].to_s.gsub(/\s*-no-verify-emitted-module-interface\s*/, '').strip
      config.build_settings['OTHER_SWIFT_FLAGS'] << ' -no-verify-emitted-module-interface' unless config.build_settings['OTHER_SWIFT_FLAGS'].include?('-no-verify-emitted-module-interface')
    end
    
    # Remove SwiftVerifyEmittedModuleInterface build phases from Pods targets
    target.build_phases.each do |phase|
      if phase.respond_to?(:name) && phase.name == 'SwiftVerifyEmittedModuleInterface'
        target.build_phases.delete(phase)
      elsif phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
        if phase.shell_script && phase.shell_script.include?('SwiftVerifyEmittedModuleInterface')
          target.build_phases.delete(phase)
        end
      end
    end
  end
end
