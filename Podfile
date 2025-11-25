
# Uncomment the next line to define a global platform for your project
 platform :ios, '15.0'

workspace 'msp-ios-sdk'
install! 'cocoapods',
         :generate_multiple_pod_projects => true,
         :integrate_targets => false

project 'Sources/Adapters/MSPPrebidAdapter/MSPPrebidAdapter'
project 'Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter'
project 'Sources/Core/MSPCore/MSPCore'
project 'Examples/MSPDemoApp/MSPDemoApp', 'Debug' => :debug, 'Release' => :release
project 'Sources/Adapters/NovaAdapter/NovaAdapter'
project 'Sources/Core/MSPSharedLibraries/MSPSharedLibraries'
project 'Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter'

project 'Sources/Adapters/InmobiAdapter/InmobiAdapter'
project 'Sources/Adapters/MintegralAdapter/MintegralAdapter'
project 'Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter'
project 'Sources/Adapters/PubmaticAdapter/PubmaticAdapter'
project 'Sources/Adapters/UnityAdapter/UnityAdapter'

# MSP DemoApp integration mode: cocoapods (default) or spm
demoapp_pod_configs = %w[Debug Release]
puts "[MSPDemoApp] Integrating CocoaPods dependencies for DemoApp target"


target 'MSPPrebidAdapter' do
  project 'Sources/Adapters/MSPPrebidAdapter/MSPPrebidAdapter'
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MSPPrebidAdapter

  target 'MSPPrebidAdapterTests' do
    # Pods for testing
  end

end

target 'MSPCore' do
  project 'Sources/Core/MSPCore/MSPCore'
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
  project 'Sources/Core/MSPSharedLibraries/MSPSharedLibraries'
  
end

target 'MSPOMSDK' do
  project 'MSPOMSDK/MSPOMSDK'
  
end


target 'MSPGoogleAdapter' do
  project 'Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter'
  # Comment the next line if you don't want to use dynamic frameworks
  # use_frameworks!

  # Pods for GoogleAdapter
  # pod 'Google-Mobile-Ads-SDK', "10.14.0", :modular_headers => true
end

target 'NovaAdapter' do
  project 'Sources/Adapters/NovaAdapter/NovaAdapter'
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
  project 'Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter'
  
end

target 'AmazonAdapter' do
  project 'AmazonAdapter/AmazonAdapter'
  
end

target 'NovaCore' do
  project 'NovaCore/NovaCore'
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!

  # Pods for NovaAdapter
  # Kingfisher, SnapKit, Shimmer are now provided via XCFrameworks - removed from Podfile
  #pod 'SDWebImage', '5.18.8', :modular_headers => true
  #pod 'SDWebImageWebPCoder', '0.14.2', :modular_headers => true
  #pod 'SnapKit', '~> 5.6.0', :modular_headers => true
  #pod 'Shimmer', :modular_headers => true
  pod 'MSPOMSDK', :path => 'MSPOMSDK.podspec'
  #pod 'DeviceKit', :modular_headers => true
  #pod 'NBDesignSystem', :git => 'https://github.com/ParticleMedia/LAFoundation', :branch => 'main', :commit => 'b94a948', :modular_headers => true
  #pod 'MSPSharedLibraries', :path => './MSPSharedLibraries', :modular_headers => true
end

  #target 'GoogleAdapterTests' do
  #  pod 'Google-Mobile-Ads-SDK'
  #end
  
target 'MSPDemoApp' do
  project 'Examples/MSPDemoApp/MSPDemoApp'

  # Core modules (binary XCFrameworks)
  pod 'MSPiOSCore', :path => 'MSPiOSCore.podspec', :configurations => demoapp_pod_configs
  pod 'NovaCore', :path => 'NovaCore.podspec', :configurations => demoapp_pod_configs
  pod 'MSPCore', :path => 'MSPCore.podspec', :configurations => demoapp_pod_configs
  
  # Adapter modules (source pods)
  pod 'NovaAdapter', :path => 'NovaAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MSPPrebidAdapter', :path => 'MSPPrebidAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MSPGoogleAdapter', :path => 'MSPGoogleAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MSPFacebookAdapter', :path => 'MSPFacebookAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'UnityAdapter', :path => 'UnityAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'InmobiAdapter', :path => 'InmobiAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MobilefuseAdapter', :path => 'MobilefuseAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MintegralAdapter', :path => 'MintegralAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'PubmaticAdapter', :path => 'PubmaticAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'AmazonAdapter', :path => 'AmazonAdapter.podspec', :configurations => demoapp_pod_configs
  # SwiftProtobuf is now provided via XCFramework in MSPCore - removed from Podfile
  pod 'MSPSharedLibraries', :path => 'MSPSharedLibraries.podspec', :configurations => demoapp_pod_configs
  # MSPKingfisher replaces official Kingfisher pod to avoid SwiftVerifyEmittedModuleInterface errors
  pod 'MSPKingfisher', :path => 'ThirdParty/MSPKingfisher/MSPKingfisher.podspec', :configurations => demoapp_pod_configs
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

      # Note: Kingfisher-specific patching removed - now using KingfisherLocal wrapper
      # which has BUILD_LIBRARY_FOR_DISTRIBUTION=NO set in its podspec
      
      # --- Enable Swift module generation for Shimmer ---
      # Fix "no such module 'Shimmer'" during XCFramework archive
      # Enable Swift import for Shimmer (Obj-C pod) by generating Shimmer.swiftmodule
      if target.name == "Shimmer"
        puts "⚙️  [post_install] Enabling Swift module generation for Shimmer"
        config.build_settings["DEFINES_MODULE"] = "YES"
        config.build_settings["CLANG_ENABLE_MODULES"] = "YES"
        config.build_settings["SWIFT_OBJC_BRIDGING_HEADER"] = ""
      end
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
  
  # Create module.modulemap symlink for Shimmer to make it discoverable by Swift
  # Swift requires modulemap to be named 'module.modulemap' in the include directory
  shimmer_modulemap_dir = File.join(installer.sandbox.root, "Headers/Public/Shimmer")
  shimmer_modulemap = File.join(shimmer_modulemap_dir, "Shimmer.modulemap")
  module_modulemap = File.join(shimmer_modulemap_dir, "module.modulemap")
  if File.exist?(shimmer_modulemap) && !File.exist?(module_modulemap)
    puts "⚙️  [post_install] Creating module.modulemap symlink for Shimmer"
    File.symlink("Shimmer.modulemap", module_modulemap)
  end
  
  # Note: Swift module resolution for vendored XCFrameworks is handled via:
  # 1. FRAMEWORK_SEARCH_PATHS (already set in podspecs and xcconfig)
  # 2. Swift compiler automatically finds module.modulemap in framework/Modules/
  # 3. No need to add -I flags - they cause path mismatch errors
end
